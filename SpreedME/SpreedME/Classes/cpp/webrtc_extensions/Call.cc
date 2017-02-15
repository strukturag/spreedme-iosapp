/**
 * @copyright Copyright (c) 2017 Struktur AG
 * @author Yuriy Shevchuk
 * @author Ivan Sein <ivan@nextcloud.com>
 *
 * @license GNU GPL version 3 or any later version
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "Call.h"

#include <stdexcept>

#include <webrtc/base/base64.h>
#include <webrtc/base/json.h>
#include <webrtc/base/helpers.h>

#include "utils.h"

#include "Error.h"

using namespace spreedme;

namespace spreedme {
	
struct SignallingByeMessageData : public rtc::MessageData {
	explicit SignallingByeMessageData(std::string userId, ByeReason reason) : userId(userId), reason(reason) {};
	
	std::string userId;
	ByeReason reason;
};

struct HangupMessageData : public rtc::MessageData {
	explicit HangupMessageData(ByeReason reason, bool shouldSelfDestructOnFinish) :
		reason(reason), shouldSelfDestructOnFinish(shouldSelfDestructOnFinish) {};

	ByeReason reason;
	bool shouldSelfDestructOnFinish;
};
	
struct MediaConstraintsRefData : public rtc::MessageData {
	explicit MediaConstraintsRefData(MediaConstraints *constraints) : constraints(constraints) {};
	
	MediaConstraints *constraints; // We don't own it
};
	
struct UserIdSDPAndMediaConstraintsRefData : public rtc::MessageData {
	explicit UserIdSDPAndMediaConstraintsRefData(std::string userId, std::string sdp, MediaConstraints *constraints) :
		userId(userId), sdp(sdp), constraints(constraints) {};
	
	std::string userId;
	std::string sdp;
	MediaConstraints *constraints; // We don't own it
};
    
struct EstablishOutgoingCallMessageData : public rtc::MessageData {
    explicit EstablishOutgoingCallMessageData(std::string userId, std::string sdp, MediaConstraints *constraints, bool automatic) :
    userId(userId), sdp(sdp), constraints(constraints), automatic(automatic) {};
    
    std::string userId;
    std::string sdp;
    MediaConstraints *constraints; // We don't own it
    bool automatic;
};
	

// '_w' - workerQueue, '_c' - callbacks queue
enum CallThreadingMessageId
{
	MSG_SMC_ESTABLISH_OUTGOING_CALL_w = 0, // SMC == SpreedMeCall
	MSG_SMC_ACCEPT_INCOMING_CALL_w,
	MSG_SMC_RECEIVED_MESSAGE_w,
	MSG_SMC_RECEIVED_BYE_MESSAGE_w,
	MSG_SMC_HANGUP_w,
	MSG_SMC_SET_MUTE_AUDIO_w,
	MSG_SMC_SET_MUTE_VIDEO_w,
	MSG_SMC_SET_LOUDSPEAKER_STATUS_w,
	MSG_SMC_REQUEST_SETUP_VIDEO_RENDERER_w,
	MSG_SMC_REQUEST_REMOVE_VIDEO_RENDERER_w,
	MSG_SMC_SET_AUDIO_CONSTRAINTS_w,
	MSG_SMC_SET_VIDEO_CONSTRAINTS_w,
	MSG_SMC_SET_VIDEO_DEVICE_ID_w,
	MSG_SMC_DISABLE_ALL_VIDEO_w,
	MSG_SMC_ENABLE_ALL_VIDEO_w,
	MSG_SMC_DISPOSE_OF_CALL_w,
	MSG_SMC_REQUEST_STATISTICS_w,
	MSG_SMC_CALL_HAS_BEEN_CLEANED_UP_c
};

	
}; //namespace spreedme


Call::Call(std::string selfId,
		   PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
		   SignallingHandler* signallingHandler,
		   MessageQueueInterface *workerQueue,
		   MessageQueueInterface *callbackQueue) :
	critSect_(webrtc::CriticalSectionWrapper::CreateCriticalSection()),
	peerConnectionWrapperFactory_(peerConnectionWrapperFactory),
	signallingHandler_(signallingHandler),
	state_(kSMCStateReady),
	selfId_(selfId),
	pendingOffer_(NULL),
	pendingConferenceMixerId_(NULL),
	atLeastOneWasConnectionEstablished_(false),
	audioMuted_(false),
	videoMuted_(false),
	audioConstraints_(NULL),
	videoConstraints_(NULL),
	workerQueue_(workerQueue),
	callbackQueue_(callbackQueue)
{
	ASSERT(workerQueue_ != callbackQueue_);
	callDeleter_ = new CallDeleter(this);
	callId_ = std::string();
	bool success = rtc::CreateRandomString(10, &callId_);
	if (!success) {
		spreed_me_log("Couldn't create callId!");
	}
	
	spreed_me_log("Created Call instance with sessionId %s", selfId_.c_str());
}


Call::~Call()
{
	if (pendingConferenceMixerId_) {
		delete pendingConferenceMixerId_;
		pendingConferenceMixerId_ = NULL;
	}
	
	if (pendingOffer_) {
		delete pendingOffer_;
		pendingOffer_ = NULL;
	}
	
	if (audioConstraints_) {
		delete audioConstraints_;
	}
	if (videoConstraints_) {
		delete videoConstraints_;
	}
	
	callbackQueue_ = NULL;
	workerQueue_ = NULL;
	
	delete critSect_;
}


void Call::Dispose()
{
	signallingHandler_->UnRegisterMessageReceiver(this);
	this->SetDelegate(NULL);
	workerQueue_->Post(this, MSG_SMC_DISPOSE_OF_CALL_w, NULL);
}


void Call::Dispose_w()
{
	// clean up worker queue
	workerQueue_->Clear(this);
	// delete all activeConnections in worker queue
	activeConnections_.clear();
	// delete all closed connections
	closedConnections_.clear();
	
	pendingOffers_.clear();
    pendingOutgoingCallOffers_.clear();
	
	callbackQueue_->Post(this, MSG_SMC_CALL_HAS_BEEN_CLEANED_UP_c);
}


std::vector<std::string> Call::GetUsersIds()
{
	critSect_->Enter();
	std::vector<std::string> vector;
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		vector.push_back(it->first);
	}
	critSect_->Leave();
	
	return vector;
}


std::set<std::string> Call::GetUsersIdsAsSet()
{
	critSect_->Enter();
	std::set<std::string> set;
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		set.insert(it->first);
	}
	critSect_->Leave();
	return set;
}



int Call::usersOnCallCount()
{
	critSect_->Enter();
	int activeConnectionsSize = (int)activeConnections_.size();
	critSect_->Leave();
	
	return activeConnectionsSize;
}


bool Call::HasVideo()
{
	return (this->NumberOfLocalVideoStreams() > 0);
}


size_t Call::NumberOfLocalVideoStreams()
{
	return this->NumberOfStreams(true, true);
}


size_t Call::NumberOfRemoteVideoStreams()
{
	return this->NumberOfStreams(false, true);
}


size_t Call::NumberOfRemoteStreams()
{
	return this->NumberOfStreams(false, false);
}


size_t Call::NumberOfStreams(bool local, bool countVideoStreamsOnly)
{
	critSect_->Enter();
	size_t numberOfStreams = 0;
	
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		rtc::scoped_refptr<webrtc::StreamCollectionInterface> streams = (local ? it->second->local_streams() : it->second->remote_streams());
		for (size_t i = 0; i < streams->count(); i++) {
			webrtc::MediaStreamInterface *stream = streams->at(i);
			
			if (countVideoStreamsOnly) {
				numberOfStreams = numberOfStreams + (stream->GetVideoTracks().size() > 0 ? 1 : 0);
			} else {
				numberOfStreams = numberOfStreams + (stream->GetAudioTracks().size() > 0 ? 1 : 0);
			}
		}
	}
	
	critSect_->Leave();
	
	return numberOfStreams;
}


#pragma mark - Video Renderers

void Call::RequestToSetupVideoRenderer(const std::string &userId, const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName)
{
	VideoRendererMessageData *msgData = new VideoRendererMessageData(userId, streamLabel, videoTrackId, rendererName);
	workerQueue_->Post(this, MSG_SMC_REQUEST_SETUP_VIDEO_RENDERER_w, msgData);
}


void Call::RequestToSetupVideoRenderer_w(const std::string &userId, const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName)
{
	if (!userId.empty() && !streamLabel.empty())  {
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
		
		if (wrapper) {
			wrapper->SetupVideoRenderer(streamLabel, videoTrackId, rendererName);
		} else {
			spreed_me_log("There is no wrapper for given userId to setRenderer!");
		}
	} else {
		spreed_me_log("UserId or streamLabel is empty or renderer is NULL in set Renderer method!");
	}
}


void Call::RequestToDeleteVideoRenderer(const std::string &userId, const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName)
{
	VideoRendererMessageData *msgData = new VideoRendererMessageData(userId, streamLabel, videoTrackId, rendererName);
	workerQueue_->Post(this, MSG_SMC_REQUEST_REMOVE_VIDEO_RENDERER_w, msgData);
}


void Call::RequestToDeleteVideoRenderer_w(const std::string &userId, const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName)
{
	if (!userId.empty() && !streamLabel.empty())  {
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
		
		if (wrapper) {
			wrapper->DeleteVideoRenderer(streamLabel, videoTrackId, rendererName);
		} else {
			spreed_me_log("There is no wrapper for given userId to remove Renderer!");
		}
	} else {
		spreed_me_log("UserId or streamLabel is empty or renderer is NULL in remove Renderer method!");
	}
}


#pragma mark - PeerConnection management

rtc::scoped_refptr<PeerConnectionWrapper> Call::CreatePeerConnectionWrapper(const std::string &userId)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = peerConnectionWrapperFactory_->CreateSpreedPeerConnection(userId, this);
	return wrapper;
}


bool Call::InsertNewWrapperWithUserId(rtc::scoped_refptr<PeerConnectionWrapper> wrapper, std::string userId)
{
	critSect_->Enter();
	std::pair<UserIdToWrapperMap::iterator , bool> ret = activeConnections_.insert(std::pair< std::string, rtc::scoped_refptr<PeerConnectionWrapper> >(userId, wrapper));
	critSect_->Leave();
	return ret.second;
}


rtc::scoped_refptr<PeerConnectionWrapper> Call::WrapperForUserId(const std::string &userId)
{
	UserIdToWrapperMap::iterator it = activeConnections_.find(userId);
	
	if (it != activeConnections_.end()) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
		return wrapper;
	}
	
	return NULL;
}


bool Call::WrapperForUserIdExists(const std::string &userId)
{
	UserIdToWrapperMap::iterator it = activeConnections_.find(userId);
	
	return (it != activeConnections_.end());
}


bool Call::CheckIfRegisteredWrapper(PeerConnectionWrapper *wrapper)
{
	rtc::scoped_refptr<PeerConnectionWrapper> registeredWrapper = this->WrapperForUserId(wrapper->userId());
	if (registeredWrapper) {
		if (registeredWrapper.get() == wrapper) {
			return true;
		}
	}
	
	return false;
}


#pragma mark - Conferences

std::string Call::CreateConferenceId()
{
	std::string randomString;
	bool succes = rtc::CreateRandomString(selfId_.length(), &randomString);
	if (!succes) {
		spreed_me_log("Couldn't generate random string to create conference Id!\n");
		assert(false);
	}
	
	std::string conferenceId = selfId_ + randomString;
	conferenceId = rtc::Base64::Encode(conferenceId);
	
	return conferenceId;
}


void Call::CreateConference()
{
	// we expect here conferenceId_ to be already created (on a stage when we call to 3 peer)
	std::set<std::string> ids = this->GetUsersIdsAsSet();
	std::pair<std::set<std::string>::iterator, bool> pair = ids.insert(selfId_);
	if (!pair.second) {
		spreed_me_log("We couldn't add selfId_ to set of ids!\n");
		assert(false);
	}
	signallingHandler_->SendConferenceDocument(ids, conferenceId_);
}


#pragma mark - Call controlling methods

void Call::NewIncomingCall(const std::string &userId, const std::string &sdp, const std::string &conferenceId)
{
	if (!this->WrapperForUserIdExists(userId)) {
		
		// Singlal to uiDelegate about new call straight away
		if (activeConnections_.size() == 0) {
			state_ = kSMCStateSinglePeerCall;
			if (delegate_) {
				delegate_->FirstIncomingCallReceived(this, userId);
			}
			
			this->SetupPeerConnectionFactory();
		}
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->CreatePeerConnectionWrapper(userId);
		bool succes = this->InsertNewWrapperWithUserId(wrapper, userId);
		if (!succes) {
			spreed_me_log("Couldn't insert new wrapper! Wrapper for this id %s already exists.\n", userId.c_str());
			assert(false);
		}
		
		std::pair<UserIdToPendindOfferPackageMap::iterator, bool> ret = pendingOffers_.insert(UserIdToPendingOfferPackagePair(userId, PendingOfferPackage(sdp, conferenceId)));
		if (!ret.second) {
			spreed_me_log("Couldn't insert new pending offer! Offer for this id %s already exists.\n", userId.c_str());
			assert(false);
		}
		
		if (activeConnections_.size() == 1) {
//			state_ = kSMCStateSinglePeerCall;
		} else if (activeConnections_.size() > 1) {
			state_ = kSMCStateConferenceCall;
			if (delegate_) {
				delegate_->IncomingCallReceived(this, userId);
			}
		} else {
			spreed_me_log("Something is broken. activeConnections_.size() is less then 1.\n");
			assert(false);
		}
		
	} else {
		spreed_me_log("User is already on call. Wrapper for this id %s already exists.\n", userId.c_str());
		assert(false);
	}
}


void Call::NewIncomingCall(const std::string &userId, const Json::Value &jsonOffer)
{
	std::string sdp = jsonOffer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
	std::string conferenceId = jsonOffer.get(kOfferConferenceKey, Json::Value()).asString();
	if (!sdp.empty()) {
		this->NewIncomingCall(userId, sdp, conferenceId);
	} else {
		spreed_me_log("Error parsing session description in remote offer.\n");
	}
}


void Call::AcceptIncomingCall(const std::string &userId, const std::string &sdp, MediaConstraints *mediaConstraints)
{
	UserIdSDPAndMediaConstraintsRefData *msgData = new UserIdSDPAndMediaConstraintsRefData(userId, sdp, mediaConstraints);
	workerQueue_->Post(this, MSG_SMC_ACCEPT_INCOMING_CALL_w, msgData);
}


void Call::AcceptIncomingCall_w(const std::string &userId, const std::string &sdp, MediaConstraints *mediaConstraints)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
	if (wrapper) {
		spreed_me_log("Accepting offer from %s", userId.c_str());
		
		std::string sdpToProcess = "";
		if (sdp.empty()) {
			//this means we need to get sdp from pending sdps
			UserIdToPendindOfferPackageMap::iterator it = pendingOffers_.find(userId);
			if (it != pendingOffers_.end()) {
				sdpToProcess = it->second.sdp;
				if (!it->second.conferenceId.empty()) {
					conferenceId_ = it->second.conferenceId;
				}
				pendingOffers_.erase(it);
			} else {
				spreed_me_log("Error! Couldn't find pending offer to accept.\n");
			}
		} else {
			// this means sdp was given to us
			sdpToProcess = sdp;
		}
		
		
		bool forceNoVideo = false;
//		if (maxNumberOfVideoConnections_ < this->NumberOfRemoteVideoStreams() + numberOfExternalVideoConnections_) {
//			forceNoVideo = true;
//			spreed_me_log("Force no video in AcceptIncomingCall_w");
//		}
		
		// we have already added the wrapper to active connections so we have to check not for "activeConnections_.size() > 0"
		if (activeConnections_.size() > 1) {
			forceNoVideo = this->NumberOfLocalVideoStreams() == 0;
		}
		
		MediaConstraints constraints = this->ProcessConstraints(mediaConstraints, forceNoVideo);
		wrapper->SetSessionDescriptionConstraints(constraints);
		bool localStreamWithVideo = this->ShouldAddVideoTrackForWrapper(wrapper, forceNoVideo);
		
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peerConnectionWrapperFactory_->CreateLocalStream(true, localStreamWithVideo);
		wrapper->AddLocalStream(stream, NULL);
				
		if (!sdpToProcess.empty()) {
			wrapper->SetupRemoteOffer(sdpToProcess);
		} else {
			spreed_me_log("No sdp to accept incoming call!");
			assert(false);
		}
		
		// Apply whatever options are present for the call to the new wrapper
		this->ApplyCallSettings_w(wrapper);
		
	} else {
		spreed_me_log("Error! No wrapper for incoming call acception.\n");
	}
}


void Call::EstablishOutgoingCall(const std::string &userId, MediaConstraints *mediaConstraints, bool automatic)
{
	EstablishOutgoingCallMessageData *msgData = new EstablishOutgoingCallMessageData(userId, "", mediaConstraints, automatic);
	workerQueue_->Post(this, MSG_SMC_ESTABLISH_OUTGOING_CALL_w, msgData);
}


void Call::EstablishOutgoingCall_w(const std::string &userId, MediaConstraints *mediaConstraints, bool automatic)
{
	if (!this->WrapperForUserIdExists(userId)) {
		
		spreed_me_log("Establishing outgoing call to %s", userId.c_str());
		
		// Singlal to uiDelegate about new call staight away
		if (activeConnections_.size() == 0) {
			if (delegate_) {
                bool withVideo = false;
                bool noVideoConstraintValue = false;
                size_t numberOfFoundConstraints = 0;
                
                webrtc::FindConstraint(mediaConstraints, webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, &noVideoConstraintValue, &numberOfFoundConstraints);
                
                if (numberOfFoundConstraints > 0) {
                    withVideo = noVideoConstraintValue;
                } else {
                    withVideo = true;
                }
                
                delegate_->FirstOutgoingCallStarted(this, userId, withVideo);
			}
		
			this->SetupPeerConnectionFactory();
			
		} else if (activeConnections_.size() > 0) {
			if (delegate_) {
				delegate_->OutgoingCallStarted(this, userId);
			}
		} else {
			spreed_me_log("Something is broken. activeConnections_.size() is less then 1.\n");
			assert(false);
		}
		
				
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->CreatePeerConnectionWrapper(userId);
		if (wrapper) {
			
			bool forceNoVideo = false;
//			if (maxNumberOfVideoConnections_ < this->NumberOfRemoteVideoStreams() + 1 + numberOfExternalVideoConnections_) {
//				forceNoVideo = true;
//				spreed_me_log("Force no video in EstablishOutgoingCall_w");
//			}
			
			if (activeConnections_.size() > 0) {
				forceNoVideo = this->NumberOfLocalVideoStreams() == 0;
			}

			MediaConstraints constraints = this->ProcessConstraints(mediaConstraints, forceNoVideo);
			wrapper->SetSessionDescriptionConstraints(constraints);
			bool localStreamWithVideo = this->ShouldAddVideoTrackForWrapper(wrapper, forceNoVideo); // This method looks for video constraints in wrapper so you should set constraints before calling it.
			
			rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peerConnectionWrapperFactory_->CreateLocalStream(true, localStreamWithVideo);
			wrapper->AddLocalStream(stream, NULL);

			
			bool succes = this->InsertNewWrapperWithUserId(wrapper, userId); // adds wrapper to active connections
			if (!succes) {
				spreed_me_log("Assert! Couldn't insert new wrapper! Wrapper for this id %s already exists.\n", userId.c_str());
				assert(false);
			}
			
			// We begin new conference. Check if this is at least second(third if count ourselves) peer on call and no other conference is active i.e. conferenceId_ is empty
			if (activeConnections_.size() > 1 && conferenceId_.empty()) {
				conferenceId_ = this->CreateConferenceId();
			}
            
            std::pair<AutomaticOutgoingCallPendingOfferMap::iterator, bool> ret = pendingOutgoingCallOffers_.insert(UserIdToAutomaticOfferPair(userId, automatic));
            if (!ret.second) {
                spreed_me_log("Couldn't insert new outgoing call pending offer! Offer for this id %s already exists.\n", userId.c_str());
                assert(false);
            }
			
			wrapper->CreateOffer(userId);
			
			// Apply whatever options are present for the call to the new wrapper
			this->ApplyCallSettings_w(wrapper);
			
			if (activeConnections_.size() == 1) {
				state_ = kSMCStateSinglePeerCall;
			} else if (activeConnections_.size() > 1) {
				state_ = kSMCStateConferenceCall;
			} else {
				spreed_me_log("Something is broken. activeConnections_.size() is less then 1.\n");
				assert(false);
			}
		}
		
	} else {
		spreed_me_log("Information. Couldn't insert new wrapper! Wrapper for this id %s already exists.\n", userId.c_str());
	}
}


void Call::ReceivedByeMessage(const std::string &userId, ByeReason reason)
{
	SignallingByeMessageData *param = new SignallingByeMessageData(userId, reason);
	workerQueue_->Post(this, MSG_SMC_RECEIVED_BYE_MESSAGE_w, param);
}


void Call::ReceivedByeMessage_w(const std::string &userId, ByeReason reason)
{
	// TODO: Find a better way to deal with this
	/*
	 Added scope in order to release wrapper since we need it only to check if there is userId registered. 
	 Keeping this wrapper within the method scope causes a side effect of late deletion of peerconnection,
	 which leads to further crashes due to racing conditions.
	 */
	{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
	if (wrapper == NULL) {
		spreed_me_log("Bye message from user who is not in the call. Ignore.");
		if (delegate_) {
			delegate_->RemoteUserHangUp(this, userId);
		}
		return;
	}
	}
	
	if (activeConnections_.size() > 1) {
		this->HangUpUser(userId);
		if (delegate_) {
			delegate_->RemoteUserHangUp(this, userId);
		}
	} else if (activeConnections_.size() == 1) {
		this->FinishCall(kByeReasonNotSpecified, false, kCallFinishReasonRemoteHungUp);
	} else if (activeConnections_.size() < 1) {
		spreed_me_log("No one on call. Doing nothing in %s.\n", __FUNCTION__);
	} else {
		spreed_me_log("Strange behaviour please check activeconnections_.count() %d.\n", activeConnections_.size());
		spreed_me_log("Strange behaviour please check in %s.\n", __FUNCTION__);
	}
}


