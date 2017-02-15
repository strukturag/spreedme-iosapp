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

#include "ScreenSharingHandler.h"

#include <stdexcept>

enum  {
	MSG_SSH_RECEIVED_MESSAGE_w = 0,
	MSG_SSH_ESTABLISH_CONNECTION_w,
	MSG_SSH_STOP_w,
	MSG_SSH_DISABLE_ALL_VIDEO_w,
	MSG_SSH_ENABLE_ALL_VIDEO_w,
	MSG_SSH_DISPOSE_w,
	MSG_SSH_HAS_BEEN_CLEANED_UP_c,
};


using namespace spreedme;

#pragma mark - Object lifecycle

ScreenSharingHandler::ScreenSharingHandler(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
										   SignallingHandler *signallingHandler,
										   MessageQueueInterface *workerQueue,
										   MessageQueueInterface *callbacksMessageQueue) :
	TokenBasedConnectionsHandler(peerConnectionWrapperFactory,
								 signallingHandler,
								 workerQueue,
								 callbacksMessageQueue),
	delegate_(NULL),
	wrapper_(NULL),
	deleter_(new Deleter(this))
{
	
}


ScreenSharingHandler::~ScreenSharingHandler()
{
	delegate_ = NULL;
}


void ScreenSharingHandler::Dispose()
{
	workerQueue_->Post(this, MSG_SSH_DISPOSE_w);
}


void ScreenSharingHandler::Dispose_w()
{
	workerQueue_->Clear(this);
	wrapper_ = NULL;
	
	callbacksMessageQueue_->Post(this, MSG_SSH_HAS_BEEN_CLEANED_UP_c);
}


#pragma mark - MessageHandler interface

void ScreenSharingHandler::OnMessage(rtc::Message* msg)
{
	switch (msg->message_id) {
		case MSG_SSH_RECEIVED_MESSAGE_w: {
			SignallingMessageData *param = static_cast<SignallingMessageData*>(msg->pdata);
			this->MessageReceived_s(param->msg, param->transportType, param->wrapperId, param->token);
			delete param;
			break;
		}
			
		case MSG_SSH_ESTABLISH_CONNECTION_w: {
			EstablishConnectionMessageData *param = static_cast<EstablishConnectionMessageData*>(msg->pdata);
			this->EstablishConnection_s(param->token, param->userId);
			delete param;
			break;
		}
			
		case MSG_SSH_STOP_w: {
			this->Stop_w();
		}
			break;
		case MSG_SSH_DISPOSE_w: {
			this->Dispose_w();
		}
			break;
			
		case MSG_SSH_DISABLE_ALL_VIDEO_w: {
			this->DisableAllVideo_s();
			break;
		}
			
		case MSG_SSH_ENABLE_ALL_VIDEO_w: {
			this->EnableAllVideo_s();
			break;
		}
			
		case MSG_SSH_HAS_BEEN_CLEANED_UP_c: {
			callbacksMessageQueue_->Clear(this);
			deleter_->ScreenSharingHandlerHasBeenCleanedUp(this);
		}
			break;
			
		default:
			break;
	}
}


#pragma mark - Control methods

void ScreenSharingHandler::EstablishConnection(const std::string &token, const std::string &userId)
{
	EstablishConnectionMessageData *msgData = new EstablishConnectionMessageData(token, userId);
	workerQueue_->Post(this, MSG_SSH_ESTABLISH_CONNECTION_w, msgData);
}


void ScreenSharingHandler::EstablishConnection_s(const std::string &token, const std::string &userId)
{
	if (!wrapper_) {
		token_ = token;
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->CreatePeerConnectionWrapper(userId, "");
		if (wrapper) {
			wrapper->SetCustomIdentifier(this->WrapperIdForIdTokenUserId(wrapper->factoryId(), token_, userId));
			wrapper_ = wrapper;
			
			MediaConstraints constraints;
			constraints.AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, webrtc::MediaConstraintsInterface::kValueTrue);
			constraints.AddMandatory(webrtc::MediaConstraintsInterface::kOfferToReceiveAudio, webrtc::MediaConstraintsInterface::kValueFalse);
			wrapper->SetSessionDescriptionConstraints(constraints);

			wrapper_->CreateOffer(userId);
		}
	} else {
		spreed_me_log("Attempt to establish connection with already create wrapper! in ScreenSharingHandler");
	}
}


