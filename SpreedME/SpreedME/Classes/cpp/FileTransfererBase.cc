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

#include "FileTransfererBase.h"

#include <stdexcept>

#include <webrtc/base/helpers.h>

using namespace spreedme;


FileTransfererBase::FileTransfererBase(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
									   SignallingHandler *signallingHandler,
									   MessageQueueInterface *workerQueue,
									   MessageQueueInterface *callbacksMessageQueue) :
	TokenBasedConnectionsHandler(peerConnectionWrapperFactory,
								 signallingHandler,
								 workerQueue,
								 callbacksMessageQueue)
{
	
}


FileTransfererBase::~FileTransfererBase()
{
	
}


bool FileTransfererBase::InsertWrapperForUserIdAndWrapperId(const std::string &userId, const std::string &wrapperId, rtc::scoped_refptr<PeerConnectionWrapper> wrapper)
{
	std::pair<WrapperIdToWrapperMap::iterator , bool> ret = activeConnections_.insert(std::pair< std::string, rtc::scoped_refptr<PeerConnectionWrapper> >(wrapperId, wrapper));
	return ret.second;
}


rtc::scoped_refptr<PeerConnectionWrapper> FileTransfererBase::WrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId)
{
	WrapperIdToWrapperMap::iterator it = activeConnections_.find(wrapperId);
	
	if (it != activeConnections_.end()) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
		return wrapper;
	}
	
	return NULL;
}


rtc::scoped_refptr<PeerConnectionWrapper> FileTransfererBase::WrapperForUserIdTokenId(const std::string &userId, const std::string &id)
{
	return this->WrapperForUserIdWrapperId(userId, this->WrapperIdForIdTokenUserId(id, token_, userId));
}


void FileTransfererBase::DeleteWrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId)
{
	
	WrapperIdToWrapperMap::iterator it = activeConnections_.find(wrapperId);
	
	if (it != activeConnections_.end()) {
		if (it->second->userId() == userId) {
			it->second->Close();
			activeConnections_.erase(it);
		} else {
			spreed_me_log("FileTransfererBase: On deleting wrapper: wrapper user_id doesn't match to userId!");
		}
	}
}


void FileTransfererBase::EraseAllWrappers()
{
	for (WrapperIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
		Json::Value chunkRequestJson;
		chunkRequestJson[kDataChannelChunkRequestModeKey] = kDataChannelChunkRequestModeByeKey;
		
		std::string msg = chunkRequestJson.toStyledString();
		spreed_me_log("Sending bye on data channel %s", msg.c_str());
		it->second->SendData(msg, kDefaultDataChannelLabel);
	}
	
	activeConnections_.clear();
}


void FileTransfererBase::ReceivedCandidate_s(const Json::Value &candidateJson, const std::string &from)
{
	Json::Value unwrappedCandidate = candidateJson.get(kCandidateKey, Json::Value());
	if (!unwrappedCandidate.isNull()) {
		
		std::string id = unwrappedCandidate.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = unwrappedCandidate.get(kDataChannelTokenKey, Json::Value()).asString();
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserIdTokenId(from, id);
		if (wrapper) {
			
			std::string sdpMid = unwrappedCandidate.get(kCandidateSdpMidKey, Json::Value()).asString();
			
			int sdpMLineIndex = -1;
			Json::Value sdpMLineIndexValue = unwrappedCandidate.get(kCandidateSdpMlineIndexKey, Json::Value());
			if (!sdpMLineIndexValue.isNull()) {
				sdpMLineIndex = sdpMLineIndexValue.asInt();
			}
			
			std::string candidateString = unwrappedCandidate.get(kCandidateSdpKey, Json::Value()).asString();
			
			if (sdpMLineIndex > -1) {
				if (sdpMid != "video" && sdpMid != "audio") {
					wrapper->SetupRemoteCandidate(sdpMid, sdpMLineIndex, candidateString);
				} else {
					spreed_me_log("Discarding video and audio ice candidate while from token based peer connection.");
				}
			} else {
				throw std::runtime_error("Candidate inline index is not correct!!!");
			}
		}
	} else {
		spreed_me_log("Problem with parsing candidate! \n");
	}
}
