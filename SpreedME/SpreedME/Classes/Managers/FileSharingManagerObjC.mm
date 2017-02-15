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

#import "FileSharingManagerObjC.h"

#include "FileSharingManager.h"

#include "FileTransfererBase.h"
#include "ObjCMessageQueue.h"
#include "PeerConnectionWrapper.h"
#include "PeerConnectionWrapperFactory.h"
#include "SignallingHandler.h"
#include "TalkBaseThreadWrapper.h"
#include <webrtc/base/thread.h>

#import "UsersManager.h"
#import "SMConnectionController_ObjectiveCPP.h"
#import "ChatManager.h"
#import "ChatMessage.h"
#import "PeerConnectionController.h"
#import "PeerConnectionController_ObjectiveCPP.h"
#import "SMLocalizedStrings.h"
#import "UsersActivityController.h"


NSString * const FileHasBeenDownloadedNotification			= @"FileHasBeenDownloadedNotification";
NSString * const FileDownloadProgressHasChangedNotification	= @"FileDownloadProgressHasChangedNotification";

NSString * const kFilePathUserInfoKey						= @"kFilePathUserInfoKey";
NSString * const kFileTokenUserInfoKey						= @"kFileTokenUserInfoKey";
NSString * const kFileDownloadProgressUserInfoKey			= @"kFileDownloadProgressUserInfoKey";


ChatFileInfo *ChatFileInfoFromFileInfo(spreedme::FileInfo *fileInfo)
{
	ChatFileInfo *chatFileInfo = (ChatFileInfo *)[ChatManager chatMessageWithType:kChatMessageTypeFileInfo
																			   to:nil
																			 from:[UsersManager defaultManager].currentUser.sessionId
																			  mId:[ChatManager generateNewMId]
																			 date:[NSDate date]
																	   dateString:nil
																		  message:kSMLocalStringFileLabel];
	unsigned int chunks = fileInfo->chunks;
	NSString *token = NSStr(fileInfo->token.c_str());
	NSString *fileName = NSStr(fileInfo->fileName.c_str());
	NSString *fileType = NSStr(fileInfo->fileType.c_str());
	unsigned long long fileSize = fileInfo->fileSize;
	
	chatFileInfo.chunks = chunks;
	chatFileInfo.token = token;
	chatFileInfo.fileName = fileName;
	chatFileInfo.fileType = fileType;
	chatFileInfo.fileSize = fileSize;
	
	return chatFileInfo;
}


class FileSharingManagerDelegate : public spreedme::FileSharingManagerDelegateInterface {
	
public:
	
	virtual ~FileSharingManagerDelegate() {};
	
	FileSharingManagerDelegate(FileSharingManagerObjC *messageReceiver) : messageReceiver_(messageReceiver) {};
	
	virtual void DownloadHasBeenFinished(const std::string &token, const std::string &filePath)
	{
		FileSharingManagerObjC *messageReceiver = messageReceiver_;
		NSString *filePath_objC = NSStr(filePath.c_str());
		NSString *token_objC = NSStr(token.c_str());
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[messageReceiver fileHasBeenDownloadedForToken:token_objC filePath:filePath_objC];
		});
		
		return;
	};
	
	virtual void DownloadProgressHasChanged(const std::string &token, uint64 bytesDownloaded, double estimatedFinishTimeInterval)
	{
		FileSharingManagerObjC *messageReceiver = messageReceiver_;
		NSString *token_objC = NSStr(token.c_str());
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[messageReceiver fileDownloadProgressHasChanged:bytesDownloaded forToken:token_objC];
		});
		
		return;
	};
	
	virtual void DownloadHasBeenCanceled(const std::string &token)
	{};
	
	virtual void DownloadHasFailed(const std::string &token)
	{};
	
	virtual void DownloadHasBeenPaused(const std::string &token)
	{};
	
	virtual void DownloadHasBeenResumed(const std::string &token)
	{};
	
	virtual void FileSharingHasStarted(const std::string &token, const spreedme::FileInfo &fileInfo)
	{
		spreedme::FileInfo copy_fileInfo = fileInfo;
		ChatFileInfo *chatFileInfo = ChatFileInfoFromFileInfo(&copy_fileInfo);
		chatFileInfo.fileTransferType = kSTChatFileTransferTypeUpload;
		
		NSString *token_objC = NSStr(token.c_str());
		
		FileSharingManagerObjC *messageReceiver = messageReceiver_;
		dispatch_async(dispatch_get_main_queue(), ^{
			[messageReceiver fileSharingHasStartedForToken:token_objC chatFileInfo:chatFileInfo];
		});
	};
	
