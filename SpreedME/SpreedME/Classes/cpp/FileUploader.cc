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

#include "FileUploader.h"

#include <webrtc/base/helpers.h>

#include "crc32.h"

using namespace spreedme;


namespace spreedme {
				

struct FileSharingMessageData : public rtc::MessageData {
	explicit FileSharingMessageData(std::string filePath, std::string fileType, std::string fileName, std::string token, bool shouldDeleteOnFinish) :
	filePath(filePath), fileType(fileType), fileName(fileName), token(token), shouldDeleteOnFinish(shouldDeleteOnFinish) {};
	
	std::string filePath;
	std::string fileType;
	std::string fileName;
	std::string token;
	bool shouldDeleteOnFinish;
};
	
	
struct UserIdWrapperIdMessageData : public rtc::MessageData {
	explicit UserIdWrapperIdMessageData(const std::string &userId, const std::string &wrapperId) : userId(userId), wrapperId(wrapperId) {};
	
	std::string userId;
	std::string wrapperId;
};

}


// '_c' - callbacks; '_s' - signallingThread; '_w' - workerThread
enum {
	MSG_FU_START_FILE_SHARING_s = 0,
	MSG_FU_RECEIVED_MESSAGE_s,
	MSG_FU_STOP_SHARING_s,
	MSG_FU_DELETE_CLOSED_WRAPPER_s,
	MSG_FU_FILESHARING_HAS_STARTED_c,
	MSG_FU_CLEANED_UP_c
};


FileUploader::FileUploader(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
						   SignallingHandler *signallingHandler,
						   MessageQueueInterface *workerQueue,
						   MessageQueueInterface *callbacksMessageQueue) :
	FileTransfererBase(peerConnectionWrapperFactory,
					   signallingHandler,
					   workerQueue,
					   callbacksMessageQueue),
	shouldDeleteFileOnFinish_(true)
{
	
}


FileUploader::~FileUploader()
{
	if (shouldDeleteFileOnFinish_) {
		remove(filePath_.c_str());
	}
}


std::string FileUploader::CreateFileUploadTokenForFileName(const std::string &fileName)
{
	std::string randomString;
	int idLength = 40;
	bool succes = rtc::CreateRandomString(idLength, &randomString);
	if (!succes) {
		spreed_me_log("Couldn't generate random string to create token peer connection id!\n");
		assert(false);
	}
	
	randomString = fileName + "_" + randomString;
		
	return randomString;
}


void FileUploader::StartSharingFile(const std::string &filePath, const std::string &fileType, const std::string &fileName, const std::string &token, bool shouldDeleteOnFinish)
{
	FileSharingMessageData *msgData = new FileSharingMessageData(filePath, fileType, fileName, token, shouldDeleteOnFinish);
	workerQueue_->Post(this, MSG_FU_START_FILE_SHARING_s, msgData);
}


void FileUploader::StartSharingFile_s(const std::string &filePath, const std::string &fileType, const std::string &fileName, const std::string &token, bool shouldDeleteOnFinish)
{
	token_ = token;
	
	shouldDeleteFileOnFinish_ = shouldDeleteOnFinish;
	
	filePath_ = filePath;
	
	fileHandle_.open(filePath_.c_str(), std::ios::in | std::ios::binary);
	
	if (fileHandle_.is_open()) {
		fileHandle_.seekg(0, std::ios::end);
		fileInfo_.fileSize = fileHandle_.tellg();
		fileHandle_.seekg(0);
		spreed_me_log("Opened file handle to filePath %s", filePath.c_str());
	} else {
		spreed_me_log("Couldn't open file handle to filePath %s", filePath.c_str());
		assert(false);
	}
	
	fileInfo_.token = token;
	fileInfo_.fileName = fileName;
	fileInfo_.fileType = fileType;

	this->DecideOnFileChunksForFileSize();

	
	spreed_me_log("Starting file share with parameters: \n name: %s \n type: %s \n size: %llu \n chunks: %u",
				  fileInfo_.fileName.c_str(), fileInfo_.fileType.c_str(), fileInfo_.fileSize, fileInfo_.chunks);
	
	callbacksMessageQueue_->Post(this, MSG_FU_FILESHARING_HAS_STARTED_c);
}


void FileUploader::StopFileTransfer()
{
	workerQueue_->Post(this, MSG_FU_STOP_SHARING_s, NULL);
}


