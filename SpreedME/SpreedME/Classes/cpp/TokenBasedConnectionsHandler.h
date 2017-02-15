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

#ifndef __SpreedME__TokenBasedConnectionsHandler__
#define __SpreedME__TokenBasedConnectionsHandler__

#include <iostream>

#include "CommonCppTypes.h"
#include "MessageQueueInterface.h"
#include "PeerConnectionWrapper.h"
#include "PeerConnectionWrapperFactory.h"
#include "SignallingHandler.h"


namespace spreedme {

class TokenBasedConnectionsHandler : public rtc::RefCountInterface,
									 public rtc::MessageHandler,
									 public PeerConnectionWrapperDelegateInterface,
									 public SignallingMessageReceiverInterface
{

public:
/*
 peerConnectionWrapperFactory - cannot be NULL
 signallingHandler - this object should take care of multithreading in messages.
 workerQueue -	all work related to webrtc is done here,
				all PeerConnectionWrappers should live exclusively in this thread.
				If NULL, rtc::Thread is created.
				Should NOT be a main thread!
 callbacksThread -	all delegate callbacks are rooted here.
					shouldn't be NULL
 */
	TokenBasedConnectionsHandler(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
								 SignallingHandler *signallingHandler,
								 MessageQueueInterface *workerQueue,
								 MessageQueueInterface *callbacksMessageQueue);
	
	
protected:
	TokenBasedConnectionsHandler();
	virtual ~TokenBasedConnectionsHandler();
	
	static std::string CreateWrapperIdForOutgoingOffer(const std::string &token, const std::string &to);
	static std::string WrapperIdForIdTokenUserId(const std::string &id, const std::string &token, const std::string &userId);
	static std::string IdForWrapperId(const std::string &wrapperId);
	
	// rtc::MessageHandler interface
	virtual void OnMessage(rtc::Message* msg) = 0;
	
	// Peer connection wrapper delegate interface implementation
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *spreedPeerConnection) = 0;
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper) = 0;
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper) = 0;
	
	// Message receiver interface implementation
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId)
	{ spreed_me_log("Received non token message. This should not happen!\n"); };
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token) = 0; // should be implemented in subclasses
	
	// generic signalling methods which should be run in signalling thread
	virtual void MessageReceived_s(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token);
	virtual void ReceivedOffer_s(const Json::Value &offerJson, const std::string &from) = 0; // expects inner JSON (without Data :{})
	virtual void ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from) = 0; // expects inner JSON (without Data :{})
	virtual void ReceivedCandidate_s(const Json::Value &candidateJson, const std::string &from) = 0; // expects inner JSON (without Data :{})
		
	// These methods should be used carefully in multithreaded environment since they rely on PeerConnectionWrapperFactory implementation
	virtual rtc::scoped_refptr<PeerConnectionWrapper> CreatePeerConnectionWrapper(const std::string &userId, const std::string &wrapperId);
	virtual rtc::scoped_refptr<PeerConnectionWrapper> CreatePeerConnectionWrapper(const std::string &userId);

	
	
	// Instance variables ----------------------------------------------------------------------
	webrtc::CriticalSectionWrapper *critSect_;
	
	PeerConnectionWrapperFactory *peerConnectionWrapperFactory_; // We do not own it!
	SignallingHandler *signallingHandler_; // We do not own it!
	
	MessageQueueInterface *workerQueue_; // We do not own it!
	MessageQueueInterface *callbacksMessageQueue_; // We do not own it!
	
	std::string token_;
	
private:
	
};

} // namespace spreedme


#endif /* defined(__SpreedME__TokenBasedConnectionsHandler__) */
