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

#ifndef __SpreedME__FileUploader__
#define __SpreedME__FileUploader__

#include <iostream>

#include "FileTransfererBase.h"

namespace spreedme {
	
class FileUploader;

class FileUploaderDelegateInterface
{
public:
	virtual void FileSharingHasStarted(const FileInfo &fileInfo, FileUploader *fileUploader) = 0;
	virtual void FileUploaderHasStoppedAndCleanedUp(FileUploader *fileUploader) = 0;
};
	
	
class FileUploader : public FileTransfererBase {
public:
	
	FileUploader(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
				 SignallingHandler *signallingHandler,
				 MessageQueueInterface *workerQueue,
				 MessageQueueInterface *callbacksMessageQueue);
	
	virtual void StartSharingFile(const std::string &filePath, const std::string &fileType, const std::string &fileName, const std::string &token, bool shouldDeleteOnFinish = false);
	
	virtual void SetDelegate(FileUploaderDelegateInterface *delegate) { delegate_ = delegate; };
	
	static std::string CreateFileUploadTokenForFileName(const std::string &fileName);
	
	virtual void StopFileTransfer(); // Calling this method is irrevocable. Do not delete uploader until call to 'FileUploaderHasStoppedAndCleanedUp'
	virtual void PauseFileTransfer() {}; // Does nothing
	virtual void ResumeFileTransfer() {}; // Does nothing
	
protected:
	
	FileUploader();
	virtual ~FileUploader();
	
	virtual void OnMessage(rtc::Message* msg);
		
	virtual void StartSharingFile_s(const std::string &filePath, const std::string &fileType, const std::string &fileName, const std::string &token, bool shouldDeleteOnFinish = false);
	
	virtual void AsyncDeleteWrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId);
	
	// Peer connection wrapper delegate interface implementation
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *spreedPeerConnection) {};
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper) {};
	
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	
	virtual void StopSharingFile_s();
	
	// These methods are called in signallingThread
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token);
	virtual void ReceivedOffer_s(const Json::Value &offerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from); // expects inner JSON (without Data :{})
		
	virtual void DecideOnFileChunksForFileSize();
	
private:
	FileUploaderDelegateInterface *delegate_; // We do not own it!
	
	bool shouldDeleteFileOnFinish_;
};
	
} // namespace spreedme





#endif /* defined(__SpreedME__FileUploader__) */