void Call::HangUp(ByeReason reason)
{
	HangupMessageData *msgData = new HangupMessageData(reason, false);
	workerQueue_->Post(this, MSG_SMC_HANGUP_w, msgData);
}


void Call::HangUp_w(ByeReason reason)
{
	this->FinishCall(reason, true, kCallFinishReasonLocalHangUp);
}


void Call::FinishCall(ByeReason reason, bool shouldSendBye, CallFinishReason callFinishReason)
{
	this->CloseCall(reason, shouldSendBye);
	this->signallingHandler_->UnRegisterMessageReceiver(this);
	peerConnectionWrapperFactory_->StopVideoCapturing();
	peerConnectionWrapperFactory_->DisposeOfVideoSource();
	
	state_ = kSMCStateFinished;
	
	if (delegate_) {
		delegate_->CallIsFinished(this, callFinishReason);
	}
}


void Call::CloseCall(ByeReason reason, bool sendBye)
{
	webrtc::CriticalSectionScoped sc(critSect_);
	
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
		if (sendBye) {
			this->SendBye(it->first, reason);
		}
		it->second->Close();
		closedConnections_.insert(WrapperIdToWrapperPair(it->first, it->second));
	}
    activeConnections_.clear();
	
	pendingOffers_.clear();
    pendingOutgoingCallOffers_.clear();
	conferenceId_ = std::string(); // empty conference Id
	
	state_ = kSMCStateReady;
}


