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

#ifndef __SpreedME__Call__
#define __SpreedME__Call__

#include <iostream>
#include <map>

#include <talk/app/webrtc/mediastreaminterface.h>

#include "CommonCppTypes.h"
#include "MessageQueueInterface.h"
#include "PeerConnectionWrapper.h"
#include "PeerConnectionWrapperFactory.h"
#include "SignallingHandler.h"
#include "VideoRendererInfo.h"
#include "WebrtcCommonDefinitions.h"


namespace spreedme {
	

typedef enum CallState
{
	kSMCStateNotReady = 0, // Call is not ready to receive/send offers for any reason
	kSMCStateReady, // Call is ready to receive/send offers and is not in any call
	kSMCStateSinglePeerCall, // Call is in single peer call state
	kSMCStateConferenceCall, // Call is in conference call state
	kSMCStateWaitingForConferenceMixerCall, // Call is waiting for conference mixer call
	kSMCStateFinished, // Call has been finished and is usable only for statistics queries
}
CallState;
	
	
typedef enum {
	kCallFinishReasonUnspecified = 0,
	kCallFinishReasonLocalHangUp,
	kCallFinishReasonRemoteHungUp,
	kCallFinishReasonInternalError,
} CallFinishReason;


class Call;

class CallDelegateInterface {
public:
	
	// ----------- Call events
	// this is called when we establish first call/connection whatsoever so we need to present call UI first
	virtual void FirstOutgoingCallStarted(Call *call, const std::string &userId, bool withVideo) = 0;
	// this is called when we already in a call and start establishing another call
	virtual void OutgoingCallStarted(Call *call, const std::string &userId) = 0;
	//these function calls are analogous to outgoing calls
	virtual void FirstIncomingCallReceived(Call *call, const std::string &userId) = 0;
	virtual void IncomingCallReceived(Call *call, const std::string &userId) = 0;
	
	virtual void RemoteUserHangUp(Call *call, const std::string &userId) = 0;
	virtual void CallIsFinished(Call *call, CallFinishReason finishReason) = 0;
	virtual void IncomingCallWasAutoRejected(Call *call, const std::string &userId) = 0;
	
	virtual void ConnectionEstablished(Call *call, const std::string &userId) = 0;
	virtual void ConnectionLost(Call *call, const std::string &userId) = 0;
	virtual void ConnectionFailed(Call *call, const std::string &userId) = 0;
	
	virtual void CallHasStarted(Call *call) {}; // Called when first connection is established.
												// By that time audio module should be already activated.
	
	
	// ----------- Call errors
	virtual void CallHasEncounteredAnError(Call *call, const Error &error) = 0;
	
	
	// ----------- Streams events
	virtual void LocalStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds) = 0;
	virtual void LocalStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds) = 0;
	virtual void RemoteStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds) = 0;
	virtual void RemoteStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds) = 0;
	
	
	// ----------- Video renderers
	virtual void VideoRendererWasCreated(Call *call,
										 const VideoRendererInfo &rendererInfo) = 0;
	virtual void VideoRendererHasSetFrame(Call *call,
										  const VideoRendererInfo &rendererInfo) = 0;
	virtual void VideoRendererWasDeleted(Call *call,
										 const VideoRendererInfo &rendererInfo) = 0;
	virtual void FailedToSetupVideoRenderer(Call *call,
											const VideoRendererInfo &rendererInfo,
											VideoRendererManagementError error) {};
	virtual void FailedToDeleteVideoRenderer(Call *call,
											 const VideoRendererInfo &rendererInfo,
											 VideoRendererManagementError error) {};
	
	
	// ----------- Token data channel events
	virtual void TokenDataChannelOpened(Call *call, const std::string &userId, const std::string &wrapperId) = 0;
	virtual void TokenDataChannelClosed(Call *call, const std::string &userId, const std::string &wrapperId) = 0;
	
	
	// ----------- Statistics
	virtual void CallHasReceivedStatistics(Call *call, const webrtc::StatsReports &reports) = 0;
	
	
	virtual ~CallDelegateInterface() {};
};

class CallPrivateDeletionInterface
{
public:
	virtual void CallHasBeenCleanedUp(Call *call) = 0;
	virtual ~CallPrivateDeletionInterface() {};
};
	
	
struct PendingOfferPackage {
	//This structure is used to encapsulate both sdp and conferenceId in one object for convenience
	PendingOfferPackage(std::string sdp, std::string conferenceId) : sdp(sdp), conferenceId(conferenceId) {};
	
