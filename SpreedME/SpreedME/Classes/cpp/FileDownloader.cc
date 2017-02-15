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

#include "FileDownloader.h"

#include <stdexcept>

#include "crc32.h"

using namespace spreedme;

// '_c' - callbacks; '_s' - signallingThread; '_w' - workerThread
enum {
	MSG_FD_START_FILE_DOWNLOAD_s = 0,
	MSG_FD_RECEIVE_DATA_BUFFER,
	MSG_FD_REQUEST_NEXT_CHUNK_s,
	MSG_FD_UPDATE_DOWNLOAD_PROGRESS_c,
	MSG_FD_RECEIVED_MESSAGE_s,
	MSG_FD_STOP_DOWNLOADING_FILE_s,
	MSG_FD_PAUSE_DOWNLOADING_FILE_s,
	MSG_FD_RESUME_DOWNLOADING_FILE_s,
	MSG_FD_DOWNLOAD_FINISHED_c,
	MSG_FD_DOWNLOAD_CANCELED_c,
	MSG_FD_CLEANED_UP_c
};




FileDownloader::FileDownloader(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
							   SignallingHandler *signallingHandler,
							   MessageQueueInterface *workerQueue,
							   MessageQueueInterface *callbacksMessageQueue) :
	FileTransfererBase(peerConnectionWrapperFactory, signallingHandler, workerQueue, callbacksMessageQueue),
	delegate_(NULL),
	downloadFileInfo_(NULL),
	isDownloadStarted_(false),
	firstChunkDownloaded_(false),
	downloadingFirstChunk_(false)
{
}


FileDownloader::~FileDownloader()
{	
	if (downloadFileInfo_) {
		delete downloadFileInfo_;
	}
	
	this->EraseAllWrappers();
	
	if (tmpFilePath_ != filePath_) {
		remove(tmpFilePath_.c_str());
	}
}


void FileDownloader::DownloadFileForToken(const FileInfo &fileInfo, const std::string &fileLocation, const std::set<std::string> &userIds, const std::string &tempFilePath)
{
	critSect_->Enter();
	
	userIds_ = userIds;
		
	token_ = fileInfo.token;
	
	fileInfo_ = fileInfo;
	filePath_ = std::string(fileLocation + fileInfo_.fileName);
	
	if (tempFilePath.length() > 0) {
		tmpFilePath_ = tempFilePath;
	} else {
		tmpFilePath_ = filePath_;
	}
	
	/* 
	 All chunks are the same size (except the last one, which can be smaller)
	 so we will setup chunk size as the size of first received packet. 
	 TODO: Check so that we don't ask for the last chunk as our first chunk.
	 */
	fileInfo_.chunkSize = 0;
	
	critSect_->Leave();
	
	this->StartFileDownload();
}


void FileDownloader::UpdateUserIds(std::set<std::string> userIds)
{
	critSect_->Enter();
	for (std::set<std::string>::iterator it = userIds.begin(); it != userIds.end(); ++it) {
		userIds_.insert(*it);
	}
	critSect_->Leave();
}


void FileDownloader::StartFileDownload()
{
	workerQueue_->Post(this, MSG_FD_START_FILE_DOWNLOAD_s);
}


void FileDownloader::StopFileTransfer()
{
	workerQueue_->Post(this, MSG_FD_STOP_DOWNLOADING_FILE_s);
}


void FileDownloader::PauseFileTransfer()
{
	workerQueue_->Post(this, MSG_FD_PAUSE_DOWNLOADING_FILE_s);
}


void FileDownloader::ResumeFileTransfer()
{
	workerQueue_->Post(this, MSG_FD_RESUME_DOWNLOADING_FILE_s);
}