void ScreenSharingHandler::Stop()
{
	workerQueue_->Post(this, MSG_SSH_STOP_w);
}


void ScreenSharingHandler::Stop_w()
{
	wrapper_->Close();
	wrapper_->RequestStatisticsReportsForAllStreams();
}


#pragma mark - Utilities

rtc::scoped_refptr<PeerConnectionWrapper> ScreenSharingHandler::CreatePeerConnectionWrapper(const std::string &userId, const std::string &wrapperId)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = peerConnectionWrapperFactory_->CreateSpreedPeerConnection(userId, this);
	if (wrapper) {
		if (!wrapperId.empty()) {
			wrapper->SetCustomIdentifier(wrapperId);
		}
	}
	return wrapper;
}


#pragma mark - PeerConnectionWrapper delegate

void ScreenSharingHandler::RemoteStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
	for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
		videoTracksIds.push_back(it->get()->id());
	}
	
	// setup renderer
	if (wrapper_.get() == peerConnectionWrapper && videoTracksIds.size() > 0 && rendererName_.empty()) {
		rendererName_ = "ScreenSharingHandler" + videoTracksIds[0];
		wrapper_->SetupVideoRenderer(scoped_stream->label(), videoTracksIds[0], rendererName_);
	}
}


void ScreenSharingHandler::RemoteStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper)
{
	rtc::scoped_refptr<webrtc::MediaStreamInterface> scoped_stream(stream); // keep reference
	
	STDStringVector videoTracksIds;
	webrtc::VideoTrackVector videoTracks = scoped_stream->GetVideoTracks();
	for (webrtc::VideoTrackVector::iterator it = videoTracks.begin(); it != videoTracks.end(); ++it) {
		videoTracksIds.push_back(it->get()->id());
	}
	
	//TODO: Check if remote removed stream with the video track we are rendering now
}


void ScreenSharingHandler::VideoRendererWasSetup(PeerConnectionWrapper *peerConnectionWrapper,
												 const VideoRendererInfo &info)
{
	if (rendererName_ == info.rendererName) {
		rendererView_ = info.videoView;
		
		if (delegate_) {
			delegate_->ScreenSharingHasStarted(this, token_, peerConnectionWrapper->userId(), rendererView_, rendererName_);
		}
		
	} else {
		spreed_me_log("Unexpected renderer name in screensharing handler!");
	}
}


void ScreenSharingHandler::VideoRendererHasChangedFrameSize(PeerConnectionWrapper *peerConnectionWrapper,
															const VideoRendererInfo &info)
{
	if (rendererName_ == info.rendererName) {
		if (delegate_) {
			delegate_->ScreenSharingHasChangedFrameSize(this,
														token_,
														peerConnectionWrapper->userId(),
														rendererName_,
														info.frameWidth,
														info.frameHeight);
		}
	} else {
		spreed_me_log("Unexpected renderer name in screensharing handler on frame size changed event!");
	}
}


void ScreenSharingHandler::VideoRendererWasDeleted(PeerConnectionWrapper *peerConnectionWrapper,
												   const VideoRendererInfo &info)
{
	spreed_me_log("Video renderer was deleted in screensharing handler!");
}


void ScreenSharingHandler::FailedToSetupVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
													  const VideoRendererInfo &info,
													  VideoRendererManagementError error)
{
	spreed_me_log("Failed to setup video renderer in screensharing handler!");
}