	std::string sdp;
	std::string conferenceId;
};

typedef std::map<std::string, PendingOfferPackage> UserIdToPendindOfferPackageMap;
typedef std::pair<std::string, PendingOfferPackage> UserIdToPendingOfferPackagePair;
    
typedef std::map<std::string, bool> AutomaticOutgoingCallPendingOfferMap;
typedef std::pair<std::string, bool> UserIdToAutomaticOfferPair;

	
class Call : public PeerConnectionWrapperDelegateInterface,
			 public SignallingMessageReceiverInterface,
			 public PeerConnectionWrapperProviderInterface,
			 public rtc::MessageHandler
	
{
	friend class CallDeleter;
public:
	
	// Due to the problems with rtc::Thread and main thread on iOS
	// https://code.google.com/p/webrtc/issues/detail?id=3547
	// worker queue should never be main thread.
	// Worker queue should never be the same as callbackQueue otherwise deadlocks possible.
	// Worker and callbackQueue should live longer than call instance!
	explicit Call(std::string selfId,
				  PeerConnectionWrapperFactory *peerConnectionWrapperFactory, // call doesn't take ownership
				  SignallingHandler* signallingHandler, // call doesn't take ownership
				  MessageQueueInterface *workerQueue, // call doesn't take ownership
				  MessageQueueInterface *callbackQueue); // call doesn't take ownership
	
	// This method is the correct way to delete call.
	virtual void Dispose();
	
	// ----------- Delegates, signalling handler
	virtual void SetSignallingHandler(SignallingHandler *signallingHandler) { critSect_->Enter(); signallingHandler_ = signallingHandler; critSect_->Leave(); };
	virtual void SetDelegate(CallDelegateInterface *delegate) { critSect_->Enter(); delegate_ = delegate; critSect_->Leave(); };
	
	
	// ----------- Statistics and call information
	virtual const std::string CallId() {return callId_;};
	
	// Requests statistics for every audio and video track in every peer connection in the call.
	// This call does nothing if previous call has not finished gathering statistics.
	virtual void RequestStatistics();

	virtual CallState state() {critSect_->Enter(); CallState state = state_; critSect_->Leave(); return state;};
	
	virtual std::vector<std::string> GetUsersIds();
	virtual std::set<std::string> GetUsersIdsAsSet();
	virtual int usersOnCallCount();
	
	virtual bool audioMuted() { critSect_->Enter(); bool audioMuted = audioMuted_; critSect_->Leave(); return audioMuted; };
	virtual bool videoMuted() { critSect_->Enter(); bool videoMuted = videoMuted_; critSect_->Leave(); return videoMuted; };
	
	virtual bool HasVideo();
	virtual size_t NumberOfLocalVideoStreams();
	virtual size_t NumberOfRemoteVideoStreams();
	virtual size_t NumberOfRemoteStreams(); // calculates all streams which have at least one audio track. These streams may/may not have video tracks
	
	
	// ----------- Signalling
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId); //s
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token); //empty implementation
	
	
	// ----------- Call control actions
	virtual void AcceptIncomingCall(const std::string &userId, const std::string &sdp, MediaConstraints *mediaConstraints);
	virtual void EstablishOutgoingCall(const std::string &userId, MediaConstraints *mediaConstraints, bool automatic);
	
	virtual void HangUp(ByeReason reason); //hangs up active call, sends bye to every user in active call
	virtual void ReceivedByeMessage(const std::string &userId, ByeReason reason); 
	
	virtual void MuteAudio(bool onOff);
	virtual void MuteVideo(bool onOff);
	
	virtual void SetLoudspeakerStatus(bool onOff);
	
	virtual void DisableAllVideo(); // This method is synchronous
	virtual void EnableAllVideo(); // This method is asynchronous
	
	// Requests underlying PeerConnectionWrapper with 'userId'
	// to create and setup video or delete renderer for video track with 'videoTrackId'
	// in stream with label 'streamLabel'.
	// 'rendererName' is to keep track of the renderers. It must be unique for one videoTrack
	// Delegate method will report creation or deletion
	virtual void RequestToSetupVideoRenderer(const std::string &userId,
											 const std::string &streamLabel,
											 const std::string &videoTrackId,
											 const std::string &rendererName);
	virtual void RequestToDeleteVideoRenderer(const std::string &userId,
											  const std::string &streamLabel,
											  const std::string &videoTrackId,
											  const std::string &rendererName);
	
	
	// ----------- Call constraints
	virtual void SetVideoDeviceId(const std::string &deviceId);
	// Call takes ownership of constraints. Constraints are applied to the next call and do not affect the current one
	virtual void SetCallAudioConstraints(MediaConstraints *audioSourceConstraints);
	virtual void SetCallVideoConstraints(MediaConstraints *videoSourceConstraints);
	// convenience method. Internally calls 'SetCallAudioConstraints()' and 'SetCallVideoConstraints()'
	virtual void SetCallAudioVideoConstrains(MediaConstraints *audioSourceConstraints, MediaConstraints *videoSourceConstraints);
	
	