void Call::HangUpUser(const std::string &userId)
{
	critSect_->Enter();
	
	UserIdToWrapperMap::iterator it = activeConnections_.find(userId);
	if (it != activeConnections_.end()) {
		it->second->Close();
		closedConnections_.insert(WrapperIdToWrapperPair(it->first, it->second));
		activeConnections_.erase(it);
	}
	
	if (activeConnections_.size() < 2) {
		conferenceId_ = std::string(); // since server downgrades to single call mode we need to do it either in order to interact properly
	}
	
	critSect_->Leave();
	
	this->SendBye(userId, kByeReasonNotSpecified);
}


void Call::SendBye(const std::string &userId, ByeReason reason)
{
	//first clean up any pending offers/conferences for this user
	UserIdToPendindOfferPackageMap::iterator it = pendingOffers_.find(userId);
	if (it != pendingOffers_.end()) {
		pendingOffers_.erase(it);
	}
	
	signallingHandler_->SendBye(userId, reason, NULL);
}


void Call::MuteAudio(bool onOff)
{
	BooleanMessageData *msgData = new BooleanMessageData(onOff);
	workerQueue_->Post(this, MSG_SMC_SET_MUTE_AUDIO_w, msgData);
}


void Call::MuteAudio_w(bool onOff)
{
	//	peerConnectionWrapperFactory_->SetMuteAudio(onOff); //TODO: Add implementation to mute thru audio device module.
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		it->second->SetMuteAudio(onOff);
	}
	critSect_->Enter();
	audioMuted_ = onOff;
	critSect_->Leave();
}


