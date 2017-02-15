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

#ifndef __SpreedME__SignallingHandler__
#define __SpreedME__SignallingHandler__

#include <iostream>
#include <map>
#include <set>

#include "SignallingHandlerInterface.h"

#include <webrtc/base/json.h>
#include <talk/app/webrtc/datachannelinterface.h>

#include "WebrtcCommonDefinitions.h"

namespace spreedme {

class PeerConnectionWrapper;

class DataChannelDataHandlerInterface {
public:
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper) = 0;
};


class SignallingHandler : public SignallingHandlerInterface,
						  public DataChannelDataHandlerInterface
{
public:
	
	SignallingHandler(std::string selfId, ServerBasedMessageSenderInterface *serverSender) :
		serverSender_(serverSender), wrapperProvider_(NULL), selfId_(selfId) {};
	
	virtual void SetSelfId(const std::string &selfId) {selfId_ = selfId;};
	virtual std::string selfId() {return selfId_;};
	virtual void SetWrapperProvider(PeerConnectionWrapperProviderInterface *wrapperProvider) {wrapperProvider_ = wrapperProvider;};
	
	//================= SignallingHandlerInterface implementation =====
	virtual void SendMessage(const std::string &type, const std::string &msg);
	virtual void SendP2PMessage(const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void SendMessage(const std::string &type, const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void SendMessage(const std::string &type, const std::string &msg, const std::string &userId);
	virtual void SendMessage(const std::string &type, const std::string &msg, const std::string &userId, const std::string &wrapperId);
	
	virtual void ReceiveMessage(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId);
	
	virtual void RegisterMessageReceiver(SignallingMessageReceiverInterface *receiver);
	virtual void UnRegisterMessageReceiver(SignallingMessageReceiverInterface *receiver);

	virtual void RegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver);
	virtual void UnRegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver);
	
	//================= Convenience methods ==============
	/*
	 Sends Bye to @userId with @reason.
	 If @peerConnectionWrapper is not NULL and has working data channel sends it P2P.
	 */
	virtual void SendBye(const std::string &userId, ByeReason reason, PeerConnectionWrapper *peerConnectionWrapper);
	
	// These methods send their respected documents to peerConnectionWrapper's userId. If peerConnectionWrapper data channel works sends it P2P.
	virtual void SendAnswer(webrtc::SessionDescriptionInterface* desc,
							const std::string &token,
							const std::string &id,
							PeerConnectionWrapper *peerConnectionWrapper);
	virtual void SendAnswer(const std::string &sdType,
							const std::string &sdpString,
							const std::string &token,
							const std::string &id,
							PeerConnectionWrapper *peerConnectionWrapper);
	virtual void SendOffer(webrtc::SessionDescriptionInterface* desc,
						   const std::string &token,
						   const std::string &id,
						   const std::string &conferenceId,
						   PeerConnectionWrapper *peerConnectionWrapper);
	virtual void SendOffer(const std::string &sdType,
						   const std::string &sdpString,
						   const std::string &token,
						   const std::string &id,
						   const std::string &conferenceId,
						   PeerConnectionWrapper *peerConnectionWrapper);
	
	virtual void SendCandidate(IceCandidateStringRepresentation* candidate,
							   const std::string &token,
							   const std::string &id,
							   PeerConnectionWrapper *peerConnectionWrapper);
	
	// At the moment can send only thru channeling server
	virtual void SendConferenceDocument(const std::set<std::string> &ids, const std::string &conferenceId);

	
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper);
	
	// Utilities. These methods are public for convenience
	// This method wraps given JSON msg into common format for API {To: "", From:"", etc.}. out_message is expected to be empty
	static void WrapJsonBeforeSending(const Json::Value &msg, const std::string &from, const std::string &to, const std::string &type, Json::Value &out_message);
	static void WrapJsonStringBeforeSendingToSignallingServer(const std::string &msg, const std::string &type, const std::string &from, const std::string &to, std::string *out);
	static void WrapP2PJson(const Json::Value &msg, const std::string &to, const std::string &from, Json::Value &out_message);
	static bool IsChannelingMessage(const Json::Value &msg);

private:
	SignallingHandler();
	
	ServerBasedMessageSenderInterface *serverSender_; // we do not own it
	PeerConnectionWrapperProviderInterface *wrapperProvider_; // we do not own it
	
	std::set<SignallingMessageReceiverInterface *> messageReceivers_;
	std::set<SignallingMessageReceiverInterface *> tokenMessageReceivers_;
	
	
	std::string selfId_;
};
	
} //namespace spreedme

#endif /* defined(__SpreedME__SignallingHandler__) */