protected:
	
	virtual ~Call();
	
	// ----------- Peer connection wrapper delegate interface implementation
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *spreedPeerConnection);
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper);
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	virtual void VideoRendererWasSetup(PeerConnectionWrapper *peerConnectionWrapper,
									   const VideoRendererInfo &info);
	virtual void VideoRendererHasChangedFrameSize(PeerConnectionWrapper *peerConnectionWrapper,
												  const VideoRendererInfo &info);
	virtual void VideoRendererWasDeleted(PeerConnectionWrapper *peerConnectionWrapper,
										 const VideoRendererInfo &info);
	virtual void FailedToSetupVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
											const VideoRendererInfo &info,
											VideoRendererManagementError error);
	virtual void FailedToDeleteVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
											 const VideoRendererInfo &info,
											 VideoRendererManagementError error);
	virtual void LocalStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void LocalStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void RemoteStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void RemoteStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void PeerConnectionWrapperHasReceivedStats(spreedme::PeerConnectionWrapper *peerConnectionWrapper, const webrtc::StatsReports &reports);
	virtual void PeerConnectionWrapperHasEncounteredError(PeerConnectionWrapper *peerConnectionWrapper, const Error &error);
	
	// ----------- Conference related methods
	virtual std::string CreateConferenceId();
	virtual void CreateConference();
	
	// ----------- PeerConnectionWrapperProviderInterface implementation
	virtual PeerConnectionWrapper *GetP2PWrapperForUserId(const std::string &userId);
	virtual PeerConnectionWrapper *GetP2PWrapperForWrapperId(const std::string &wrapperId);
	
	virtual void SendDataChannelMessage(const std::string &userId, const std::string &msg);
	
	virtual void ProcessDefaultAudioVideoOffer(const Json::Value &unwrappedOffer, const std::string &from);
	virtual void ProcessDataChannelTokenOffer(const Json::Value &unwrappedOffer, const std::string &from);
		
	bool IsChannelingMessage(const Json::Value &msg);
	
	virtual void ReceivedOffer(const Json::Value &offerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedAnswer(const Json::Value &answerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedCandidate(const Json::Value &candidateJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedConferenceDocument(const Json::Value &conferenceJson); //expects inner JSON (without Data :{})
	
	virtual void NewIncomingCall(const std::string &userId, const std::string &sdp, const std::string &conferenceId);
	virtual void NewIncomingCall(const std::string &userId, const Json::Value &jsonOffer);
	virtual void HangUpUser(const std::string &userId);
	virtual void SendBye(const std::string &userId, ByeReason reason); // DOES NOT erase peer connection and only sends bye to specified user (e.g. reject offer)
	
	rtc::scoped_refptr<PeerConnectionWrapper> CreatePeerConnectionWrapper(const std::string &userId);
	virtual void CloseCall(ByeReason reason, bool sendBye = true);
	virtual void FinishCall(ByeReason reason, bool shouldSendBye, CallFinishReason finishReason);
	
	virtual void AddDefaultStreamToPeerConnectionWrapper(const std::string &userId);
	virtual void AddDefaultStreamToPeerConnectionWrapper(rtc::scoped_refptr<PeerConnectionWrapper> wrapper);
	
	virtual void ForceAddMandatoryConstraint(MediaConstraints *constraints, const std::string &constraintName, const std::string &constraintValue);
	virtual bool ShouldAddVideoTrackForWrapper(rtc::scoped_refptr<PeerConnectionWrapper> wrapper, bool forceNoVideo);
	virtual MediaConstraints ProcessConstraints(MediaConstraints *mediaConstraints, bool forceDisableVideo);
	
	virtual size_t NumberOfStreams(bool local, bool countVideoStreamsOnly = false);
	
	virtual void ApplyCallSettings_w(rtc::scoped_refptr<PeerConnectionWrapper> wrapper);
	
	// ----------- rtc::MessageHandler implementation
	virtual void OnMessage(rtc::Message* msg);
	
	// ----------- explicit worker queue methods
	virtual void Dispose_w();
	virtual void EstablishOutgoingCall_w(const std::string &userId, MediaConstraints *mediaConstraints, bool automatic);
	virtual void AcceptIncomingCall_w(const std::string &userId, const std::string &sdp, MediaConstraints *mediaConstraints);
	virtual void MessageReceived_w(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId);
	virtual void ReceivedByeMessage_w(const std::string &userId, ByeReason reason);
	virtual void HangUp_w(ByeReason reason);
	virtual void MuteAudio_w(bool onOff);
	virtual void MuteVideo_w(bool onOff);
	virtual void SetLoudspeakerStatus_w(bool onOff);
	virtual void SetVideoDeviceId_w(const std::string &deviceId);
	virtual void SetCallAudioConstraints_w(MediaConstraints *audioSourceConstraints);
	virtual void SetCallVideoConstraints_w(MediaConstraints *videoSourceConstraints);
	virtual void DisableAllVideo_w();
	virtual void EnableAllVideo_w();
	virtual void RequestToSetupVideoRenderer_w(const std::string &userId,
											   const std::string &streamLabel,
											   const std::string &videoTrackId,
											   const std::string &rendererName);
	virtual void RequestToDeleteVideoRenderer_w(const std::string &userId,
												const std::string &streamLabel,
												const std::string &videoTrackId,
												const std::string &rendererName);
	virtual void RequestStatistics_w();
	

	
private:
	Call() : critSect_(webrtc::CriticalSectionWrapper::CreateCriticalSection()) {};
	
	// Utility methods
	rtc::scoped_refptr<PeerConnectionWrapper> WrapperForUserId(const std::string &userId);
	bool InsertNewWrapperWithUserId(rtc::scoped_refptr<PeerConnectionWrapper> wrapper, std::string userId);
	bool WrapperForUserIdExists(const std::string &userId);
	bool CheckIfRegisteredWrapper(PeerConnectionWrapper *wrapper);
	
	void SetupPeerConnectionFactory();
	
	//variables--------------------------------------------------------------------------------
	webrtc::CriticalSectionWrapper *critSect_;
	
	std::string callId_;
	PeerConnectionWrapperFactory *peerConnectionWrapperFactory_; // we do NOT own it
	
	SignallingHandler *signallingHandler_; // we do NOT own it
	CallDelegateInterface *delegate_; // we do NOT own it
	
	CallState state_;
	
	std::string selfId_;
	std::string conferenceId_;
	
	std::vector<std::string> conferenceUserIDs_;
	
	UserIdToWrapperMap activeConnections_;
	UserIdToWrapperMap closedConnections_;
	
	UserIdToPendindOfferPackageMap pendingOffers_;
	
	std::string *pendingOffer_;
    
    AutomaticOutgoingCallPendingOfferMap pendingOutgoingCallOffers_;
	
	std::string *pendingConferenceMixerId_;
	
	bool atLeastOneWasConnectionEstablished_;
	
	bool audioMuted_;
	bool videoMuted_;
	
	std::string videoDeviceId_;
	MediaConstraints *audioConstraints_;
	MediaConstraints *videoConstraints_;
	
	MessageQueueInterface *workerQueue_; // we don't own it
	MessageQueueInterface *callbackQueue_; // we don't own it
	
	CallPrivateDeletionInterface *callDeleter_; // this object deletes itself
	
	webrtc::StatsReports collectedStatReports_;
	
	// This is a set of wrapper factory ids of wrappers for which we wait for statistics.
	// We only call statistics callback when this list is empty.
	// We populate this list when receive 'RequestStatistics()' call
	std::set<std::string> statisticsWaitSet_;
};

	
	
class CallDeleter : public CallPrivateDeletionInterface
{
public:
	CallDeleter(Call *call) : call_(call) {};
	virtual ~CallDeleter() {};
	
	void CallHasBeenCleanedUp(Call *call) {
		if (call_ == call) {
			delete call;
			delete this;
		} else {
			spreed_me_log("Strange call instance to delete");
		}
	};
private:
	Call *call_;
};
	

}; //namespace spreedme


#endif /* defined(__SpreedME__Call__) */
