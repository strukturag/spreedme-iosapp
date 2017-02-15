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

#include "SignallingHandler.h"

#include <webrtc/base/json.h>

#include "PeerConnectionWrapper.h"


using namespace spreedme;

void SignallingHandler::SendMessage(const std::string &type, const std::string &msg)
{
	std::string wrappedMessage;
	SignallingHandler::WrapJsonStringBeforeSendingToSignallingServer(msg, type, std::string(), std::string(), &wrappedMessage);
	serverSender_->SendMessage(wrappedMessage);
}


void SignallingHandler::SendP2PMessage(const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper)
{
	if (peerConnectionWrapper && peerConnectionWrapper->HasOpenedDataChannel()) {
		rtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel = peerConnectionWrapper->DataChannelForName(kDefaultDataChannelLabel);
		if (dataChannel) {
			peerConnectionWrapper->SendData(msg);
		} else {
			// TODO: This should probably be removed as discussed with Simon. We want to send channeling messages only thru the default data channel.
			return;
			std::string openedDataChannelName = peerConnectionWrapper->FirstOpenedDataChannelName();
			if (!openedDataChannelName.empty()) {
				peerConnectionWrapper->SendData(msg, openedDataChannelName);
			}
		}
	}
}


void SignallingHandler::SendMessage(const std::string &type, const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper)
{
	if (peerConnectionWrapper && peerConnectionWrapper->HasOpenedDataChannel()) {
		this->SendP2PMessage(msg, peerConnectionWrapper);
	} else {
		this->SendMessage(type, msg);
	}
}


void SignallingHandler::SendMessage(const std::string &type, const std::string &msg, const std::string &userId)
{
	if (wrapperProvider_) {
		PeerConnectionWrapper *wrapper = wrapperProvider_->GetP2PWrapperForUserId(userId);
		if (wrapper) {
			this->SendP2PMessage(msg, wrapper);
			return;
		}
	}
	
	this->SendMessage(type, msg);
}


void SignallingHandler::SendMessage(const std::string &type, const std::string &msg, const std::string &userId, const std::string &wrapperId)
{
	if (wrapperProvider_) {
		PeerConnectionWrapper *wrapper = wrapperProvider_->GetP2PWrapperForWrapperId(wrapperId);
		if (wrapper && wrapper->userId() == userId) {
			this->SendP2PMessage(msg, wrapper);
			return;
		}
	}
	
	this->SendMessage(type, msg);
}


void SignallingHandler::ReceiveMessage(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId)
{
	Json::Reader reader;
	Json::Value root;
	
	bool isJsonValid = reader.parse(msg, root);
	if (isJsonValid) {
		
		Json::Value innerJson = root[kDataKey];
		if (!innerJson.isNull()) {
			std::string messageType = innerJson.get(kTypeKey, Json::Value()).asString();
			if (!messageType.empty()) {
				if (messageType == kOfferKey || messageType == kAnswerKey || messageType == kCandidateKey) {
					Json::Value offerAnswerCand = innerJson[messageType];
					std::string token = offerAnswerCand.get(kDataChannelTokenKey, Json::Value()).asString();
					if (!token.empty()) {
						for (std::set<SignallingMessageReceiverInterface *>::iterator it = tokenMessageReceivers_.begin(); it != tokenMessageReceivers_.end(); ++it) {
							(*it)->MessageReceived(msg, transportType, wrapperId, token);
						}
						return;
                    }
				}
			}
		}
	
		for (std::set<SignallingMessageReceiverInterface *>::iterator it = messageReceivers_.begin(); it != messageReceivers_.end(); ++it) {
			(*it)->MessageReceived(msg, transportType, wrapperId);
		}
	}
}


void SignallingHandler::RegisterMessageReceiver(SignallingMessageReceiverInterface *receiver)
{
	if (receiver) {
		messageReceivers_.insert(receiver);
	}
}


void SignallingHandler::UnRegisterMessageReceiver(SignallingMessageReceiverInterface *receiver)
{
	if (receiver) {
		messageReceivers_.erase(receiver);
	}
}


void SignallingHandler::RegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver)
{
	if (receiver) {
		tokenMessageReceivers_.insert(receiver);
	}
}


void SignallingHandler::UnRegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver)
{
	if (receiver) {
		tokenMessageReceivers_.erase(receiver);
	}
}



