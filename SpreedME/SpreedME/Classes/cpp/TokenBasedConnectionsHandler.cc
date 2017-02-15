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

#include "TokenBasedConnectionsHandler.h"

#include <stdexcept>

#include <webrtc/base/helpers.h>

using namespace spreedme;

TokenBasedConnectionsHandler::
TokenBasedConnectionsHandler(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
							 SignallingHandler *signallingHandler,
							 MessageQueueInterface *workerQueue,
							 MessageQueueInterface *callbacksMessageQueue) :

		critSect_(webrtc::CriticalSectionWrapper::CreateCriticalSection()),
		peerConnectionWrapperFactory_(peerConnectionWrapperFactory),
		signallingHandler_(signallingHandler),
		workerQueue_(workerQueue),
		callbacksMessageQueue_(callbacksMessageQueue),
		token_(std::string())
{
	assert(peerConnectionWrapperFactory);
	assert(callbacksMessageQueue);
	signallingHandler_->RegisterTokenMessageReceiver(this);
}


TokenBasedConnectionsHandler::~TokenBasedConnectionsHandler()
{
	signallingHandler_->UnRegisterTokenMessageReceiver(this);
	delete critSect_;
}


std::string TokenBasedConnectionsHandler::CreateWrapperIdForOutgoingOffer(const std::string &token, const std::string &to)
{
	std::string randomString;
	int idLength = 15;
	bool succes = rtc::CreateRandomString(idLength, &randomString);
	if (!succes) {
		spreed_me_log("Couldn't generate random string to create token peer connection id!\n");
		assert(false);
	}
	
	//	std::set<std::string>::iterator it = tokenPeerConnectionWrapperIds_.find(randomString);
	//	if (it != tokenPeerConnectionWrapperIds_.end()) {
	//		tokenPeerConnectionWrapperIds_.insert(randomString);
	//	} else {
	//		randomString = std::string();
	//	}
	
	return randomString;
}


std::string TokenBasedConnectionsHandler::WrapperIdForIdTokenUserId(const std::string &id, const std::string &token, const std::string &userId)
{
	std::string retId;
	if (!id.empty() && !token.empty() && !userId.empty()) {
		retId = id + "_" + token + "_" + userId;
	}
	return retId;
}


std::string TokenBasedConnectionsHandler::IdForWrapperId(const std::string &wrapperId)
{
	std::string retId;
	if (!wrapperId.empty()) {
		size_t pos = wrapperId.find(std::string("_"));
		if (pos != std::string::npos)
		{
			retId = wrapperId.substr(0, pos);
		}
	}
	
	return retId;
}


rtc::scoped_refptr<PeerConnectionWrapper> TokenBasedConnectionsHandler::CreatePeerConnectionWrapper(const std::string &userId)
{
	return this->CreatePeerConnectionWrapper(userId, "");
}


rtc::scoped_refptr<PeerConnectionWrapper> TokenBasedConnectionsHandler::CreatePeerConnectionWrapper(const std::string &userId, const std::string &wrapperId)
{
	rtc::scoped_refptr<PeerConnectionWrapper> wrapper = peerConnectionWrapperFactory_->CreateSpreedPeerConnection(userId, this);
	if (wrapper) {
        rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peerConnectionWrapperFactory_->CreateLocalStream(false, false);
		wrapper->AddLocalStream(stream, NULL);
		if (!wrapperId.empty()) {
			wrapper->SetCustomIdentifier(wrapperId);
		}
	}
	return wrapper;
}


void TokenBasedConnectionsHandler::MessageReceived_s(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
{
	if (token != token_) {
		spreed_me_log("Received alien token message. Ignore it. Our token %s token received %s", token_.c_str(), token.c_str());
		return;
	}
	
	Json::Reader jsonReader;
	Json::Value root;
	
	bool success = jsonReader.parse(msg, root);
	if (success) {
		Json::Value innerJson = root[kDataKey];
		if (!innerJson.isNull()) {
			std::string messageType = innerJson.get(kTypeKey, Json::Value()).asString();
			std::string from = root.get(kFromKey, Json::Value()).asString();
			if (!messageType.empty()) {
				if (messageType == kOfferKey) {
					this->ReceivedOffer_s(innerJson, from);
				} else if (messageType == kAnswerKey) {
					this->ReceivedAnswer_s(innerJson, from);
				} else if (messageType == kCandidateKey) {
					this->ReceivedCandidate_s(innerJson, from);
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