void Call::SetLoudspeakerStatus(bool onOff)
{
	BooleanMessageData *msgData = new BooleanMessageData(onOff);
	workerQueue_->Post(this, MSG_SMC_SET_LOUDSPEAKER_STATUS_w, msgData);
}


void Call::SetLoudspeakerStatus_w(bool onOff)
{
	peerConnectionWrapperFactory_->SetSpeakerPhone(onOff);
}


void Call::MuteVideo(bool onOff)
{
	BooleanMessageData *msgData = new BooleanMessageData(onOff);
	workerQueue_->Post(this, MSG_SMC_SET_MUTE_VIDEO_w, msgData);
}


void Call::MuteVideo_w(bool onOff)
{
	//	peerConnectionWrapperFactory_->SetMuteVideo(onOff); //TODO: Add implementation to mute thru video device module.
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		it->second->SetMuteVideo(onOff);
	}
	critSect_->Enter();
	videoMuted_ = onOff;
	critSect_->Leave();
}


void Call::DisableAllVideo()
{
	workerQueue_->Send(this, MSG_SMC_DISABLE_ALL_VIDEO_w);
}


void Call::DisableAllVideo_w()
{
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		it->second->DisableAllVideo();
	}
	
	peerConnectionWrapperFactory_->StopVideoCapturing();
}


