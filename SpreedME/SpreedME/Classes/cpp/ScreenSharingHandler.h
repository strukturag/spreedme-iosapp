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

#ifndef __SpreedME__ScreenSharingHandler__
#define __SpreedME__ScreenSharingHandler__

#include <iostream>

#include "TokenBasedConnectionsHandler.h"

namespace spreedme {

class ScreenSharingHandler;
	
class ScreenSharingHandlerDelegateInterface
{
public:	
	virtual void ScreenSharingHasStarted(ScreenSharingHandler *handler,
										 const std::string &token,
										 const std::string &userId,
										 void *videoView,
										 const std::string &renderName) = 0;
	virtual void ScreenSharingHasStopped(ScreenSharingHandler *handler,
										 const std::string &token,
										 const std::string &userId) = 0;
	
	virtual void ScreenSharingHasChangedFrameSize(ScreenSharingHandler *handler,
												  const std::string &token,
												  const std::string &userId,
												  const std::string &renderName,
												  int width, int height) = 0;
	
	virtual void ScreenSharingConnectionEstablished(ScreenSharingHandler *handler,
													const std::string &token,
													const std::string &userId) = 0;
	virtual void ScreenSharingConnectionLost(ScreenSharingHandler *handler,
											 const std::string &token,
											 const std::string &userId) = 0;
	
	virtual void ScreenSharingHandlerHasBeenClosed(ScreenSharingHandler *handler,
												   const std::string &token,
												   const std::string &userId,
												   const webrtc::StatsReports &reports) = 0;
};


class ScreenSharingHandler : public TokenBasedConnectionsHandler {
public:
	struct EstablishConnectionMessageData : public rtc::MessageData {
		explicit EstablishConnectionMessageData (std::string token, std::string userId) : token(token), userId(userId) {};
		
		std::string token;
		std::string userId;
	};
	
	class ScreenSharingHandlerPrivateDeletionInterface
	{
	public:
		virtual void ScreenSharingHandlerHasBeenCleanedUp(ScreenSharingHandler *handler) = 0;
		virtual ~ScreenSharingHandlerPrivateDeletionInterface() {};
	};
	
	class Deleter : public ScreenSharingHandlerPrivateDeletionInterface
	{
	public:
		Deleter(ScreenSharingHandler *handler) : handler_(handler) {};
		void ScreenSharingHandlerHasBeenCleanedUp(ScreenSharingHandler *handler) {delete handler_; delete this;}
	private:
		ScreenSharingHandler *handler_;
	};
	
	
public:
	ScreenSharingHandler(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
						 SignallingHandler *signallingHandler,
						 MessageQueueInterface *workerQueue,
						 MessageQueueInterface *callbacksMessageQueue);
	
	virtual void EstablishConnection(const std::string &token, const std::string &userId);
	
	virtual void SetDelegate(ScreenSharingHandlerDelegateInterface *uiDelegate) { critSect_->Enter(); delegate_ = uiDelegate; critSect_->Leave(); };
	
	virtual void Stop();
	virtual void Dispose();
	
	virtual void DisableAllVideo(); // This method is synchronous
	virtual void EnableAllVideo(); // This method is asynchronous
	
protected:
	ScreenSharingHandler();
	virtual ~ScreenSharingHandler();
	
	virtual void OnMessage(rtc::Message* msg);
	
	std::string CreateWrapperIdForOutgoingOffer(const std::string &token, const std::string &to);
	
	rtc::scoped_refptr<PeerConnectionWrapper> CreatePeerConnectionWrapper(const std::string &userId, const std::string &wrapperId);
	
	// Peer connection wrapper delegate interface implementation
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *spreedPeerConnection);
	virtual void RemoteStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void RemoteStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper);
	
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
	
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper);
	
	virtual void PeerConnectionWrapperHasReceivedStats(PeerConnectionWrapper *peerConnectionWrapper, const webrtc::StatsReports &reports);
	virtual void PeerConnectionWrapperHasFailedToReceiveStats(PeerConnectionWrapper *peerConnectionWrapper);
	
	// Message receiver interface implementation
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token);
	
	virtual void ReceivedOffer_s(const Json::Value &offerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedCandidate_s(const Json::Value &candidateJson, const std::string &from);
	
	// Explicit worker thread methods
	virtual void EstablishConnection_s(const std::string &token, const std::string &userId);
	virtual void Stop_w();
	virtual void Dispose_w();
	
	virtual void DisableAllVideo_s();
	virtual void EnableAllVideo_s();
	
	// Instance variables ---------------
	
	ScreenSharingHandlerDelegateInterface *delegate_;
	
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper_;
	
	std::string rendererName_;
	void *rendererView_;
	
	Deleter *deleter_;
};

	
} // namespace spreedme

#endif /* defined(__SpreedME__ScreenSharingHandler__) */