void FileDownloader::StartFileDownload_s(int maxSimultaneousPeers, int maxSimultaneousConnectionsPerPeer)
{
	fileHandle_.open(tmpFilePath_.c_str(), std::ios::out | std::ios::binary);
	
	critSect_->Enter();
	
	downloadFileInfo_ = new DownloadFileInfo(fileInfo_);
	
	critSect_->Leave();
	
	spreed_me_log("Starting file download with parameters: \n name: %s \n type: %s \n size: %llu \n chunks: %u",
				  fileInfo_.fileName.c_str(), fileInfo_.fileType.c_str(), fileInfo_.fileSize, fileInfo_.chunks);
	
	maxSimultaneousPeers_ = 1;
	maxSimultaneousConnectionsPerPeer_ = 5;
	
	if (fileInfo_.chunks < 10) {
		maxSimultaneousConnectionsPerPeer_ = 1;
	} else if (fileInfo_.chunks > 10 && fileInfo_.chunks <= 30) {
		maxSimultaneousConnectionsPerPeer_ = 2;
	} else if (fileInfo_.chunks > 30 && fileInfo_.chunks <= 60) {
		maxSimultaneousConnectionsPerPeer_ = 3;
	} else if (fileInfo_.chunks > 60 && fileInfo_.chunks <= 90) {
		maxSimultaneousConnectionsPerPeer_ = 4;
	} else {
		maxSimultaneousConnectionsPerPeer_ = 5;
	}
	
	int i = 0;
	for (std::set<std::string>::iterator it = userIds_.begin(); it != userIds_.end() && i < maxSimultaneousPeers_; ++it) {
		++i;
		std::string userId = *it;
		
		for (int j = 0; j < maxSimultaneousConnectionsPerPeer_; j++) {
			rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->CreatePeerConnectionWrapper(userId);
			if (wrapper) {
				wrapper->SetCustomIdentifier(this->WrapperIdForIdTokenUserId(wrapper->factoryId(), fileInfo_.token, userId));
				this->InsertWrapperForUserIdAndWrapperId(userId, wrapper->customIdentifier(), wrapper);
				
				downloadFileInfo_->freeDownloaders_.insert(std::pair<UniqueDownloadDataChannelId, DownloadStatusPair>
														   (UniqueDownloadDataChannelId(wrapper->factoryId(),kDefaultDataChannelLabel),
															DownloadStatusPair()));
				
				wrapper->CreateOffer(userId);
			}
		}
	}
}


void FileDownloader::StopFileTransfer_s()
{
	signallingHandler_->UnRegisterMessageReceiver(this);
	
	for (WrapperIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
		wrapper->Close();
	}
	
	activeConnections_.clear();
	
	workerQueue_->Clear(this);
	
	callbacksMessageQueue_->Post(this, MSG_FD_DOWNLOAD_CANCELED_c);
	callbacksMessageQueue_->Post(this, MSG_FD_CLEANED_UP_c);
}


void FileDownloader::PauseFileTransfer_s()
{
	
}


void FileDownloader::ResumeFileTransfer_s()
{
	
}


void FileDownloader::OnMessage(rtc::Message* msg)
{
	switch (msg->message_id) {
		case MSG_FD_START_FILE_DOWNLOAD_s:
			this->StartFileDownload_s(1, 1);
		break;
			
		case MSG_FD_REQUEST_NEXT_CHUNK_s:
			this->RequestNextChunk_s();
		break;
		
		case MSG_FD_UPDATE_DOWNLOAD_PROGRESS_c: {
			if (delegate_) {
				critSect_->Enter();
#warning CHECK if here type conversion happens correctly
				FileInfo tempInfo = this->fileInfo();
				bool lastChunkDownloaded = downloadFileInfo_->ChunkStatus(tempInfo.chunks - 1) == kChunkDownloaded;
				uint64 downloadProgress = 0;
				if (lastChunkDownloaded) {
					uint32 lastChunkSize = tempInfo.fileSize % tempInfo.chunks;
					if (lastChunkSize == 0) {
						lastChunkSize = tempInfo.chunkSize;
					}
					downloadProgress = (downloadFileInfo_->downloadedChunksCount() - 1) * tempInfo.chunkSize + lastChunkSize;
				} else {
					downloadProgress = downloadFileInfo_->downloadedChunksCount() * tempInfo.chunkSize;
				}
				critSect_->Leave();
				
				delegate_->DownloadProgressHasChanged(this, downloadProgress);
			}
			break;
		}
		case MSG_FD_RECEIVED_MESSAGE_s: {
			SignallingMessageData *param = static_cast<SignallingMessageData*>(msg->pdata);
			this->MessageReceived_s(param->msg, param->transportType, param->wrapperId, param->token);
			delete param;
			break;
		}
		case MSG_FD_STOP_DOWNLOADING_FILE_s: {
			this->StopFileTransfer_s();
			break;
		}
		case MSG_FD_PAUSE_DOWNLOADING_FILE_s: {
			this->PauseFileTransfer_s();
			break;
		}
		case MSG_FD_RESUME_DOWNLOADING_FILE_s: {
			this->ResumeFileTransfer_s();
			break;
		}
			
		case MSG_FD_DOWNLOAD_CANCELED_c: {
			if (delegate_) {
				delegate_->DownloadHasBeenCanceled(this);
			}
			break;
		}
		case MSG_FD_DOWNLOAD_FINISHED_c: {
			if (delegate_) {
				delegate_->DownloadHasBeenFinished(this, filePath_);
			}
			break;
		}
		case MSG_FD_CLEANED_UP_c: {
			if (delegate_) {
				delegate_->FileDownloaderHasStoppedAndCleanedUp(this);
			}
			break;
		}
		
		default:
		break;
	}
}