void Call::EnableAllVideo()
{
	workerQueue_->Post(this, MSG_SMC_ENABLE_ALL_VIDEO_w);
}


void Call::EnableAllVideo_w()
{
	for (UserIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); it++) {
		it->second->EnableAllVideo();
	}
	
	peerConnectionWrapperFactory_->StartVideoCapturing();
}


#pragma mark - Streams in PeerConnections

void Call::AddDefaultStreamToPeerConnectionWrapper(const std::string &userId)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
	if (wrapper) {
		this->AddDefaultStreamToPeerConnectionWrapper(wrapper);
	}
}


void Call::AddDefaultStreamToPeerConnectionWrapper(rtc::scoped_refptr<PeerConnectionWrapper> wrapper)
{
	if (wrapper) {
        bool withAudio = true;
		bool withVideo = true;
		//		if (maxNumberOfVideoConnections_ < activeConnections_.size() + numberOfExternalVideoConnections_) {
		//			withVideo = false;
		//		}
		
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peerConnectionWrapperFactory_->CreateLocalStream(withAudio, withVideo);
		wrapper->AddLocalStream(stream, NULL);
	}
}


#pragma mark - Constraints

void Call::SetupPeerConnectionFactory()
{
	MediaConstraints *audioConstraints = NULL;
	MediaConstraints *videoConstraints = NULL;
	if (audioConstraints_) {
		audioConstraints = audioConstraints_->Copy();
	}
	if (videoConstraints_) {
		videoConstraints = videoConstraints_->Copy();
	}
	
	peerConnectionWrapperFactory_->SetVideoDeviceId(videoDeviceId_);
	peerConnectionWrapperFactory_->SetAudioVideoConstrains(audioConstraints, videoConstraints);
}


void Call::ForceAddMandatoryConstraint(MediaConstraints *constraints, const std::string &constraintName, const std::string &constraintValue)
{
	if (constraints) {
		webrtc::MediaConstraintsInterface::Constraints *mandatory = constraints->GetMandatoryRef();
		for (webrtc::MediaConstraintsInterface::Constraints::iterator it = mandatory->begin(); it != mandatory->end(); ++it) {
			if (it->key == constraintName) {
				mandatory->erase(it);
				break;
			}
		}
		constraints->AddMandatory(constraintName, constraintValue);
	}
}


bool Call::ShouldAddVideoTrackForWrapper(rtc::scoped_refptr<PeerConnectionWrapper> wrapper, bool forceNoVideo)
{
	bool answer = false;
	if (wrapper && !forceNoVideo) {
		answer = wrapper->IsVideoPermittedByConstraints();
	}
	
	return answer;
}


MediaConstraints Call::ProcessConstraints(MediaConstraints *mediaConstraints, bool forceDisableVideo)
{
	MediaConstraints constraints;
	
	if (mediaConstraints) {
		if (forceDisableVideo) {
			this->ForceAddMandatoryConstraint(mediaConstraints, webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
		}
		constraints = *mediaConstraints;
		delete mediaConstraints;
		
	} else {
		if (forceDisableVideo) {
			constraints.AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
		}
	}
	
	return constraints;
}


#pragma mark - Signalling messages handling

void Call::MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId)
{
	SignallingMessageData *msgData = new SignallingMessageData(msg, transportType, wrapperId);
	workerQueue_->Post(this, MSG_SMC_RECEIVED_MESSAGE_w, msgData);
}


void Call::MessageReceived_w(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId)
{
	Json::Reader jsonReader;
	Json::Value root;
	
    spreed_me_log("MSG: %s", msg.c_str());
	bool success = jsonReader.parse(msg, root);
	if (success) {
		Json::Value innerJson = root[kDataKey];
		if (!innerJson.isNull()) {
			std::string messageType = innerJson.get(kTypeKey, Json::Value()).asString();
			std::string from = root.get(kFromKey, Json::Value()).asString();
			if (!messageType.empty()) {
				if (messageType == kOfferKey) {
					this->ReceivedOffer(innerJson, from);
				} else if (messageType == kAnswerKey) {
					this->ReceivedAnswer(innerJson, from);
				} else if (messageType == kCandidateKey) {
					this->ReceivedCandidate(innerJson, from);
				} else if (messageType == kConferenceKey) {
					this->ReceivedConferenceDocument(innerJson);
				} else {
					// ignore this message. It was not meant for us.
					//spreed_me_log("This message is no Offer, Answer, Conference or Candidate. Ignore it.\n");
				}
			} else {
				spreed_me_log("Error, couldn't parse message type!\n");
			}
		}
	} else {
		spreed_me_log("Error, couldn't parse message!\n");
	}
}


void Call::MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
{
	spreed_me_log("Received token message. This should not happen!\n");
}


void Call::ProcessDefaultAudioVideoOffer(const Json::Value &unwrappedOffer, const std::string &from)
{
	std::string conferenceId = unwrappedOffer.get(kOfferConferenceKey, Json::Value()).asString();
	
	switch (state_) {
		case kSMCStateReady:
			this->NewIncomingCall(from, unwrappedOffer);
			break;
			
		case kSMCStateSinglePeerCall:
			this->SendBye(from, kByeReasonBusy);
			if (delegate_) {
				delegate_->IncomingCallWasAutoRejected(this, from);
			}
			break;
			
		case kSMCStateConferenceCall:
			if (!conferenceId.empty() && conferenceId==conferenceId_) {
				std::string sdp = unwrappedOffer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
				this->NewIncomingCall(from, sdp, conferenceId_);
				// After call to NewIncomingCall we already have a wrapper inserted;
				
				MediaConstraints constraints;
				if (!this->HasVideo()) {
					constraints.AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
				}
				
				this->AcceptIncomingCall(from, sdp, constraints.Copy());
			} else {
				this->SendBye(from, kByeReasonBusy);
				if (delegate_) {
					delegate_->IncomingCallWasAutoRejected(this, from);
				}
			}
			break;
			
		case kSMCStateWaitingForConferenceMixerCall:
			if (from == *pendingConferenceMixerId_) {
				// TODO: deal with this situation, it is not trivial since we can wait conferenceMixer when we are in peer to peer conference
			} else {
				this->SendBye(from, kByeReasonBusy);
				if (delegate_) {
					delegate_->IncomingCallWasAutoRejected(this, from);
				}
			}
			break;
			
		case kSMCStateNotReady:
		default:
			spreed_me_log("Error: call is not ready or state_ is undefined!\n");
			break;
	}
}


void Call::ProcessDataChannelTokenOffer(const Json::Value &unwrappedOffer, const std::string &from)
{
	spreed_me_log("We actually shouldn't get in ProcessDataChannelTokenOffer!");
}


