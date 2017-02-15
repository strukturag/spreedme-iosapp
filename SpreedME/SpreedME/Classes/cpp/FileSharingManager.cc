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

#include "FileSharingManager.h"

#include <webrtc/base/thread.h>

#include "ObjCMessageQueue.h"
#include "TalkBaseThreadWrapper.h"

using namespace spreedme;

FileSharingManager::FileSharingManager(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
									   SignallingHandler *signallingHandler,
									   MessageQueueInterface *workerQueue,
									   MessageQueueInterface *callbackQueue) :
	critSect_(webrtc::CriticalSectionWrapper::CreateCriticalSection()),
	peerConnectionWrapperFactory_(peerConnectionWrapperFactory),
	signallingHandler_(signallingHandler),
	workerQueue_(workerQueue),
	callbackQueue_(callbackQueue),
	delegate_(NULL)
{
}


FileSharingManager::~FileSharingManager()
{
	delete critSect_;
}


void FileSharingManager::DownloadFile(const FileInfo &fileInfo, const std::string &fileLocation, const std::set<std::string> &userIds, const std::string &tempFilePath)
{
	rtc::scoped_refptr<spreedme::FileDownloader> downloader = this->FileDownloaderForToken(fileInfo.token);
	
	if (downloader == NULL) {
	
		downloader = this->CreateFileDownloader();
		
		if (downloader) {
		
			downloader->SetDelegate(this);
			this->InsertDownloader(fileInfo.token, downloader, activeFileDownloaders_);
							
			downloader->DownloadFileForToken(fileInfo, fileLocation, userIds, tempFilePath);
		}
	} else {
		spreed_me_log("We already have downloader for this token (%s)!", fileInfo.token.c_str());
	}
}


void FileSharingManager::PauseFileDownloadForToken(const std::string &token)
{
	
}


void FileSharingManager::ResumeFileDownloadForToken(const std::string &token)
{
	
}


void FileSharingManager::StopFileDownloadForToken(const std::string &token)
{
	rtc::scoped_refptr<FileDownloader> downloader = this->FileDownloaderForToken(token);
	if (downloader) {
		this->MoveDownloader(downloader->fileInfo().token, activeFileDownloaders_, stoppedFileDownloaders_);
		downloader->StopFileTransfer();
	}
}


void FileSharingManager::StartSharingFile(const std::string &filePath,
					  const std::string &fileType,
					  const std::string &fileName,
					  const std::string &token,
					  bool shouldDeleteOnFinish)
{
	
	
	rtc::scoped_refptr<spreedme::FileUploader> uploader = this->CreateFileUploader();
	
	if (uploader) {

		uploader->SetDelegate(this);
		this->InsertUploader(token, uploader, activeFileUploaders_);
		
		uploader->StartSharingFile(filePath, fileType, fileName, token, shouldDeleteOnFinish);
	}
}


void FileSharingManager::StopSharingFileForToken(const std::string &token)
{
	rtc::scoped_refptr<FileUploader> fileUploader = this->FileUploaderForToken(token);
	if (fileUploader) {
		this->MoveUploader(fileUploader->fileInfo().token, activeFileUploaders_, stoppedFileUploaders_);
		fileUploader->StopFileTransfer();
	}
}


std::set<std::string> FileSharingManager::CurrentlyDownloadingFileTokens()
{
	std::set<std::string> set;
	for (TokenToFileDownloaderMap::iterator it = activeFileDownloaders_.begin(); it != activeFileDownloaders_.end(); ++it) {
		set.insert(it->first);
	}
	
	return set;
}


std::set<std::string> FileSharingManager::CurrentlySharedFileTokens()
{
	std::set<std::string> set;
	for (TokenToFileUploaderMap::iterator it = activeFileUploaders_.begin(); it != activeFileUploaders_.end(); ++it) {
		set.insert(it->first);
	}
	
	return set;
}


// FileUploaderDelegateInterface implementation
void FileSharingManager::FileSharingHasStarted(const FileInfo &fileInfo, FileUploader *fileUploader)
{
	if (delegate_) {
		delegate_->FileSharingHasStarted(fileInfo.token, fileInfo);
	}
}