private:
	FileSharingManagerDelegate();
	
	__unsafe_unretained FileSharingManagerObjC *messageReceiver_;
};


@implementation FileSharingManagerObjC
{
	rtc::scoped_refptr<spreedme::FileSharingManager> _manager;
	
	NSMutableDictionary *_tokenFileShares;
	
	UIAlertView *_fileDownloadAlert;
	ChatFileInfo *_pendingFileInfo;
	
	FileSharingManagerDelegate *_fileSharingManagerDelegate;
	
	spreedme::ObjCMessageQueue *_callbacksMessageQueue;
	spreedme::TalkBaseThreadWrapper *_workerQueue;
	rtc::Thread *_workerThread;
	
    NSString *_documentsDirectory;
}


+ (instancetype)defaultManager
{
	static dispatch_once_t once;
    static FileSharingManagerObjC *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		
		_tokenFileShares = [[NSMutableDictionary alloc] init];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _documentsDirectory = [paths objectAtIndex:0];
        [self addSkipBackupAttributeToItemAtPath:_documentsDirectory];
		
		spreedme::PeerConnectionWrapperFactory *peerConnectionWrapperFactory = [[PeerConnectionController sharedInstance] peerConnectionWrapperFactory];
		
		_callbacksMessageQueue = spreedme::ObjCMessageQueue::CreateObjCMessageQueueMainQueue();
		
		_workerThread = new rtc::Thread();
		_workerThread->SetName("files worker thread", _workerThread);
		_workerThread->Start();
		_workerQueue = new spreedme::TalkBaseThreadWrapper(_workerThread);
		
		_manager =
			rtc::scoped_refptr<spreedme::FileSharingManager>(new rtc::RefCountedObject<spreedme::FileSharingManager>
																		(peerConnectionWrapperFactory,
																		 [SMConnectionController sharedInstance].signallingHandler,
																		 _workerQueue,
																		 _callbacksMessageQueue)
																   );
		
		_fileSharingManagerDelegate = new FileSharingManagerDelegate(self);
		_manager->SetDelegate(_fileSharingManagerDelegate);
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasResetApp:) name:UserHasResetApplicationNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedApplicationMode:) name:UserHasChangedApplicationModeNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
	_manager->SetDelegate(NULL);
	delete _fileSharingManagerDelegate;
	delete _callbacksMessageQueue;
	delete _workerQueue;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		_workerThread->Stop();
		delete _workerThread;
	});

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Public methods
- (void)startDownloadingFile:(ChatFileInfo *)fileInfo_objc
{
	if (fileInfo_objc) {
		ChatFileInfo *message = fileInfo_objc;
		dispatch_async(dispatch_get_main_queue(), ^{

			spreedme::FileInfo fileInfo;
			fileInfo.chunkSize = 0; // it will be calculated later.
			fileInfo.chunks = message.chunks;
			fileInfo.token = std::string([message.token cStringUsingEncoding:NSUTF8StringEncoding]);
			fileInfo.fileName = std::string([message.fileName cStringUsingEncoding:NSUTF8StringEncoding]);;
			fileInfo.fileType = std::string([message.fileType cStringUsingEncoding:NSUTF8StringEncoding]);
			fileInfo.fileSize = message.fileSize;
			
			std::set<std::string> userIds;
			NSString *userSessionId_objc = [message.from copy];
			std::string userId = std::string([userSessionId_objc cStringUsingEncoding:NSUTF8StringEncoding]);
			userIds.insert(userId);
			NSString *fileLocation_objc = [[self fileLocation] copy];
			std::string fileLocation = std::string([fileLocation_objc cStringUsingEncoding:NSUTF8StringEncoding]);
			
			NSString *tempFileLocation_objc = [self tempFileLocation];
			if (tempFileLocation_objc) {
				tempFileLocation_objc = [tempFileLocation_objc stringByAppendingFormat:@"%@_%@", [self randomFileName], message.fileName];
			} else {
				spreed_me_log("Couldn't retrieve temp directory");
			}
			std::string tempFileLocation = std::string([tempFileLocation_objc cStringUsingEncoding:NSUTF8StringEncoding]);
			spreed_me_log("Download File temp location: %s", tempFileLocation.c_str());
			
			_manager->DownloadFile(fileInfo, fileLocation, userIds, tempFileLocation);
		});
	}
}