void Call::ReceivedOffer(const Json::Value &offerJson, const std::string &from)
{
	Json::Value wrappedOffer = offerJson.get(kOfferKey, Json::Value());
	if (!wrappedOffer.isNull()) {
		std::string sdp = wrappedOffer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
		std::string id = wrappedOffer.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = wrappedOffer.get(kDataChannelTokenKey, Json::Value()).asString();

		if (!sdp.empty() && token.empty()) {
			this->ProcessDefaultAudioVideoOffer(wrappedOffer, from);
		} else if (!sdp.empty() && !token.empty() && !id.empty()) {
			this->ProcessDataChannelTokenOffer(wrappedOffer, from);
		}
	}
}


void Call::ReceivedAnswer(const Json::Value &answerJson, const std::string &from)
{
	Json::Value wrappedAnswer = answerJson.get(kAnswerKey, Json::Value());
	if (!wrappedAnswer.isNull()) {
		
		UserIdToWrapperMap::iterator it = activeConnections_.find(from);
		if (it != activeConnections_.end()) {
			rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
			
			if (wrapper->signalingState() == webrtc::PeerConnectionInterface::kHaveLocalOffer) {
				
				std::string sdp = wrappedAnswer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
				if (!sdp.empty()) {
					wrapper->SetupRemoteAnswer(sdp);
					
					if (activeConnections_.size() > 1) {
						this->CreateConference();
					}
				}
			}
		}
	}
}


void Call::ReceivedCandidate(const Json::Value &candidateJson, const std::string &from)
{
	Json::Value wrappedCandidate = candidateJson.get(kCandidateKey, Json::Value());
	if (!wrappedCandidate.isNull()) {
		
		UserIdToWrapperMap::iterator it = activeConnections_.find(from);
		if (it != activeConnections_.end()) {
			rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
				
			std::string sdpMid = wrappedCandidate.get(kCandidateSdpMidKey, Json::Value()).asString();
			
			int sdpMLineIndex = -1;
			Json::Value sdpMLineIndexValue = wrappedCandidate.get(kCandidateSdpMlineIndexKey, Json::Value());
			if (!sdpMLineIndexValue.isNull()) {
				sdpMLineIndex = sdpMLineIndexValue.asInt();
			}
			
			std::string candidateString = wrappedCandidate.get(kCandidateSdpKey, Json::Value()).asString();

			if (sdpMLineIndex > -1) {
				wrapper->SetupRemoteCandidate(sdpMid, sdpMLineIndex, candidateString);
			} else {
				throw std::runtime_error("Candidate inline index is not correct!!!");
			}
		}
	} else {
		spreed_me_log("Problem with parsing candidate! \n");
	}
}


void Call::ReceivedConferenceDocument(const Json::Value &conferenceJson)
{
	if (state_ == kSMCStateNotReady || state_ == kSMCStateReady) {
		return; // From documentation on conferencing: "If not in a call already -> ignore."
	}
	
	std::string conferenceId = conferenceJson.get(kIdKey, Json::Value()).asString();
	
	if (conferenceId_.empty()) {
		conferenceId_ = conferenceId;
	}
	
	if (!conferenceId.empty() && conferenceId == conferenceId_) {
		
		state_ = kSMCStateConferenceCall;
		
		Json::Value idsArray = conferenceJson.get(kConferenceKey, Json::Value());
		if (idsArray.isArray()) {
			std::set<std::string> ids;
			for (int i = 0; i < idsArray.size(); ++i) {
				Json::Value idJson = idsArray[i];
				std::string id = idJson.asString();
				if (!id.empty()) {
					ids.insert(id); // we can safely ignore coincidences
				}
			}
			
			if (ids.size()) {
				for (std::set<std::string>::iterator it = ids.begin(); it != ids.end(); it++) {
					int comparisonResult = selfId_.compare(*it); //it->compare(selfId_);
					spreed_me_log("it(%d)      = %s \nselfId_(%d) = %s \n comparisonResult = %d\n\n", it->length(), it->c_str(), selfId_.length(), selfId_.c_str(), comparisonResult);
					
					if (comparisonResult < 0 && !this->WrapperForUserIdExists(*it)) {
                        spreed_me_log("Calling according to conference to:\n%s\n", it->c_str());
                        
                        MediaConstraints *constraints = NULL;
                        if (!this->HasVideo()) {
                            constraints = new MediaConstraints;
                            constraints->AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueFalse);
                        }
                                                
                        this->EstablishOutgoingCall(*it, constraints, true);
					}
				}
			}
		}
	}
}


#pragma mark - PeerConnectionWrapper Delegate Interface

void Call::IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *peerConnectionWrapper)
{
	critSect_->Enter();
	bool isWrapperRegistered = this->CheckIfRegisteredWrapper(peerConnectionWrapper);
	std::string userId = peerConnectionWrapper->userId();
	critSect_->Leave();
	if (isWrapperRegistered) {
		switch (new_state) {
			case webrtc::PeerConnectionInterface::kIceConnectionNew:
			case webrtc::PeerConnectionInterface::kIceConnectionChecking:
			break;
				
			case webrtc::PeerConnectionInterface::kIceConnectionCompleted:
			case webrtc::PeerConnectionInterface::kIceConnectionConnected:
				if (!atLeastOneWasConnectionEstablished_ && delegate_) {
					delegate_->CallHasStarted(this);
				}
				
				atLeastOneWasConnectionEstablished_ = true;
				
				if (delegate_) {
					delegate_->ConnectionEstablished(this, userId);
				}
			break;
				
			case webrtc::PeerConnectionInterface::kIceConnectionDisconnected:
				if (delegate_) {
					delegate_->ConnectionLost(this, userId);
				}
			break;
			
			case webrtc::PeerConnectionInterface::kIceConnectionFailed:
				if (delegate_) {
					delegate_->ConnectionFailed(this, userId);
				}
			break;
			
			case webrtc::PeerConnectionInterface::kIceConnectionClosed:
			break;
				
			default:
				break;
		}
		
		
	} else {
		spreed_me_log("Message from unregistered wrapper %p ! This can happen when wrapper is being destoroyed.\n", peerConnectionWrapper);
	}
}


void Call::SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper)
{
	
}


void Call::PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper)
{
	
}


void Call::AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendAnswer(sdType, sdp, std::string(), std::string(), peerConnectionWrapper);
}


void Call::OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	std::string confId;
    
    spreed_me_log("Offer ready to be sent to %s", (peerConnectionWrapper->userId()).c_str());
    
    AutomaticOutgoingCallPendingOfferMap::iterator it = pendingOutgoingCallOffers_.find(peerConnectionWrapper->userId());
    if (it != pendingOutgoingCallOffers_.end()) {
        if (it->second) {
            //Only add conference Id to the offer when it is an automatic call.
            confId = conferenceId_;
            spreed_me_log("Automatic call offer. Adding conference Id to the offer.\n");
        }
        pendingOutgoingCallOffers_.erase(it);
    }
	
	signallingHandler_->SendOffer(sdType, sdp, std::string(), std::string(), confId, peerConnectionWrapper);
}