void SignallingHandler::SendBye(const std::string &userId, ByeReason reason, PeerConnectionWrapper *peerConnectionWrapper)
{
	Json::Value jmessage;
	jmessage[kTypeKey] = kByeKey;
	jmessage[kToKey] = userId;
	
	
	std::string reasonStr;
	switch (reason) {
		case kByeReasonBusy:
			reasonStr = std::string(kByeReasonBusyString);
			break;
			
		case kByeReasonNoAnswer:
			reasonStr = std::string(kByeReasonNoAnswerString);
			break;
			
		case kByeReasonAbort:
			reasonStr = std::string(kByeReasonAbortString);
			break;
			
		case kByeReasonReject:
			reasonStr = std::string(kByeReasonRejectString);
			break;
			
		case kByeReasonNotSpecified:
		default:
			break;
	}
	
	if (!reasonStr.empty()) {
		Json::Value reasonJson;
		reasonJson[kByeReasonKey] = reasonStr;
		jmessage[kByeKey] = reasonJson;
	}
	
	Json::Value wrappedMessage;
	SignallingHandler::WrapJsonBeforeSending(jmessage, selfId_, userId, std::string(kByeKey), wrappedMessage);
	
	Json::StyledWriter writer;
	this->SendMessage(std::string(kByeKey), writer.write(wrappedMessage));
}


void SignallingHandler::SendAnswer(webrtc::SessionDescriptionInterface* desc, const std::string &token, const std::string &id, PeerConnectionWrapper *peerConnectionWrapper)
{
	std::string sdType = desc->type();
	std::string sdp;
	desc->ToString(&sdp);
	
	this->SendAnswer(sdType, sdp, token, id, peerConnectionWrapper);
}


void SignallingHandler::SendAnswer(const std::string &sdType,
								   const std::string &sdpString,
								   const std::string &token,
								   const std::string &id,
								   PeerConnectionWrapper *peerConnectionWrapper)
{
	Json::Value jmessage;
	jmessage[kLCTypeKey] = sdType;
	jmessage[kSessionDescriptionSdpKey] = sdpString;
	
	if (!token.empty()) {
		jmessage[kDataChannelTokenKey] = token;
	}
	if (!id.empty()) {
		jmessage[kDataChannelIdKey] = id;
	}
	
	Json::Value wrappedMessage;
	SignallingHandler::WrapJsonBeforeSending(jmessage, selfId_, peerConnectionWrapper->userId(), std::string(kAnswerKey), wrappedMessage);
	
	Json::StyledWriter writer;
	this->SendMessage(std::string(kAnswerKey), writer.write(wrappedMessage));
}


void SignallingHandler::SendOffer(webrtc::SessionDescriptionInterface* desc, const std::string &token, const std::string &id, const std::string &conferenceId, PeerConnectionWrapper *peerConnectionWrapper)
{
	std::string sdType = desc->type();
	std::string sdp;
	desc->ToString(&sdp);
	
	this->SendOffer(sdType, sdp, token, id, conferenceId, peerConnectionWrapper);
}


void SignallingHandler::SendOffer(const std::string &sdType,
								  const std::string &sdpString,
								  const std::string &token,
								  const std::string &id,
								  const std::string &conferenceId,
								  PeerConnectionWrapper *peerConnectionWrapper)
{
	Json::Value jmessage;
	jmessage[kLCTypeKey] = sdType;
	jmessage[kSessionDescriptionSdpKey] = sdpString;
	
	if (!token.empty()) {
		jmessage[kDataChannelTokenKey] = token;
	}
	if (!id.empty()) {
		jmessage[kDataChannelIdKey] = id;
	}
	if (!conferenceId.empty()) {
		jmessage[kOfferConferenceKey] = conferenceId;
	}
	
	Json::Value wrappedMessage;
	SignallingHandler::WrapJsonBeforeSending(jmessage, selfId_, peerConnectionWrapper->userId(), std::string(kOfferKey), wrappedMessage);
	
	Json::StyledWriter writer;
	std::string msg = writer.write(wrappedMessage);
	
	this->SendMessage(std::string(kOfferKey), msg);
}


