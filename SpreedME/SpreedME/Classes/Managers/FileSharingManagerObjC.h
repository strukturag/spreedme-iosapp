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

#import <Foundation/Foundation.h>

@class ChatFileInfo;

extern NSString * const FileHasBeenDownloadedNotification;
extern NSString * const FileDownloadProgressHasChangedNotification;

extern NSString * const kFilePathUserInfoKey;
extern NSString * const kFileTokenUserInfoKey;
extern NSString * const kFileDownloadProgressUserInfoKey;


@interface FileSharingManagerObjC : NSObject

/*
 FileSharingManagerObjC has internal dependancies on PeerConnectionController and ChannelingManager.
 Thus we MUST always create default file sharing manager only after PeerConnectionController and ChannelingManager. 
 Otherwise behaviour of FileSharingManagerObjC is undefined.
 */
+ (instancetype)defaultManager;

- (void)startDownloadingFile:(ChatFileInfo *)fileInfo;
- (void)pauseFileDownloadForToken:(NSString *)token;
- (void)resumeFileDownloadForToken:(NSString *)token;
- (void)stopFileDownloadForToken:(NSString *)token;

// fileType is MIME type.
- (void)startSharingFileAtPath:(NSString *)filePath fileName:(NSString *)fileName fileType:(NSString *)fileType fileIsTemporary:(BOOL)isTemporary forUsers:(NSSet *)users;
- (void)stopSharingFileForToken:(NSString *)token;

- (NSSet *)currentlyDownloadingFileTokens;
- (NSSet *)currentlySharedFileTokens;

- (ChatFileInfo *)fileInfoForToken:(NSString *)token;

// Delegate methods for c++ FileSharingManager 
- (void)fileHasBeenDownloadedForToken:(NSString *)token filePath:(NSString *)filePath;
- (void)fileSharingHasStartedForToken:(NSString *)token chatFileInfo:(ChatFileInfo *)chatFileInfo;

- (void)fileDownloadProgressHasChanged:(uint64_t)bytesDownloaded forToken:(NSString *)token;

- (NSString *)fileLocation;

@end