void Call::CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendCandidate(candidate, std::string(), std::string(), peerConnectionWrapper);
}


void Call::DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper)
{
	
}


void Call::ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										   webrtc::DataChannelInterface *data_channel,
										   PeerConnectionWrapper *wrapper)
{
	signallingHandler_->ReceivedDataChannelData(buffer, data_channel, wrapper);
}


void Call::LocalStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	spreed_me_log("Call. Local stream has been added %s", stream->label().c_str());
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
	for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
		videoTracksIds.push_back(it->get()->id());
	}
	
	if (delegate_) {
		delegate_->LocalStreamHasBeenAdded(this, peerConnectionWrapper->userId(), stream->label(), videoTracksIds);
	}
}


void Call::LocalStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
	for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
		videoTracksIds.push_back(it->get()->id());
	}
	
	if (delegate_) {
		delegate_->LocalStreamHasBeenRemoved(this, peerConnectionWrapper->userId(), stream->label(), videoTracksIds);
	}
}


void Call::RemoteStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	
	// If video is not permitted by constraints we have a dead video track.
	// We have 2 options:
	// 1. do not expose dead tracks to client;
	// 2. Expose dead tracks to client but send some 'permissions' structure or flags to signal which/what is dead;
	// At the moment we have chosen 1 options
	if (peerConnectionWrapper->IsVideoPermittedByConstraints()) {
		webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
		for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
			videoTracksIds.push_back(it->get()->id());
		}
	}

	if (delegate_) {
		delegate_->RemoteStreamHasBeenAdded(this, peerConnectionWrapper->userId(), stream->label(), videoTracksIds);
	}
}


void Call::RemoteStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	
	// If video is not permitted by constraints we have a dead video track.
	// We have 2 options:
	// 1. do not expose dead tracks to client;
	// 2. Expose dead tracks to client but send some 'permissions' structure or flags to signal which/what is dead;
	// At the moment we have chosen 1 options
	
	// Since we didn't expose dead video tracks to client in RemoteStreamHasBeenAdded we should omit them in RemoteStreamHasBeenRemoved too.
	if (peerConnectionWrapper->IsVideoPermittedByConstraints()) {
		webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
		for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
			videoTracksIds.push_back(it->get()->id());
		}
	}
		
	if (delegate_) {
		delegate_->RemoteStreamHasBeenRemoved(this, peerConnectionWrapper->userId(), stream->label(), videoTracksIds);
	}
}


void Call::PeerConnectionWrapperHasEncounteredError(PeerConnectionWrapper *peerConnectionWrapper, const Error &error)
{
	if (delegate_) {
		Error callError = Error(kErrorDomainCall, "PeerConnectionWrapperHasEncounteredError", kPeerConnectionFailedErrorCode);
		callError.underlyingError = new Error(error);
		if (delegate_) {
			delegate_->CallHasEncounteredAnError(this, callError);
		}
	}
}


void Call::VideoRendererWasSetup(PeerConnectionWrapper *peerConnectionWrapper,
								 const VideoRendererInfo &info)
{
	if (delegate_) {
		delegate_->VideoRendererWasCreated(this, info);
	}
}


void Call::VideoRendererHasChangedFrameSize(PeerConnectionWrapper *peerConnectionWrapper,
											const VideoRendererInfo &info)
{
	if (delegate_) {
		delegate_->VideoRendererHasSetFrame(this, info);
	}
}


void Call::VideoRendererWasDeleted(PeerConnectionWrapper *peerConnectionWrapper,
								   const VideoRendererInfo &info)
{
	if (delegate_) {
		delegate_->VideoRendererWasDeleted(this, info);
	}
}


void Call::FailedToSetupVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
									  const VideoRendererInfo &info,
									  VideoRendererManagementError error)
{
	if (delegate_) {
		delegate_->FailedToSetupVideoRenderer(this,
											  info,
											  error);
	}
}


void Call::FailedToDeleteVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
									   const VideoRendererInfo &info,
									   VideoRendererManagementError error)
{
	if (delegate_) {
		delegate_->FailedToDeleteVideoRenderer(this,
											  info,
											  error);
	}
}


void Call::PeerConnectionWrapperHasReceivedStats(spreedme::PeerConnectionWrapper *peerConnectionWrapper, const webrtc::StatsReports &reports)
{
	std::string factoryId = peerConnectionWrapper->factoryId();
	if (statisticsWaitSet_.count(factoryId)) {
		collectedStatReports_.insert(collectedStatReports_.end(), reports.begin(), reports.end());
		statisticsWaitSet_.erase(factoryId);
		
		// Check if we have gathered all statistics we were eaiting for
		if (statisticsWaitSet_.size() == 0) {
			
			webrtc::StatsReports reports = collectedStatReports_;
			
			delegate_->CallHasReceivedStatistics(this, reports);
		}
		
	} else {
		spreed_me_log("Statistics has come from unexpected wrapper!");
	}
}


#pragma mark - Constaints setting

void Call::SetVideoDeviceId(const std::string &deviceId)
{
	StringMessageData *msgData = new StringMessageData(deviceId);
	workerQueue_->Post(this, MSG_SMC_SET_VIDEO_DEVICE_ID_w, msgData);
}


void Call::SetVideoDeviceId_w(const std::string &deviceId)
{
	videoDeviceId_ = deviceId;
}


void Call::SetCallAudioConstraints(MediaConstraints *audioSourceConstraints)
{
	MediaConstraintsRefData *msgData = new MediaConstraintsRefData(audioSourceConstraints);
	workerQueue_->Post(this, MSG_SMC_SET_AUDIO_CONSTRAINTS_w, msgData);
}


void Call::SetCallAudioConstraints_w(MediaConstraints *audioSourceConstraints)
{
	if (audioConstraints_) {
		delete audioConstraints_;
	}
	audioConstraints_ = audioSourceConstraints;
}


void Call::SetCallVideoConstraints(MediaConstraints *videoSourceConstraints)
{
	MediaConstraintsRefData *msgData = new MediaConstraintsRefData(videoSourceConstraints);
	workerQueue_->Post(this, MSG_SMC_SET_VIDEO_CONSTRAINTS_w, msgData);
}


void Call::SetCallVideoConstraints_w(MediaConstraints *videoSourceConstraints)
{
	if (videoConstraints_) {
		delete videoConstraints_;
	}
	videoConstraints_ = videoSourceConstraints;
}


void Call::SetCallAudioVideoConstrains(MediaConstraints *audioSourceConstraints, MediaConstraints *videoSourceConstraints)
{
	this->SetCallAudioConstraints(audioSourceConstraints);
	this->SetCallVideoConstraints(videoSourceConstraints);
}