void FileSharingManager::FileUploaderHasStoppedAndCleanedUp(FileUploader *fileUploader)
{
	this->DeleteStoppedTransferer(fileUploader->fileInfo().token);
}


// FileUploaderDelegateInterface implementation END


// FileDownloaderDelegateInterface implementation
void FileSharingManager::DownloadHasBeenFinished(FileDownloader *fileDownloader, const std::string &filePath)
{
	if (delegate_) {
		delegate_->DownloadHasBeenFinished(fileDownloader->fileInfo().token, filePath);
	}
	
	this->DeleteTransferer(fileDownloader->fileInfo().token);
}


void FileSharingManager::DownloadProgressHasChanged(FileDownloader *fileDownloader, uint64 bytesDownloaded)
{
	if (delegate_) {
		delegate_->DownloadProgressHasChanged(fileDownloader->fileInfo().token, bytesDownloaded, 0.0);
	}
}


void FileSharingManager::DownloadHasBeenCanceled(FileDownloader *fileDownloader)
{
	if (delegate_) {
		delegate_->DownloadHasBeenCanceled(fileDownloader->fileInfo().token);
	}
}


void FileSharingManager::DownloadHasFailed(FileDownloader *fileDownloader)
{
	this->DeleteTransferer(fileDownloader->fileInfo().token);
}


void FileSharingManager::DownloadHasBeenPaused(FileDownloader *fileDownloader)
{
	
}


void FileSharingManager::DownloadHasBeenResumed(FileDownloader *fileDownloader)
{
	
}


void FileSharingManager::FileDownloaderHasStoppedAndCleanedUp(FileDownloader *fileDownloader)
{
	this->DeleteStoppedTransferer(fileDownloader->fileInfo().token);
}
// FileDownloaderDelegateInterface implementation END


FileInfo FileSharingManager::FileInfoForToken(const std::string &token)
{
	if (this->FileTransfererForTokenExists(token)) {
		rtc::scoped_refptr<FileDownloader> downloader = this->FileDownloaderForToken(token);
		if (downloader) {
			return downloader->fileInfo();
		} else {
			rtc::scoped_refptr<FileUploader> uploader = this->FileUploaderForToken(token);
			if (uploader) {
				return uploader->fileInfo();
			} else {
				spreed_me_log("Strange situation. We know that transferer for token exists but we can't find it.");
			}
		}
	}
	
	return FileInfo();
}


bool FileSharingManager::FileTransfererForTokenExists(const std::string &token)
{
	TokenToFileDownloaderMap::iterator it = activeFileDownloaders_.find(token);
	
	if (it != activeFileDownloaders_.end()) {
		return true;
	}
	
	TokenToFileUploaderMap::iterator it_up = activeFileUploaders_.find(token);
	
	if (it_up != activeFileUploaders_.end()) {
		return true;
	}
	
	return false;
}


rtc::scoped_refptr<FileUploader> FileSharingManager::FileUploaderForToken(const std::string &token)
{
	TokenToFileUploaderMap::iterator it = activeFileUploaders_.find(token);
	
	if (it != activeFileUploaders_.end()) {
		rtc::scoped_refptr<FileUploader> uploader = it->second;
		return uploader;
	}
	
	return NULL;
}


rtc::scoped_refptr<FileDownloader> FileSharingManager::FileDownloaderForToken(const std::string &token)
{
	TokenToFileDownloaderMap::iterator it = activeFileDownloaders_.find(token);
	
	if (it != activeFileDownloaders_.end()) {
		rtc::scoped_refptr<FileDownloader> downloader = it->second;
		return downloader;
	}
	
	return NULL;
}


rtc::scoped_refptr<FileDownloader> FileSharingManager::CreateFileDownloader()
{
	rtc::scoped_refptr<spreedme::FileDownloader> downloader =
	new rtc::RefCountedObject<spreedme::FileDownloader>(peerConnectionWrapperFactory_,
															  signallingHandler_,
															  workerQueue_,
															  callbackQueue_);
	return downloader;
}


