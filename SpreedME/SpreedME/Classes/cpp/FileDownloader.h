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

#ifndef __SpreedME__FileDownloader__
#define __SpreedME__FileDownloader__

#include <iostream>
#include <fstream>

#include "FileTransfererBase.h"
#include "FileDownloadInfo.h"

namespace spreedme {
		
class FileDownloader;
	
class FileDownloaderDelegateInterface {
public:
	virtual void DownloadHasBeenFinished(FileDownloader *fileDownloader, const std::string &filePath) = 0;
	virtual void DownloadProgressHasChanged(FileDownloader *fileDownloader, uint64 bytesDownloaded) = 0;
	virtual void DownloadHasBeenCanceled(FileDownloader *fileDownloader) = 0; // This signals that download has been canceled, at this point FileDownloader still lives and can have all internal structure.
	virtual void DownloadHasFailed(FileDownloader *fileDownloader) = 0;
	virtual void DownloadHasBeenPaused(FileDownloader *fileDownloader) = 0;
	virtual void DownloadHasBeenResumed(FileDownloader *fileDownloader) = 0;
	virtual void FileDownloaderHasStoppedAndCleanedUp(FileDownloader *fileDownloader) = 0; //This signals that FileDownloader has cleaned up all its internals and ready to be disposed of
};

	
typedef std::map<std::string, WrapperIdToWrapperMap *> UserIdWrapperIdToWrapperMapPtrMap;
typedef std::pair<std::string, WrapperIdToWrapperMap *> UserIdWrapperIdToWrapperMapPtrPair;
	
class FileDownloader : public FileTransfererBase
{
public:
	
	FileDownloader(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
				   SignallingHandler *signallingHandler,
				   MessageQueueInterface *workerQueue,
				   MessageQueueInterface *callbacksMessageQueue);
	
	// @fileLocation should be a directory where to store the file with write permission, string itself has to have ending '/'.
	virtual void DownloadFileForToken(const FileInfo &fileInfo, const std::string &fileLocation, const std::set<std::string> &userIds, const std::string &tempFilePath = "");
	// Now you can only add userIds
	virtual void UpdateUserIds(std::set<std::string> userIds);
	
	virtual void SetDelegate(FileDownloaderDelegateInterface *delegate) {critSect_->Enter(); delegate_ = delegate; critSect_->Leave();};
	
	virtual void StopFileTransfer();
	virtual void PauseFileTransfer();
	virtual void ResumeFileTransfer();
	
protected:

	FileDownloader();
	virtual ~FileDownloader();
	
	virtual void OnMessage(rtc::Message* msg);
	
	void StartFileDownload();
	void StartFileDownload_s(int maxSimultaneousPeers, int maxSimultaneousConnectionsPerPeer); //For now it ignores arguments and uses 1 peer and 1 connection per peer.
	void StopFileTransfer_s();
	void PauseFileTransfer_s();
	void ResumeFileTransfer_s();
	
	std::string PickUserForDownload();
	
	std::string CreateWrapperIdForOutgoingOffer(const std::string &token, const std::string &to);

	void UpdateDownloadProgress();
	
	// Peer connection wrapper delegate interface implementation
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *spreedPeerConnection) {};
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper) {};
	
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation* candidate, PeerConnectionWrapper *peerConnectionWrapper);
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper);
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper);
	
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token);
	virtual void ReceivedOffer_s(const Json::Value &offerJson, const std::string &from); // expects inner JSON (without Data :{})
	virtual void ReceivedAnswer_s(const Json::Value &answerJson, const std::string &from); // expects inner JSON (without Data :{})
		
private:
	
	void RequestNextChunk();
	void RequestNextChunkDelayed(int cmsDelay);
	void RequestNextChunk_s();
	void RequestChunkNumber(int chunkNumber, PeerConnectionWrapper *wrapper, const std::string &dataChannelName);
	rtc::scoped_refptr<PeerConnectionWrapper> GetFreeWrapperForChunkRequest();
	void FileHasBeenDownloaded();
	
	// Instance variables ----------------------------------------------------------------------
	std::set<std::string> tokenPeerConnectionWrapperIds_;
	
	FileDownloaderDelegateInterface *delegate_; // We do not own it!
	
	DownloadFileInfo *downloadFileInfo_;
	
	std::string tmpFilePath_;
	
	bool isDownloadStarted_;
	bool firstChunkDownloaded_;
	bool downloadingFirstChunk_;
	
	int maxSimultaneousPeers_;
	int maxSimultaneousConnectionsPerPeer_;
};

} // namespace spreedme

#endif /* defined(__SpreedME__FileDownloader__) */