void ScreenSharingHandler::FailedToDeleteVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
													   const VideoRendererInfo &info,
													   VideoRendererManagementError error)
{
	spreed_me_log("Failed to delete video renderer in screensharing handler!");
}


void ScreenSharingHandler::AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendAnswer(sdType, sdp, token_, peerConnectionWrapper->factoryId(), peerConnectionWrapper);
}


void ScreenSharingHandler::OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendOffer(sdType, sdp, token_, peerConnectionWrapper->factoryId(), std::string(), peerConnectionWrapper);
}


void ScreenSharingHandler::CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper)
{
	if (candidate->sdp_mid == "audio") {
		spreed_me_log("Not sending audio ice candidate while from screensharing peer connection.\n");
		return;
	}
	
	signallingHandler_->SendCandidate(candidate, token_, peerConnectionWrapper->factoryId(), peerConnectionWrapper);
}


void ScreenSharingHandler::DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper)
{
	spreed_me_log("Received data channel in ScreenSharingHandler!");
}


void ScreenSharingHandler::ReceivedDataChannelData(webrtc::DataBuffer *buffer,
												   webrtc::DataChannelInterface *data_channel,
												   PeerConnectionWrapper *wrapper)
{
	if (!buffer->binary) {
		std::string strMsg = std::string(buffer->data.data(), buffer->data.length());
		Json::Reader jsonReader;
		Json::Value root;
		Json::Value message;
		
		bool success = jsonReader.parse(strMsg, message);
		if (success) {
			
			std::string m = message.get("m", Json::Value()).asString();
			
			if (m == kLCByeKey) {
				if (delegate_) {
					delegate_->ScreenSharingHasStopped(this, token_, wrapper->userId());
				}
				
				this->Stop();
				
				spreed_me_log("Remote peer has stopped sharing screen;");
			} else {
				spreed_me_log("Received unexpected message in screensharing handler %s", message.toStyledString().c_str());
			}
			
		} else {
			spreed_me_log("Not a JSON message");
			//Maybe handle this non-json message somehow later. At the moment we don't have any non-json text messages
		}
		
	} else {
		spreed_me_log("Received binary buffer");
	}
	
	delete buffer;
}


void ScreenSharingHandler::IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *peerConnectionWrapper)
{
	switch (new_state) {
		case webrtc::PeerConnectionInterface::kIceConnectionNew:
		case webrtc::PeerConnectionInterface::kIceConnectionChecking:
			break;
			
		case webrtc::PeerConnectionInterface::kIceConnectionConnected:
		case webrtc::PeerConnectionInterface::kIceConnectionCompleted:
			if (delegate_) {
				delegate_->ScreenSharingConnectionEstablished(this, token_, peerConnectionWrapper->userId());
			}
			break;
		
		case webrtc::PeerConnectionInterface::kIceConnectionDisconnected:
			if (delegate_) {
				delegate_->ScreenSharingConnectionLost(this, token_, peerConnectionWrapper->userId());
			}
			break;
			
		case webrtc::PeerConnectionInterface::kIceConnectionClosed:
		case webrtc::PeerConnectionInterface::kIceConnectionFailed:
			//TODO: Check maybe we want to process error in case of kIceConnectionFailed
			if (delegate_) {
				delegate_->ScreenSharingHasStopped(this, token_, peerConnectionWrapper->userId());
			}
			break;
			
		
		default:
			break;
	}
}


void ScreenSharingHandler::PeerConnectionWrapperHasReceivedStats(PeerConnectionWrapper *peerConnectionWrapper, const webrtc::StatsReports &reports)
{
	if (peerConnectionWrapper == wrapper_) {
		if (delegate_) {
			webrtc::StatsReports copyReports = reports;
			delegate_->ScreenSharingHandlerHasBeenClosed(this, token_, wrapper_->userId(), copyReports);
		}
	} else {
		spreed_me_log("Received stats from unknown peer connection wrapper");
	}
}