void FileUploader::StopSharingFile_s()
{
//	this->EraseAllWrappers(); // this also sends 'download file bye' requests via data channels, so it is might not be appropriate in FileUploader
	signallingHandler_->UnRegisterTokenMessageReceiver(this);
	
	for (WrapperIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
		wrapper->Shutdown();
	}
	
	activeConnections_.clear();
	
	if (shouldDeleteFileOnFinish_) {
		remove(filePath_.c_str());
		shouldDeleteFileOnFinish_ = false; // to prevent 'remove()' call in destructor
	}
	
	workerQueue_->Clear(this);
	
	//Later maybe send some byes here.
	
	callbacksMessageQueue_->Post(this, MSG_FU_CLEANED_UP_c, NULL);
}


void FileUploader::AsyncDeleteWrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId)
{
	UserIdWrapperIdMessageData *msgData = new UserIdWrapperIdMessageData(userId, wrapperId);
	workerQueue_->Post(this, MSG_FU_DELETE_CLOSED_WRAPPER_s, msgData);
}


void FileUploader::DecideOnFileChunksForFileSize()
{
	fileInfo_.chunkSize = 60000; // SCTP data packet max size is 64k
	uint64 reminder = fileInfo_.fileSize % fileInfo_.chunkSize;
	uint64 chunks = fileInfo_.fileSize / fileInfo_.chunkSize;
	fileInfo_.chunks = (uint32)chunks + (reminder > 0 ? 1 : 0);
}


void FileUploader::OnMessage(rtc::Message* msg)
{
	switch (msg->message_id) {
		case MSG_FU_RECEIVED_MESSAGE_s: {
			SignallingMessageData *param = static_cast<SignallingMessageData*>(msg->pdata);
			this->MessageReceived_s(param->msg, param->transportType, param->wrapperId, param->token);
			delete param;
			break;
		}
			
		case MSG_FU_START_FILE_SHARING_s: {
			FileSharingMessageData *param = static_cast<FileSharingMessageData*>(msg->pdata);
			this->StartSharingFile_s(param->filePath, param->fileType, param->fileName, param->token, param->shouldDeleteOnFinish);
			delete param;
			break;
		}
		
		case MSG_FU_STOP_SHARING_s: {
			this->StopSharingFile_s();
			break;
		}
			
		case MSG_FU_DELETE_CLOSED_WRAPPER_s: {
			
			UserIdWrapperIdMessageData *param = static_cast<UserIdWrapperIdMessageData*>(msg->pdata);
			this->DeleteWrapperForUserIdWrapperId(param->userId, param->wrapperId);
			delete param;
			break;
		}
		
		case MSG_FU_FILESHARING_HAS_STARTED_c: {
			if (delegate_) {
				delegate_->FileSharingHasStarted(fileInfo_, this);
			}
			break;
		}
		
		case MSG_FU_CLEANED_UP_c: {
			if (delegate_) {
				delegate_->FileUploaderHasStoppedAndCleanedUp(this);
			}
		}
			
		default:
			break;
	}
}


void FileUploader::MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
{
	SignallingMessageData *msgData = new SignallingMessageData(msg, transportType, wrapperId, token);
	workerQueue_->Post(this, MSG_FU_RECEIVED_MESSAGE_s, msgData);
}


void FileUploader::ReceivedOffer_s(const Json::Value &offerJson, const std::string &from)
{
	Json::Value wrappedOffer = offerJson.get(kOfferKey, Json::Value());
	if (!wrappedOffer.isNull()) {
		
		std::string sdp = wrappedOffer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
		std::string id = wrappedOffer.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = wrappedOffer.get(kDataChannelTokenKey, Json::Value()).asString();
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserIdTokenId(from, id);
		
		if (wrapper) {
			spreed_me_log("This is strange. Received offer for exisitng wrapper. This could be renegotiation.");
		} else {
			std::string wrapperId = this->WrapperIdForIdTokenUserId(id, token, from);
			assert(!wrapperId.empty());
			wrapper = this->CreatePeerConnectionWrapper(from, wrapperId);
			this->InsertWrapperForUserIdAndWrapperId(wrapper->userId(), wrapper->customIdentifier(), wrapper);
			if (wrapper) {
				spreed_me_log("Accepting offer from %s", from.c_str());
				if (!sdp.empty()) {
					// this means sdp was given to us
					wrapper->SetupRemoteOffer(sdp);
				}
			} else {
				spreed_me_log("Error! No wrapper for incoming call acception.\n");
			}
		}
	}
}