void SignallingHandler::SendCandidate(IceCandidateStringRepresentation* candidate, const std::string &token, const std::string &id, PeerConnectionWrapper *peerConnectionWrapper)
{
	Json::Value jmessage;
	
    jmessage[kLCTypeKey] = kCandidateSdpKey;
    jmessage[kCandidateSdpMidKey] = candidate->sdp_mid;
    jmessage[kCandidateSdpMlineIndexKey] = candidate->sdp_mline_index;
    jmessage[kCandidateSdpKey] = candidate->string_rep;
	
	if (!token.empty()) {
		jmessage[kDataChannelTokenKey] = token;
	}
	if (!id.empty()) {
		jmessage[kDataChannelIdKey] = id;
	}
	
	delete candidate;
	
//	spreed_me_log("sending candidate:===> %s", jmessage.toStyledString().c_str());
	
	Json::Value wrappedCandidateMessage;
	SignallingHandler::WrapJsonBeforeSending(jmessage, selfId_, peerConnectionWrapper->userId(), std::string(kCandidateKey), wrappedCandidateMessage);
	
	Json::StyledWriter writer;
	this->SendMessage(std::string(kCandidateKey), writer.write(wrappedCandidateMessage));
}


void SignallingHandler::SendConferenceDocument(const std::set<std::string> &ids, const std::string &conferenceId)
{
	Json::Value jmessage;
	Json::Value idsArray;
	
	int i = 0;
	for (std::set<std::string>::iterator it = ids.begin(); it != ids.end(); it++) {
		idsArray[i] = *it;
		++i;
	}
	
    jmessage[kConferenceKey] = idsArray;
	jmessage[kIdKey] = conferenceId;
	jmessage[kTypeKey] = kConferenceKey;
	
	Json::StyledWriter writer;
	std::string msg = writer.write(jmessage);
	this->SendMessage(std::string(kConferenceKey), msg);
}


void SignallingHandler::ReceivedDataChannelData(webrtc::DataBuffer *buffer,
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
			if (SignallingHandler::IsChannelingMessage(message)) {
				
				std::string from = wrapper->userId();
				std::string to = selfId_;
				
				SignallingHandler::WrapP2PJson(message, to, from, root);
				
				std::string msg = root.toStyledString();
				
				this->ReceiveMessage(msg, kPeerToPeer, wrapper->factoryId());
			} else {
				spreed_me_log("JSON message is not recognized! %s", strMsg.c_str());
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


/*----------------------Utilities-------------------*/

bool SignallingHandler::IsChannelingMessage(const Json::Value &msg)
{
	std::string messageType = msg.get(kTypeKey, Json::Value()).asString();
	if (!messageType.empty()) {
		if (
			messageType == kAnswerKey ||
			messageType == kOfferKey ||
			messageType == kCandidateKey ||
			messageType == kConferenceKey ||
			messageType == kByeKey ||
			messageType == kLeftKey ||
			messageType == kJoinedKey ||
			messageType == kStatusKey ||
			messageType == kUsersKey ||
			messageType == kChatKey ||
			messageType == kTalkingKey ||
			messageType == kScreenShareKey ||
			messageType == kHelloKey ||
			messageType == kSelfKey
			) {
			
			return true;
		}
	}
	
	return false;
}


void SignallingHandler::WrapJsonStringBeforeSendingToSignallingServer(const std::string &msg, const std::string &type, const std::string &from, const std::string &to, std::string *out)
{
	std::ostringstream stringStream;
	stringStream << "{\"" << kTypeKey << "\" : \"" << type << "\",\n\"" << type <<  "\" : " << msg << "}";
	std::string out_message = stringStream.str();
	out->clear();
	out->insert(0, out_message);
}


void SignallingHandler::WrapJsonBeforeSending(const Json::Value &msg, const std::string &from, const std::string &to, const std::string &type, Json::Value &out_message)
{
    out_message["Type"] = type;
    out_message["To"] = to;// (Json::Value::Int64) atol(_other.c_str());
    out_message["From"] = from;
	
	out_message[type] = msg;
}


void SignallingHandler::WrapP2PJson(const Json::Value &msg, const std::string &to, const std::string &from, Json::Value &out_message)
{
	out_message[kDataKey] = msg;
	out_message[kToKey] = to;
	out_message[kFromKey] = from;
}
/*----------------------End Utilities-------------------*/