void ScreenSharingHandler::PeerConnectionWrapperHasFailedToReceiveStats(PeerConnectionWrapper *peerConnectionWrapper)
{
	if (peerConnectionWrapper == wrapper_) {
		if (delegate_) {
			delegate_->ScreenSharingHandlerHasBeenClosed(this, token_, wrapper_->userId(), webrtc::StatsReports());
		}
	} else {
		spreed_me_log("Received error for stats from unknown peer connection wrapper");
	}
}


#pragma mark - Signalling messages handling

void ScreenSharingHandler::MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
{
	SignallingMessageData *msgData = new SignallingMessageData(msg, transportType, wrapperId, token);
	workerQueue_->Post(this, MSG_SSH_RECEIVED_MESSAGE_w, msgData);
}


void ScreenSharingHandler::ReceivedOffer_s(const Json::Value &offerJson, const std::string &from)
{
	spreed_me_log("We don't really expect to receive offer in ScreenSharingHandler");
}


void ScreenSharingHandler::ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from)
{
	Json::Value unwrappedAnswer = answerJson.get(kAnswerKey, Json::Value());
	if (!unwrappedAnswer.isNull()) {
		
		std::string sdp = unwrappedAnswer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
		std::string id = unwrappedAnswer.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = unwrappedAnswer.get(kDataChannelTokenKey, Json::Value()).asString();
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = NULL;
		
		if (wrapper_->factoryId() == id && token_ == token) {
			wrapper = wrapper_;
		}
		
		if (wrapper) {
			if (wrapper->signalingState() == webrtc::PeerConnectionInterface::kHaveLocalOffer) {
				if (!sdp.empty()) {
					wrapper->SetupRemoteAnswer(sdp);
				}
			}
		}
	}
}


void ScreenSharingHandler::ReceivedCandidate_s(const Json::Value &candidateJson, const std::string &from)
{
	Json::Value unwrappedCandidate = candidateJson.get(kCandidateKey, Json::Value());
	if (!unwrappedCandidate.isNull()) {
		
		std::string id = unwrappedCandidate.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = unwrappedCandidate.get(kDataChannelTokenKey, Json::Value()).asString();
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = NULL;
		
		if (wrapper_->factoryId() == id && token_ == token) {
			wrapper = wrapper_;
		}
		
		if (wrapper) {
			
			std::string sdpMid = unwrappedCandidate.get(kCandidateSdpMidKey, Json::Value()).asString();
			
			int sdpMLineIndex = -1;
			Json::Value sdpMLineIndexValue = unwrappedCandidate.get(kCandidateSdpMlineIndexKey, Json::Value());
			if (!sdpMLineIndexValue.isNull()) {
				sdpMLineIndex = sdpMLineIndexValue.asInt();
			}
			
			std::string candidateString = unwrappedCandidate.get(kCandidateSdpKey, Json::Value()).asString();
			
			if (sdpMLineIndex > -1) {
				if (sdpMid != "audio") {
					wrapper->SetupRemoteCandidate(sdpMid, sdpMLineIndex, candidateString);
				} else {
					spreed_me_log("Discarding audio ice candidate while from screenshare peer connection.");
				}
			} else {
				throw std::runtime_error("Candidate inline index is not correct!!!");
			}
		}
	} else {
		spreed_me_log("Problem with parsing candidate! \n");
	}
}


#pragma mark - Video control messages

void ScreenSharingHandler::DisableAllVideo()
{
	workerQueue_->Send(this, MSG_SSH_DISABLE_ALL_VIDEO_w);
}


void ScreenSharingHandler::DisableAllVideo_s()
{
	if (wrapper_) {
		wrapper_->DisableAllVideo();
	}
}


void ScreenSharingHandler::EnableAllVideo()
{
	workerQueue_->Post(this, MSG_SSH_ENABLE_ALL_VIDEO_w);
}


void ScreenSharingHandler::EnableAllVideo_s()
{
	if (wrapper_) {
		wrapper_->EnableAllVideo();
	}
}