rtc::scoped_refptr<FileUploader> FileSharingManager::CreateFileUploader()
{
	rtc::scoped_refptr<spreedme::FileUploader> uploader =
	new rtc::RefCountedObject<spreedme::FileUploader>(peerConnectionWrapperFactory_,
															signallingHandler_,
															workerQueue_,
															callbackQueue_);
	
	return uploader;
}


bool FileSharingManager::InsertUploader(const std::string &token, rtc::scoped_refptr<FileUploader> uploader, TokenToFileUploaderMap &map)
{
	std::pair<TokenToFileUploaderMap::iterator , bool> ret = map.insert(std::pair< std::string,  rtc::scoped_refptr<FileUploader> >(token, uploader));
	return ret.second;
}


bool FileSharingManager::InsertDownloader(const std::string &token, rtc::scoped_refptr<FileDownloader> downloader, TokenToFileDownloaderMap &map)
{
	std::pair<TokenToFileDownloaderMap::iterator , bool> ret = map.insert(std::pair< std::string,  rtc::scoped_refptr<FileDownloader> >(token, downloader));
	return ret.second;
}


bool FileSharingManager::MoveDownloader(const std::string &token, TokenToFileDownloaderMap &source, TokenToFileDownloaderMap &dest)
{
	TokenToFileDownloaderMap::iterator it = source.find(token);
	
	if (it != source.end()) {
		rtc::scoped_refptr<FileDownloader> transferer = it->second;
		source.erase(it);
		
		return this->InsertDownloader(token, transferer, dest);
	}
	
	return false;
}


bool FileSharingManager::MoveUploader(const std::string &token, TokenToFileUploaderMap &source, TokenToFileUploaderMap &dest)
{
	TokenToFileUploaderMap::iterator it = source.find(token);
	
	if (it != source.end()) {
		rtc::scoped_refptr<FileUploader> transferer = it->second;
		source.erase(it);
		
		return this->InsertUploader(token, transferer, dest);
	}
	
	return false;
}


void FileSharingManager::DeleteTransferer(const std::string &token)
{
	TokenToFileDownloaderMap::iterator it_act_down = activeFileDownloaders_.find(token);
	
	if (it_act_down != activeFileDownloaders_.end()) {
		activeFileDownloaders_.erase(it_act_down);
	}
	
	TokenToFileDownloaderMap::iterator it_stoppedd_down = stoppedFileDownloaders_.find(token);
	
	if (it_stoppedd_down != stoppedFileDownloaders_.end()) {
		stoppedFileDownloaders_.erase(it_stoppedd_down);
	}
	
	TokenToFileUploaderMap::iterator it_act_up = activeFileUploaders_.find(token);
	
	if (it_act_up != activeFileUploaders_.end()) {
		activeFileUploaders_.erase(it_act_up);
	}
	
	TokenToFileUploaderMap::iterator it_stopped_up = stoppedFileUploaders_.find(token);
	
	if (it_stopped_up != stoppedFileUploaders_.end()) {
		stoppedFileUploaders_.erase(it_stopped_up);
	}
}


void FileSharingManager::DeleteStoppedTransferer(const std::string &token)
{
	TokenToFileDownloaderMap::iterator it_stoppedd_down = stoppedFileDownloaders_.find(token);
	
	if (it_stoppedd_down != stoppedFileDownloaders_.end()) {
		stoppedFileDownloaders_.erase(it_stoppedd_down);
	}
		
	TokenToFileUploaderMap::iterator it_stopped_up = stoppedFileUploaders_.find(token);
	
	if (it_stopped_up != stoppedFileUploaders_.end()) {
		stoppedFileUploaders_.erase(it_stopped_up);
	}
}


void FileSharingManager::EraseAllTransferers()
{
	activeFileDownloaders_.clear();
	stoppedFileDownloaders_.clear();
	activeFileUploaders_.clear();
	stoppedFileUploaders_.clear();
}