void FileUploader::ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from)
{
	spreed_me_log("We don't really expect to receive answer in FileUploader since we don't send offers");
}


void FileUploader::AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendAnswer(sdType, sdp, fileInfo_.token, this->IdForWrapperId(peerConnectionWrapper->customIdentifier()), peerConnectionWrapper);
}


void FileUploader::OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	spreed_me_log("This is not correct. File uploader can only receive offers but not send. We haven't implemented renegotiation yet so this is incorrect.");
	return;
}


void FileUploader::CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper)
{
	if (candidate->sdp_mid == "video" || candidate->sdp_mid == "audio") {
        spreed_me_log("Not sending video and audio ice candidate while from token based peer connection.\n");
        return;
    }
	
	signallingHandler_->SendCandidate(candidate, fileInfo_.token, this->IdForWrapperId(peerConnectionWrapper->customIdentifier()), peerConnectionWrapper);
}


void FileUploader::DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper)
{
	spreed_me_log("DataChannelStateChanged in FileUploader state %d; wrapperUserID %s!", state, wrapper->userId().c_str());
	switch (data_channel->state()) {
		case webrtc::DataChannelInterface::kConnecting:
			break;
		case webrtc::DataChannelInterface::kOpen:
			break;
		case webrtc::DataChannelInterface::kClosing:
			break;
		case webrtc::DataChannelInterface::kClosed:
			// Delete wrapper since it has closed datachannel
			this->DeleteWrapperForUserIdWrapperId(wrapper->userId(), wrapper->customIdentifier());
			
			break;
		default:
			break;
	}
}


void FileUploader::ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										   webrtc::DataChannelInterface *data_channel,
										   PeerConnectionWrapper *wrapper)
{
	if (buffer->binary) {
		spreed_me_log("This is strange. We shouldn't receive binary buffers in FileUploader");
		delete buffer;
	} else {
		
		std::string message = std::string(buffer->data.data(), buffer->data.length());
		
		Json::Reader reader;
		Json::Value jsonMsg;
		bool success = reader.parse(message, jsonMsg);
		if (success) {
			std::string requestMode = jsonMsg.get(kDataChannelChunkRequestModeKey, Json::Value()).asString();
			uint32 chunkNum = jsonMsg.get(kDataChannelChunkSequenceNumberKey, Json::Value()).asUInt();
			if (requestMode == kDataChannelChunkRequestModeRequestKey && chunkNum < fileInfo_.chunks) {
				fileHandle_.seekg(chunkNum * fileInfo_.chunkSize);
				uint32 size = fileInfo_.fileSize - chunkNum * fileInfo_.chunkSize > fileInfo_.chunkSize ? fileInfo_.chunkSize : fileInfo_.fileSize - chunkNum * fileInfo_.chunkSize;
				
				char *buff = (char *)malloc(size + 12);
				fileHandle_.read(buff+12, size);
				
				buff[0] = 0; //This is version;
				
				uint32 calcCrc32 = crc32buf(buff+12, size);
				memcpy(&buff[8], &calcCrc32, 4); // this is checksum
				memcpy(&buff[4], &chunkNum, 4); // this is chunk num
				
				// wrapper doesn't take ownership of data buffer we provide to it
				wrapper->SendData(buff, size + 12);
				free(buff);
				
				delete buffer;
				
			} else if (requestMode == kDataChannelChunkRequestModeByeKey) {
				
				// This has to be async, otherwise we delete datachannel inside the data callback block which leads to crash.
				this->AsyncDeleteWrapperForUserIdWrapperId(wrapper->userId(), wrapper->customIdentifier());
				spreed_me_log("Deleting wrapper");
				delete buffer;
				
			} else {
				spreed_me_log("Request mode or chunk number is wrong! This might be not the chunk request json. Pass it to signalling handler");
				signallingHandler_->ReceivedDataChannelData(buffer, data_channel, wrapper);
			}
		} else {
			spreed_me_log("Couldn't parse chunk request Json!");
			delete buffer;
		}
	}
	
	
}