- (void)pauseFileDownloadForToken:(NSString *)token
{
	if (token) {
		std::string token_cpp = std::string([token cStringUsingEncoding:NSUTF8StringEncoding]);
		
		_manager->PauseFileDownloadForToken(token_cpp);
	}
}


- (void)resumeFileDownloadForToken:(NSString *)token
{
	
}


- (void)stopFileDownloadForToken:(NSString *)token
{
	if (token) {
		std::string token_cpp = std::string([token cStringUsingEncoding:NSUTF8StringEncoding]);
		
		_manager->StopFileDownloadForToken(token_cpp);
	}
}


// fileType is MIME type.
- (void)startSharingFileAtPath:(NSString *)filePath fileName:(NSString *)fileName fileType:(NSString *)fileType fileIsTemporary:(BOOL)isTemporary forUsers:(NSSet *)users
{
	std::string fileName_cpp = std::string([fileName cStringUsingEncoding:NSUTF8StringEncoding]);
	std::string token = spreedme::FileUploader::CreateFileUploadTokenForFileName(fileName_cpp);
	
	_manager->StartSharingFile(std::string([filePath cStringUsingEncoding:NSUTF8StringEncoding]),
										std::string([fileType cStringUsingEncoding:NSUTF8StringEncoding]),
										fileName_cpp,
										token,
										true);
	
	NSString *token_objC = [NSString stringWithCString:token.c_str() encoding:NSUTF8StringEncoding];
	if (!users) {
		users = [NSSet set];
	}
	[_tokenFileShares setObject:users forKey:token_objC];
}


- (void)stopSharingFileForToken:(NSString *)token
{
	if (token) {
		std::string token_cpp = std::string([token cStringUsingEncoding:NSUTF8StringEncoding]);
		
		_manager->StopSharingFileForToken(token_cpp);
	}
}


- (NSSet *)currentlyDownloadingFileTokens
{
	NSSet *retSet = nil;
	std::set<std::string> set_cpp = _manager->CurrentlyDownloadingFileTokens();
	if (set_cpp.size()) {
		NSMutableSet *set = [NSMutableSet set];
		for (std::set<std::string>::iterator it = set_cpp.begin(); it != set_cpp.end(); ++it) {
			NSString *token = NSStr(it->c_str());
			[set addObject:token];
		}
		retSet = [NSSet setWithSet:set];
	}
	
	return retSet;
}


- (NSSet *)currentlySharedFileTokens
{
	NSSet *retSet = nil;
	std::set<std::string> set_cpp = _manager->CurrentlySharedFileTokens();
	if (set_cpp.size()) {
		NSMutableSet *set = [NSMutableSet set];
		for (std::set<std::string>::iterator it = set_cpp.begin(); it != set_cpp.end(); ++it) {
			NSString *token = NSStr(it->c_str());
			[set addObject:token];
		}
		retSet = [NSSet setWithSet:set];
	}
	
	return retSet;
}

- (ChatFileInfo *)fileInfoForToken:(NSString *)token
{
	ChatFileInfo *chatFileInfo = nil;
	
	std::string token_cpp = std::string([token cStringUsingEncoding:NSUTF8StringEncoding]);
	
	spreedme::FileInfo fileInfo = _manager->FileInfoForToken(token_cpp);
	if (!fileInfo.token.empty()) {
		chatFileInfo = ChatFileInfoFromFileInfo(&fileInfo);
	}
	
	return chatFileInfo;
}


#pragma mark - FileSharingManager delegate implementation

- (void)fileSharingHasStartedForToken:(NSString *)token chatFileInfo:(ChatFileInfo *)chatFileInfo
{
	NSSet *users = [_tokenFileShares objectForKey:chatFileInfo.token];
	if ([users count] > 0){
		chatFileInfo.to = [users anyObject]; // We assume that we either have one user in set or no users at all. This may change in future.
	}
	
	NSString *recentActivityRecepientUserSessionId = nil;
	
	if ([chatFileInfo.to length] == 0) {
		recentActivityRecepientUserSessionId = [UsersManager defaultManager].currentUser.room.name;
	} else {
		recentActivityRecepientUserSessionId = chatFileInfo.to;
	}
	
	[[UsersActivityController sharedInstance] addUserActivityToHistory:chatFileInfo forUserSessionId:recentActivityRecepientUserSessionId];
	
	[[ChatManager defaultManager] sendChatFileInfoMessage:chatFileInfo to:chatFileInfo.to];
}