rtc::scoped_refptr<PeerConnectionWrapper> FileDownloader::GetFreeWrapperForChunkRequest()
{
	rtc::scoped_refptr<PeerConnectionWrapper> returnWrapper = NULL;
	
	for (WrapperIdToWrapperMap::iterator it = activeConnections_.begin(); it != activeConnections_.end(); ++it) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = it->second;
		
		FreeDownloadersMap::iterator freeDownloaderIt = downloadFileInfo_->freeDownloaders_.find(UniqueDownloadDataChannelId(wrapper->factoryId(), kDefaultDataChannelLabel));
		if (freeDownloaderIt != downloadFileInfo_->freeDownloaders_.end() && !freeDownloaderIt->second.isCurrentlyDownloading && wrapper->HasOpenedDataChannel()) {
			returnWrapper = wrapper;
			break;
		} 
	}
	
	return returnWrapper;
}


void FileDownloader::RequestNextChunk()
{
	workerQueue_->Post(this, MSG_FD_REQUEST_NEXT_CHUNK_s);
}


void FileDownloader::RequestNextChunkDelayed(int cmsDelay)
{
	workerQueue_->PostDelayed(cmsDelay, this, MSG_FD_REQUEST_NEXT_CHUNK_s);
}


void FileDownloader::RequestNextChunk_s()
{
	if (downloadFileInfo_) {
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->GetFreeWrapperForChunkRequest();
		
		if (isDownloadStarted_ == true && wrapper) {
			
			if (downloadFileInfo_->HasChunksToDownload()) {
				if (firstChunkDownloaded_) {
					uint32 nextChunkNumber = downloadFileInfo_->GetNextChunkNumberToDownload();
					if (nextChunkNumber != UINT32_MAX) {
						this->RequestChunkNumber(nextChunkNumber, wrapper, kDefaultDataChannelLabel);
					}
					this->RequestNextChunkDelayed(500);
				} else {
					if (!downloadingFirstChunk_) {
						downloadingFirstChunk_ = true;
						this->RequestChunkNumber(0, wrapper, kDefaultDataChannelLabel);
					} else {
						this->RequestNextChunkDelayed(500);
					}
				}
			} else {
				this->FileHasBeenDownloaded();
			}
		} else {
			spreed_me_log("Download hasn't started yet or no free wrapper found! Free wrapper exists %s", wrapper ? "YES" : "NO");
		}
	} else {
		spreed_me_log("No DownloadFileInfo. This shouldn't happen!");
		assert(false);
	}
}


