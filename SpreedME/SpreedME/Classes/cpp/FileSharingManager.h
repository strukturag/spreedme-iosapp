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

#ifndef __SpreedME__FileSharingManager__
#define __SpreedME__FileSharingManager__

#include <iostream>
#include <map>

#include <webrtc/base/refcount.h>

#include "FileDownloader.h"
#include "FileTransfererBase.h"
#include "FileUploader.h"


namespace spreedme {
	
typedef std::map< std::string, rtc::scoped_refptr<FileDownloader> > TokenToFileDownloaderMap;
typedef std::map< std::string, rtc::scoped_refptr<FileUploader> > TokenToFileUploaderMap;
	
	
class FileSharingManagerDelegateInterface
{
public:
	virtual void DownloadHasBeenFinished(const std::string &token, const std::string &filePath) = 0;
	virtual void DownloadProgressHasChanged(const std::string &token, uint64 bytesDownloaded, double estimatedFinishTimeInterval) = 0;
	virtual void DownloadHasBeenCanceled(const std::string &token) = 0;
	virtual void DownloadHasFailed(const std::string &token) = 0;
	virtual void DownloadHasBeenPaused(const std::string &token) = 0;
	virtual void DownloadHasBeenResumed(const std::string &token) = 0;
	
	virtual void FileSharingHasStarted(const std::string &token, const FileInfo &fileInfo) = 0;
};

	
/*
 FileSharingManager is designed to be safe to operate in callbackQueue thread.
 */
class FileSharingManager : public rtc::RefCountInterface,
						   public FileUploaderDelegateInterface,
						   public FileDownloaderDelegateInterface
{
public:
	
	FileSharingManager(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
					   SignallingHandler *signallingHandler,
					   MessageQueueInterface *workerQueue,
					   MessageQueueInterface *callbackQueue);
	
	virtual void SetDelegate(FileSharingManagerDelegateInterface *delegate) {delegate_ = delegate;};
	
	
	virtual void DownloadFile(const FileInfo &fileInfo, const std::string &fileLocation, const std::set<std::string> &userIds, const std::string &tempFilePath = "");
	virtual void PauseFileDownloadForToken(const std::string &token);
	virtual void ResumeFileDownloadForToken(const std::string &token);
	virtual void StopFileDownloadForToken(const std::string &token);
	
	virtual void StartSharingFile(const std::string &filePath,
								  const std::string &fileType,
								  const std::string &fileName,
								  const std::string &token,
								  bool shouldDeleteOnFinish = false);
	virtual void StopSharingFileForToken(const std::string &token);
	
	virtual std::set<std::string> CurrentlyDownloadingFileTokens();
	virtual std::set<std::string> CurrentlySharedFileTokens();
	virtual FileInfo FileInfoForToken(const std::string &token);
	
protected:
	
	FileSharingManager();
	~FileSharingManager();
	
	// FileUploaderDelegateInterface implementation
	virtual void FileSharingHasStarted(const FileInfo &fileInfo, FileUploader *fileUploader);
	virtual void FileUploaderHasStoppedAndCleanedUp(FileUploader *fileUploader);
	
	// FileDownloaderDelegateInterface implementation
	virtual void DownloadHasBeenFinished(FileDownloader *fileDownloader, const std::string &filePath);
	virtual void DownloadProgressHasChanged(FileDownloader *fileDownloader, uint64 bytesDownloaded);
	virtual void DownloadHasBeenCanceled(FileDownloader *fileDownloader);
	virtual void DownloadHasFailed(FileDownloader *fileDownloader);
	virtual void DownloadHasBeenPaused(FileDownloader *fileDownloader);
	virtual void DownloadHasBeenResumed(FileDownloader *fileDownloader);
	virtual void FileDownloaderHasStoppedAndCleanedUp(FileDownloader *fileDownloader);
	
	
	virtual bool FileTransfererForTokenExists(const std::string &token); // doesn't check in stopped transferers
	virtual rtc::scoped_refptr<FileUploader> FileUploaderForToken(const std::string &token); // returns only non-stopped file uploaders
	virtual rtc::scoped_refptr<FileDownloader> FileDownloaderForToken(const std::string &token); // returns active and paused downloaders
	
	
	webrtc::CriticalSectionWrapper *critSect_;
	
	TokenToFileUploaderMap activeFileUploaders_;
	TokenToFileUploaderMap stoppedFileUploaders_;
	TokenToFileDownloaderMap activeFileDownloaders_;
	TokenToFileDownloaderMap stoppedFileDownloaders_;
	
	PeerConnectionWrapperFactory *peerConnectionWrapperFactory_; // We do not own it!
	SignallingHandler *signallingHandler_; // We do not own it!
	
	MessageQueueInterface *workerQueue_; // We do not own it!
	MessageQueueInterface *callbackQueue_; // We do not own it!
	
	
	
private:
	rtc::scoped_refptr<FileDownloader> CreateFileDownloader();
	rtc::scoped_refptr<FileUploader> CreateFileUploader();
	
	bool InsertUploader(const std::string &token, rtc::scoped_refptr<FileUploader> uploader, TokenToFileUploaderMap &map);
	bool InsertDownloader(const std::string &token, rtc::scoped_refptr<FileDownloader> downloader, TokenToFileDownloaderMap &map);
	bool MoveDownloader(const std::string &token, TokenToFileDownloaderMap &source, TokenToFileDownloaderMap &dest);
	bool MoveUploader(const std::string &token, TokenToFileUploaderMap &source, TokenToFileUploaderMap &dest);
	void DeleteTransferer(const std::string &token); // deletes every transferer for given token in all transfer maps (activeFileUploaders_, stoppedFileUploaders_, ...)
	void DeleteStoppedTransferer(const std::string &token); // deletes every transferer for given token in only in stooped transfer maps (stoppedFileUploaders_, ...)
	void EraseAllTransferers();
	
	FileSharingManagerDelegateInterface *delegate_;
};
	
	
} // namespace spreedme


#endif /* defined(__SpreedME__FileSharingManager__) */