- (void)fileHasBeenDownloadedForToken:(NSString *)token filePath:(NSString *)filePath
{
	[[NSNotificationCenter defaultCenter] postNotificationName:FileHasBeenDownloadedNotification
														object:self
													  userInfo:@{kFilePathUserInfoKey : filePath, kFileTokenUserInfoKey : token}];
	
//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"File has been downloaded"
//													message:filePath
//												   delegate:nil
//										  cancelButtonTitle:@"Great, thanks!"
//										  otherButtonTitles:nil];
//	[alert show];
}


#pragma mark - Utilities

- (NSString *)fileLocation
{
	NSString *p2pFilesDir = [_documentsDirectory copy];
	
	BOOL isDirectory = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:p2pFilesDir isDirectory:&isDirectory]) {
		NSError *error = nil;
		BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:p2pFilesDir withIntermediateDirectories:YES attributes:nil error:&error];
		if (!succes) {
			spreed_me_log("We couldn't create directory to store p2p shared files!");
			NSAssert(NO, @"We couldn't create directory to store p2p shared files!");
		}
	}
	
	p2pFilesDir = [p2pFilesDir stringByAppendingString:@"/"];
	
	return p2pFilesDir;
}


- (NSString *)tempFileLocation
{
	NSString *tempDir = NSTemporaryDirectory();
	if (tempDir) {
		tempDir = [tempDir stringByAppendingPathComponent:@"p2p_files"];
		
		BOOL isDirectory = YES;
		if (![[NSFileManager defaultManager] fileExistsAtPath:tempDir isDirectory:&isDirectory]) {
			NSError *error = nil;
			BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error];
			if (!succes) {
				spreed_me_log("We couldn't create directory to store p2p shared files!");
				NSAssert(NO, @"We couldn't create directory to store p2p shared files!");
			}
		}
		
		tempDir = [tempDir stringByAppendingString:@"/"];
	}
	
	return tempDir;
}


- (NSString *)randomFileName
{
	static NSString *letters = @"abcdefghijklmnopqrstuvwxyz0123456789";

	int length = 8;
	
	NSMutableString *randomString = [NSMutableString stringWithCapacity:length];
	[randomString appendFormat:@"f"]; // string will always start from 'f'
	for (int i=1; i<length; i++) {
		[randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
	}
	
	return randomString;
}


- (void)stopAllTransfers
{
	std::set<std::string> sharedFileTokens = _manager->CurrentlySharedFileTokens();
	for (std::set<std::string>::iterator it = sharedFileTokens.begin(); it != sharedFileTokens.end(); it++) {
		_manager->StopSharingFileForToken(*it);
	}
	
	std::set<std::string> downloadedFileTokens = _manager->CurrentlyDownloadingFileTokens();
	for (std::set<std::string>::iterator it = downloadedFileTokens.begin(); it != downloadedFileTokens.end(); it++) {
		_manager->StopFileDownloadForToken(*it);
	}
}


- (BOOL)addSkipBackupAttributeToItemAtPath:(NSString *) filePathString
{
    NSURL* URL= [NSURL fileURLWithPath: filePathString];
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                  forKey: NSURLIsExcludedFromBackupKey error: &error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}


#pragma mark - Notifications

- (void)userHasResetApp:(NSNotification *)notification
{
	[self stopAllTransfers];
}


- (void)userHasChangedApplicationMode:(NSNotification *)notification
{
	[self stopAllTransfers];
}


#pragma mark - File download

- (void)fileDownloadProgressHasChanged:(uint64_t)bytesDownloaded forToken:(NSString *)token
{
	[[NSNotificationCenter defaultCenter] postNotificationName:FileDownloadProgressHasChangedNotification
														object:self
													  userInfo:@{kFileTokenUserInfoKey : token, kFileDownloadProgressUserInfoKey : @(bytesDownloaded)}];
}


#pragma mark - UIAlertView Delegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (alertView == _fileDownloadAlert) {
		if (buttonIndex == 1) {
			[[FileSharingManagerObjC defaultManager] startDownloadingFile:_pendingFileInfo];
		}
		_pendingFileInfo = nil;
	}
}

@end