void FileDownloader::RequestChunkNumber(int chunkNumber, PeerConnectionWrapper *wrapper, const std::string &dataChannelName)
{
	Json::Value chunkRequestJson;
	chunkRequestJson[kDataChannelChunkRequestModeKey] = kDataChannelChunkRequestModeRequestKey;
	chunkRequestJson[kDataChannelChunkSequenceNumberKey] = chunkNumber;
	
	std::string msg = chunkRequestJson.toStyledString();
	spreed_me_log("Asking for chunk %d with message %s", chunkNumber, msg.c_str());
	
	FreeDownloadersMap::iterator mappingIt = downloadFileInfo_->freeDownloaders_.find(UniqueDownloadDataChannelId(wrapper->factoryId(), dataChannelName));
	if (mappingIt != downloadFileInfo_->freeDownloaders_.end()) {
		mappingIt->second.isCurrentlyDownloading = true;
		mappingIt->second.chunkNumber = chunkNumber;
	} else {
		spreed_me_log("This is error. At the moment we agreed to create all downloaders before starting download so we should already find one.");
	}
	
	wrapper->SendData(msg, dataChannelName);
}


void FileDownloader::UpdateDownloadProgress()
{
	callbacksMessageQueue_->Post(this, MSG_FD_UPDATE_DOWNLOAD_PROGRESS_c);
}


void FileDownloader::FileHasBeenDownloaded()
{
	if (fileHandle_.is_open()) {
		fileHandle_.close();
	}
	
	this->EraseAllWrappers();
	
	if (tmpFilePath_ != filePath_) {

		char *suggestedFileLocation = NULL;
		makeFileNameSuggestion(filePath_.c_str(), &suggestedFileLocation);
		if (suggestedFileLocation) {
			bool success = moveFile(tmpFilePath_.c_str(), suggestedFileLocation);
			if (!success) {
				spreed_me_log("File couldn't be moved from '%s' to '%s'!", tmpFilePath_.c_str(), filePath_.c_str());
				assert(false);
			}
			filePath_ = std::string(suggestedFileLocation);
			free(suggestedFileLocation);
		} else {
			spreed_me_log("Something went wrong with file names. TempFilePath %s filePath %s", tmpFilePath_.c_str(), filePath_.c_str());
			assert(false);
		}
	}
	
	callbacksMessageQueue_->Post(this, MSG_FD_DOWNLOAD_FINISHED_c);
}


void FileDownloader::MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token)
{
	SignallingMessageData *msgData = new SignallingMessageData(msg, transportType, wrapperId, token);
	workerQueue_->Post(this, MSG_FD_RECEIVED_MESSAGE_s, msgData);
}


void FileDownloader::ReceivedOffer_s(const Json::Value &offerJson, const std::string &from)
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


void FileDownloader::ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from)
{
	Json::Value unwrappedAnswer = answerJson.get(kAnswerKey, Json::Value());
	if (!unwrappedAnswer.isNull()) {
		
		std::string sdp = unwrappedAnswer.get(kSessionDescriptionSdpKey, Json::Value()).asString();
		std::string id = unwrappedAnswer.get(kDataChannelIdKey, Json::Value()).asString();
		std::string token = unwrappedAnswer.get(kDataChannelTokenKey, Json::Value()).asString();
		
		rtc::scoped_refptr<PeerConnectionWrapper> wrapper = this->WrapperForUserIdTokenId(from, id);
		
		if (wrapper) {
			if (wrapper->signalingState() == webrtc::PeerConnectionInterface::kHaveLocalOffer) {
				if (!sdp.empty()) {
					wrapper->SetupRemoteAnswer(sdp);
				}
			}
		}
	}
}


/*----------------------PeerConnectionWrapperDelegateInterface-------------------*/

void FileDownloader::AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendAnswer(sdType, sdp, fileInfo_.token, peerConnectionWrapper->factoryId(), peerConnectionWrapper);
}


void FileDownloader::OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper)
{
	signallingHandler_->SendOffer(sdType, sdp, fileInfo_.token, peerConnectionWrapper->factoryId(), std::string(), peerConnectionWrapper);
}


void FileDownloader::CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper)
{
	if (candidate->sdp_mid == "video" || candidate->sdp_mid == "audio") {
        spreed_me_log("Not sending video and audio ice candidate while from token based peer connection.\n");
        return;
    }
	
	signallingHandler_->SendCandidate(candidate, fileInfo_.token, peerConnectionWrapper->factoryId(), peerConnectionWrapper);
}