#pragma mark - PeerConnectionWrapper Provider Interface

PeerConnectionWrapper *Call::GetP2PWrapperForUserId(const std::string &userId)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapperRef = this->WrapperForUserId(userId);
	if (wrapperRef) {
		return wrapperRef.get();
	}
	return NULL;
}


PeerConnectionWrapper *Call::GetP2PWrapperForWrapperId(const std::string &wrapperId)
{
	spreed_me_log("The Call class shouldn't be able to provide wrappers for wrapper id since it doesn't manage token based peer connections.");
	return NULL;
}


#pragma mark - Call internal handling

void Call::ApplyCallSettings_w(rtc::scoped_refptr<PeerConnectionWrapper> wrapper)
{
	if (wrapper.get()) {
		if (audioMuted_) {
			wrapper->SetMuteAudio(true);
		}
		if (videoMuted_) {
			wrapper->SetMuteVideo(true);
		}
	}
}


#pragma mark - DataChannels

void Call::SendDataChannelMessage(const std::string &userId, const std::string &msg)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserId(userId);
	if (wrapper) {
		wrapper->SendData(msg);
	}
}


#pragma mark - Statistics

void Call::RequestStatistics()
{
	workerQueue_->Post(this, MSG_SMC_REQUEST_STATISTICS_w);
}


void Call::RequestStatistics_w()
{
	if (!statisticsWaitSet_.size()) {
		
		collectedStatReports_.clear();
		
		for (WrapperIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
			statisticsWaitSet_.insert(it->second->factoryId());
			it->second->RequestStatisticsReportsForAllStreams();
		}
		
		for (WrapperIdToWrapperMap::iterator it = closedConnections_.begin(); it != closedConnections_.end(); ++it) {
			statisticsWaitSet_.insert(it->second->factoryId());
			it->second->RequestStatisticsReportsForAllStreams();
		}
		
	} else {
		spreed_me_log("Previous statistics request is not finished yet");
	}
}


#pragma mark - rtc::MessageHandler

void Call::OnMessage(rtc::Message *msg)
{
	switch (msg->message_id) {
		case MSG_SMC_ESTABLISH_OUTGOING_CALL_w: {
			
			EstablishOutgoingCallMessageData *param = static_cast<EstablishOutgoingCallMessageData*>(msg->pdata);
			this->EstablishOutgoingCall_w(param->userId, param->constraints, param->automatic);
			delete param;
			break;
		}
			
		case MSG_SMC_ACCEPT_INCOMING_CALL_w: {
			
			UserIdSDPAndMediaConstraintsRefData *param = static_cast<UserIdSDPAndMediaConstraintsRefData*>(msg->pdata);
			this->AcceptIncomingCall_w(param->userId, param->sdp, param->constraints);
			delete param;
			break;
		}

		case MSG_SMC_RECEIVED_MESSAGE_w: {
			SignallingMessageData *param = static_cast<SignallingMessageData*>(msg->pdata);
			this->MessageReceived_w(param->msg, param->transportType, param->wrapperId);
			delete param;
			break;
		}

		case MSG_SMC_RECEIVED_BYE_MESSAGE_w: {
			SignallingByeMessageData *param = static_cast<SignallingByeMessageData*>(msg->pdata);
			this->ReceivedByeMessage_w(param->userId, param->reason);
			delete param;
			break;
		}
			
		case MSG_SMC_HANGUP_w: {
			HangupMessageData *param = static_cast<HangupMessageData*>(msg->pdata);
			this->HangUp_w(param->reason);
			delete param;
			break;
		}
		
		case MSG_SMC_SET_LOUDSPEAKER_STATUS_w: {
			BooleanMessageData *param = static_cast<BooleanMessageData*>(msg->pdata);
			this->SetLoudspeakerStatus_w(param->value);
			delete param;
			break;
		}
			
		case MSG_SMC_SET_MUTE_AUDIO_w: {
			BooleanMessageData *param = static_cast<BooleanMessageData*>(msg->pdata);
			this->MuteAudio_w(param->value);
			delete param;
			break;
		}
			
		case MSG_SMC_SET_MUTE_VIDEO_w: {
			BooleanMessageData *param = static_cast<BooleanMessageData*>(msg->pdata);
			this->MuteVideo_w(param->value);
			delete param;
			break;
		}
			
		case MSG_SMC_REQUEST_SETUP_VIDEO_RENDERER_w: {
			VideoRendererMessageData *param = static_cast<VideoRendererMessageData*>(msg->pdata);
			this->RequestToSetupVideoRenderer_w(param->userId, param->streamLabel, param->videoTrackId, param->rendererName);
			delete param;
			break;
		}
		
		case MSG_SMC_REQUEST_REMOVE_VIDEO_RENDERER_w: {
			VideoRendererMessageData *param = static_cast<VideoRendererMessageData*>(msg->pdata);
			this->RequestToDeleteVideoRenderer_w(param->userId, param->streamLabel, param->videoTrackId, param->rendererName);
			delete param;
			break;
		}
			
		case MSG_SMC_SET_VIDEO_DEVICE_ID_w: {
			StringMessageData *param = static_cast<StringMessageData*>(msg->pdata);
			this->SetVideoDeviceId_w(param->value); // value == videoDeviceId
			delete param;
			break;
		}
			
		case MSG_SMC_SET_AUDIO_CONSTRAINTS_w: {
			MediaConstraintsRefData *param = static_cast<MediaConstraintsRefData*>(msg->pdata);
			this->SetCallAudioConstraints_w(param->constraints);
			delete param;
			break;
		}
			
		case MSG_SMC_SET_VIDEO_CONSTRAINTS_w: {
			MediaConstraintsRefData *param = static_cast<MediaConstraintsRefData*>(msg->pdata);
			this->SetCallVideoConstraints_w(param->constraints);
			delete param;
			break;
		}
			
		case MSG_SMC_DISABLE_ALL_VIDEO_w: {
			this->DisableAllVideo_w();
			break;
		}
			
		case MSG_SMC_ENABLE_ALL_VIDEO_w: {
			this->EnableAllVideo_w();
			break;
		}
			
		case MSG_SMC_DISPOSE_OF_CALL_w:
			this->Dispose_w();
			break;
			
		case MSG_SMC_CALL_HAS_BEEN_CLEANED_UP_c:
			callbackQueue_->Clear(this);
			callDeleter_->CallHasBeenCleanedUp(this);
			break;
			
		case MSG_SMC_REQUEST_STATISTICS_w:
			this->RequestStatistics_w();
			break;
			
		default:
			ASSERT(false && "Not implemented");
			break;
	}
}
/*-------------------- End rtc::MessageHandler ---------------------------------*/