void FileDownloader::DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper)
{
	critSect_->Enter();
	if (/*!isDownloadStarted_ &&*/ state == webrtc::DataChannelInterface::kOpen) {
		isDownloadStarted_ = true;
		this->RequestNextChunk();
	}
	critSect_->Leave();
	spreed_me_log("Received data channel in FileDownloader!");
}


void FileDownloader::ReceivedDataChannelData(webrtc::DataBuffer *buffer,
											webrtc::DataChannelInterface *data_channel,
											PeerConnectionWrapper *wrapper)
{
	if (buffer->binary) {
		
		char *buf = (char *)buffer->data.data();
//		spreed_me_log("Buffer data length = %u", buffer.data.length());
		uint32 size = buffer->data.length();
		
		uint8 version = (uint8)buf[0];
		if (version != 0) {
			spreed_me_log("File tranfer protocol version is not 0 but %d", version);
		}
//		spreed_me_log("Received binary data. Assuming file download. Version %d", version);
		
		//TODO: This conversion works only for little endian.
		// We need to cast buf to unsigned char because otherwise compiler will fill empty bytes with '1' instead of '0'.
		uint32 chunkSequenceNumber = 0;
		chunkSequenceNumber = chunkSequenceNumber | ((uint8)buf[4]) << 0 | ((uint8)buf[5]) << 8 | ((uint8)buf[6]) << 16 | ((uint8)buf[7]) << 24;
		uint32 crc32 = 0;
		crc32 = crc32 | ((uint8)buf[8]) << 0 | ((uint8)buf[9]) << 8 | ((uint8)buf[10]) << 16 | ((uint8)buf[11]) << 24;
		
		
		// Get rid of the first 12 service bytes. And work with raw data only.
		buf = &buf[12];
		size = size - 12;
		
		uint32 threadSafeChunkSize = 0;
		
		critSect_->Enter();
		
		if (fileInfo_.chunkSize == 0) {
			fileInfo_.chunkSize = size;
			spreed_me_log("Chunk size %u given", size);
		}
		
		threadSafeChunkSize = fileInfo_.chunkSize;
		
		critSect_->Leave();
		
		if (size > threadSafeChunkSize) {
			spreed_me_log("Buffer size is bigger than expected. Expected chunksize = %lu received size = %lu. This is error.", fileInfo_.chunkSize, size);
			this->RequestNextChunk();
			return;
		}
		
		uint32 calcCrc32 = crc32buf(buf, size);
		
		if (calcCrc32 == crc32) {
			if (fileHandle_.is_open()) {
				
				fileHandle_.seekp(chunkSequenceNumber * fileInfo_.chunkSize);
				fileHandle_.write(buf, size);
				
				//TODO: Check if there is no race conditions here in chunk status setting
				critSect_->Enter();
				downloadFileInfo_->SetChunkStatus(chunkSequenceNumber, kChunkDownloaded);
				if (chunkSequenceNumber == 0) {
					firstChunkDownloaded_ = true;
					downloadingFirstChunk_ = false;
				}
				downloadFileInfo_->SetDownloadStatusPair(UniqueDownloadDataChannelId(wrapper->factoryId(),data_channel->label()), DownloadStatusPair());
				critSect_->Leave();
				
				spreed_me_log("Writing chunk number %d chunk size %u buffer size %u and requesting next chunk.", chunkSequenceNumber, fileInfo_.chunkSize, size);
				this->UpdateDownloadProgress();
				//This should be asynchronous
				this->RequestNextChunk();
			} else {
				spreed_me_log("file handle is not opened!");
			}
		} else {
			spreed_me_log("Crc checksum doesn't match! Given %lu calculated %lu", crc32, calcCrc32);
			if (chunkSequenceNumber == 0) {
				downloadingFirstChunk_ = false;
			}
			
			this->RequestNextChunk();
		}
		
		delete buffer;
	} else {
		signallingHandler_->ReceivedDataChannelData(buffer, data_channel, wrapper);
	}
}
/*--------------------End PeerConnectionWrapperDelegateInterface---------------------------------*/


