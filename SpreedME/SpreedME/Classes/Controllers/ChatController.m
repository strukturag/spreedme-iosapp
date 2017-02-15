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

#import "ChatController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MapKit/MapKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "ChatManager.h"
#import "FileSharingManagerObjC.h"
#import "GeolocationManager.h"
#import "MapViewController.h"
#import "SMLocalizedStrings.h"
#import "STChatCellColorController.h"
#import "UserActivityManager.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"


NSString * const ChatViewControllerDidAppearNotification		= @"ChatViewControllerDidAppearNotification";
NSString * const kChatControllerUserSessionIdKey		= @"kChatControllerUserSessionIdKey";

@implementation ChatController
{
	UserActivityManager *_userActivityManager;
	NSMutableSet *_currentlyTypingUsers;
    
    NSTimer *_userTypingTimer;
    NSTimer *_typingNotificationTimer;
    BOOL _userIsTyping;
	
	NSMutableDictionary *_fileSharingActivities;
	
	STChatCellColorController *_cellsColorController;
    
    MapViewController *_mapViewController;
}

- (id)initWithUserActivityManager:(UserActivityManager *)userActivityManager
{
	self = [super init];
	if (self) {
		_userActivityManager = userActivityManager;
		
		[_userActivityManager subscribeForUpdates:self];
		
		_currentlyTypingUsers = [[NSMutableSet alloc] init];
		
		_fileSharingActivities = [[NSMutableDictionary alloc] init];
		
		_cellsColorController = [[STChatCellColorController alloc] init];
        
        _mapViewController = [[MapViewController alloc] initWithNibName:@"MapViewController" bundle:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveTypingNotification:) name:ChatTypingNotificationReceivedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileHasBeenDownloaded:) name:FileHasBeenDownloadedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileDownloadProgressHasChanged:) name:FileDownloadProgressHasChangedNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_userActivityManager unsubscribeForUpdates:self];
}


#pragma mark - Setters/Getters

- (void)setChatViewController:(STChatViewController *)chatViewController
{
    if (_chatViewController != chatViewController) {
        _chatViewController = chatViewController;
        
        [_chatViewController setUserActivityEnabled:_userActivityManager.isUserAvailable];
    }
}


#pragma mark -

- (id<STChatMessage>)chatMessageForIndex:(NSInteger)index
{
	id<STChatMessage> message = nil;
	
	id<UserRecentActivity> activity = [_userActivityManager activityAtIndex:index];
	
	if (activity && [activity conformsToProtocol:@protocol(STChatMessage)]){
		message = (id<STChatMessage>)activity;
	} else if (activity) {
		// If there is activity but it does not conform to STChatMessage protocol
		NSAssert(NO, @"At the moment we rely on _usersAcitivityController to provide messages which conform to STChatMessage protocol");
	}
	
	return message;
}


- (void)sendConfirmationOfUserSeenActivities:(NSInteger)lastIndexSeen
{
	NSMutableArray *arrayOfMessages = [NSMutableArray array];
	
	for (NSInteger i = _userActivityManager.indexOfLastActivitySeenByUser; i <= lastIndexSeen; i++) {
		id<UserRecentActivity> activity = [_userActivityManager activityAtIndex:i];
		if (activity && [activity isKindOfClass:[ChatMessage class]]) {
			ChatMessage *message = (ChatMessage *)activity;
			if ([message.mId length] > 0 && // Check if message has mId
				![message.from isEqualToString:[UsersManager defaultManager].currentUser.sessionId] && // filter out messages from local user
                ![message.to isEqualToString:@""]) { //filter out group chat messages
				[arrayOfMessages addObject:message.mId];
			}
		}
	}
    
    _userActivityManager.indexOfLastActivitySeenByUser = lastIndexSeen;
    _userActivityManager.numberOfActivitiesSeenByUser = lastIndexSeen + 1;
	
	if ([arrayOfMessages count]) {
		[[ChatManager defaultManager] sendSeenMids:arrayOfMessages to:[self checkedRecipientId]];
	}
}


- (void)postChatViewControllerDidAppearNotification
{
	NSDictionary *userInfo =  @{kChatControllerUserSessionIdKey : _userActivityManager.userSessionId};
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ChatViewControllerDidAppearNotification object:self userInfo:userInfo];
}


- (NSString *)checkedRecipientId
{
	// Here we need to check whether this chat controllers talk with single user or with chatroom
	NSString *recepientId = _userActivityManager.userSessionId;
	if ([recepientId isEqualToString:[UsersManager defaultManager].currentUser.room.name]) {
		recepientId = @"";
	}
	return recepientId;
}


- (BOOL)isGroupChat
{
	BOOL isGroupChat = NO;
	NSString *recepientId = _userActivityManager.userSessionId;
	if ([recepientId isEqualToString:[UsersManager defaultManager].currentUser.room.name]) {
		isGroupChat = YES;
	}
	
	return isGroupChat;
}


#pragma mark - STChatViewController Datasource

- (NSInteger)numberOfMessagesInChatViewController:(STChatViewController *)chatViewController
{
	return [_userActivityManager activitiesCount];
}


- (id<STChatMessage>)chatViewController:(STChatViewController *)chatViewController chatMessageForIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	
	return message;
}


- (STChatMessageVisualType)chatViewController:(STChatViewController *)chatViewController chatMessageTypeForIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	return [message messageVisualType];
}


#pragma mark - UserActivityManagerListener

- (void)userActivityManager:(UserActivityManager *)manager didAddActivity:(id<UserRecentActivity>)activity atIndex:(NSInteger)index
{
	id<STChatMessage> message = nil;
	
	if ([activity conformsToProtocol:@protocol(STChatMessage)]){
		message = (id<STChatMessage>)activity;
	} else {
		NSAssert(NO, @"At the moment we rely on _usersAcitivityController to provide messages which conform to STChatMessage protocol");
	}
    
    [self.chatViewController addNewChatMessage:message];
	
//	if (self.chatViewController.view.window != nil) {
//		[self sendConfirmationOfUserSeenActivities];
//	}
}


- (void)userActivityManager:(UserActivityManager *)manager didUpdateActivities:(NSArray *)activities atIndices:(NSArray *)indices
{
	if ([activities count] == [indices count]) {
		for (NSUInteger i = 0; i < [activities count]; ++i) {
			
			//TODO: Remove objects querying since we need only indices
			id<UserRecentActivity> activity = [activities objectAtIndex:i];
			id<STChatMessage> message = nil;
			if ([activity conformsToProtocol:@protocol(STChatMessage)]){
				message = (id<STChatMessage>)activity;
			} else {
				NSAssert(NO, @"At the moment we rely on _usersAcitivityController to provide messages which conform to STChatMessage protocol");
			}
			
			NSInteger index = [[indices objectAtIndex:i] integerValue];
			[self.chatViewController updateChatMessageStateAtIndex:index];
		}
	} else {
		NSAssert(NO, @"activities count is not equal to activity indices count");
	}
}


- (void)userActivityManagerDidBecomeActive:(UserActivityManager *)manager
{
	[self.chatViewController setUserActivityEnabled:YES];
}


- (void)userActivityManagerDidBecomeInactive:(UserActivityManager *)manager
{
	[self.chatViewController setUserActivityEnabled:NO];
}


#pragma mark - Timers

- (void)timerTicked:(NSTimer*)timer
{
    [self invalidateTimerAndSendStopNotification];
}


- (void)invalidateTimerAndSendStopNotification
{
    [_userTypingTimer invalidate];
    _userTypingTimer = nil;
    _userIsTyping = NO;
    [[ChatManager defaultManager] sendChatTypingNotification:@"stop" to:[self checkedRecipientId]];
}


- (void)notificationTimerTicked:(NSTimer*)timer
{
    [_typingNotificationTimer invalidate];
    _typingNotificationTimer = nil;
    [_currentlyTypingUsers removeAllObjects]; //This is a workaround until we decide if we are going to show typing notifications for more than one peer.
}


#pragma mark - STChatViewController Delegate

- (void)chatViewController:(STChatViewController *)chatViewController sendTextMessage:(NSString *)text
{
	if (!_userActivityManager.isUserAvailable) {
		return;
	}
	
	[[ChatManager defaultManager] sendChatMessage:text to:[self checkedRecipientId]];
    [_userTypingTimer invalidate];
    _userTypingTimer = nil;
    _userIsTyping = NO;
}


- (void)chatViewControllerSendGeolocation:(STChatViewController *)chatViewController
{
	if (!_userActivityManager.isUserAvailable) {
		return;
	}
    [self.chatViewController showSendingCurrentLocationMessage];
    [[GeolocationManager defaultManager] getCurrentLocationWithCompletionBlock:^(CLLocation *location, NSError *error) {
        if (error) {
            NSString *errorTitle = nil;
            NSString *errorMsg = nil;
            NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
			
			
			NSString *generalErrorMsg = NSLocalizedStringWithDefaultValue(@"message_body_could-not-obtain-current-location",
																		  nil, [NSBundle mainBundle],
																		  @"It is not possible to obtain your location at the moment. Please, try again later.",
																		  @"It is not possible to obtain your location at the moment. Please, try again later.");
			NSString *generalErrorTitle = NSLocalizedStringWithDefaultValue(@"message_title_could-not-obtain-current-location",
																			nil, [NSBundle mainBundle],
																			@"Could not obtain current location",
																			@"Could not obtain current location");
			
            if ([[error domain] isEqualToString:kCLErrorDomain]) {
                
                switch ([error code]) {
                    
                    case kCLErrorDenied:
					{
						NSString *locFormatStrBody = NSLocalizedStringWithDefaultValue(@"message_body-arg4_location-services-disabled_ios",
																				   nil, [NSBundle mainBundle],
																				   @"If you want to share your location, please go to device %@ -> %@ and enable %@ for %@.",
																				   @"If you want to share your location, please go to device 'Settings' -> 'Privacy' and enable 'Location services' for 'appname'. You can move around '%@' but make sure you have 4 of them.");
						
						errorMsg = [NSString stringWithFormat:locFormatStrBody,
									kSMLocalStringiOSSettingsSettingsLabel,
									kSMLocalStringiOSSettingsPrivacyLabel,
									kSMLocalStringiOSSettingsLocationServicesLabel,
									appName];
						
						NSString *locFormatStrTitle = NSLocalizedStringWithDefaultValue(@"message_title-arg2_location-services-disabled",
																						nil, [NSBundle mainBundle],
																						@"%@ are not enabled for %@",
																						@"'Location services' are not enabled for 'appname'. You can move around '%@' but make sure you have 2 of them.");
						
                        errorTitle = [NSString stringWithFormat:locFormatStrTitle, kSMLocalStringiOSSettingsLocationServicesLabel, appName];
					}
                    break;
                    
                    case kCLErrorLocationUnknown:
                    default:
                    
						errorMsg = generalErrorMsg;
                        errorTitle = generalErrorTitle;
                    
                    break;
                    
                }
                
            } else {
                
				errorMsg = generalErrorMsg;
				errorTitle = generalErrorTitle;
				
            }
			
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:errorTitle
															message:errorMsg
														   delegate:nil
												  cancelButtonTitle:kSMLocalStringSadOKButton
												  otherButtonTitles:nil];
            [alert show];
        } else {
            [[ChatManager defaultManager] sendChatGeolocationMessage:[self createGeolocationMessageFromCLLocation:location] to:[self checkedRecipientId]];
        }
        [self.chatViewController hideSendingCurrentLocationMessage];
    }];
}


- (void)clearMessagesInChatViewController:(STChatViewController *)chatViewController
{
    [_userActivityManager purgeAllHistory];
}


- (void)chatViewController:(STChatViewController *)chatViewController sendTypingNotification:(NSString *)type
{
	if (![self isGroupChat]) {
		if ([type isEqualToString:@"start"]) {
			if (!_userTypingTimer) {
				[[ChatManager defaultManager] sendChatTypingNotification:@"start" to:[self checkedRecipientId]];
				_userTypingTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(timerTicked:) userInfo:nil repeats:YES];
				_userIsTyping = YES;
			}
			if (_userIsTyping) {
				[_userTypingTimer invalidate];
				_userTypingTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(timerTicked:) userInfo:nil repeats:YES];
			}
		} else {
			[self invalidateTimerAndSendStopNotification];
		}
	}
}


- (void)chatViewControllerDidAppear:(STChatViewController *)chatViewController
{
//	[self sendConfirmationOfUserSeenActivities];
	[self postChatViewControllerDidAppearNotification];
}


- (void)sendMessageReadNotification:(STChatViewController *)chatViewController untilIndex:(NSInteger)index
{
    [self sendConfirmationOfUserSeenActivities:index];
}


- (void)chatViewController:(STChatViewController *)chatViewController startDownloadFileButtonPressedAtIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	if (message) {
		if ([message isKindOfClass:[ChatFileInfo class]]) {
			ChatFileInfo *fileInfo = (ChatFileInfo *)message;
			
			ChatFileInfo *checkFileInfo = [[FileSharingManagerObjC defaultManager] fileInfoForToken:fileInfo.token];
			if (!checkFileInfo) {

				[_fileSharingActivities setObject:@(index) forKey:fileInfo.token];
				[[FileSharingManagerObjC defaultManager] startDownloadingFile:fileInfo];
				fileInfo.hasTransferStarted = YES;
				[self.chatViewController updateChatMessageStateAtIndex:index];
			}
		}
	}
}


- (void)chatViewController:(STChatViewController *)chatViewController pauseDownloadFileButtonPressedAtIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	if (message) {
		if ([message conformsToProtocol:@protocol(STFileTransferChatMesage)]) {
			if ([message isKindOfClass:[ChatFileInfo class]]) {
				ChatFileInfo *chatFileInfo = (ChatFileInfo *)message;
				
				[[FileSharingManagerObjC defaultManager] pauseFileDownloadForToken:chatFileInfo.token];
				[self.chatViewController updateChatMessageStateAtIndex:index];
			}
		}
	}
}


- (void)chatViewController:(STChatViewController *)chatViewController cancelTransferFileButtonPressedAtIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	if (message) {
		if ([message conformsToProtocol:@protocol(STFileTransferChatMesage)]) {
			if ([message isKindOfClass:[ChatFileInfo class]]) {
				ChatFileInfo *chatFileInfo = (ChatFileInfo *)message;
				
				if (chatFileInfo.fileTransferType == kSTChatFileTransferTypeUpload) {
					chatFileInfo.isCanceled = YES;
					[[FileSharingManagerObjC defaultManager] stopSharingFileForToken:chatFileInfo.token];
					[self.chatViewController updateChatMessageStateAtIndex:index];
				} else if (chatFileInfo.fileTransferType == kSTChatFileTransferTypeDownload) {
					[[FileSharingManagerObjC defaultManager] stopFileDownloadForToken:chatFileInfo.token];
					chatFileInfo.downloadedBytes = 0;
					chatFileInfo.sharingSpeed = 0;
					chatFileInfo.hasTransferStarted = NO;
					[self.chatViewController updateChatMessageStateAtIndex:index];
				}
			}
		}
	}
}


- (void)chatViewController:(STChatViewController *)chatViewController openDownloadedFileButtonPressedAtIndex:(NSInteger)index
{
	id<STChatMessage> message = [self chatMessageForIndex:index];
	if (message) {
		if ([message conformsToProtocol:@protocol(STFileTransferChatMesage)]) {
			if ([message isKindOfClass:[ChatFileInfo class]]) {
				ChatFileInfo *chatFileInfo = (ChatFileInfo *)message;
				
				if (chatFileInfo.fileTransferType == kSTChatFileTransferTypeDownload &&
					chatFileInfo.fileSize == chatFileInfo.downloadedBytes) {
					
					[[UserInterfaceManager sharedInstance] tryToGoToFileWithName:chatFileInfo.fileName];
				}
			}
		}
	}
}


- (void)chatViewController:(STChatViewController *)chatViewController showLocationButtonPressedAtIndex:(NSInteger)index
{
    id<STChatMessage> message = [self chatMessageForIndex:index];
	if (message) {
		if ([message conformsToProtocol:@protocol(STGeolocationChatMessage)]) {
			if ([message isKindOfClass:[ChatGeolocation class]]) {
				ChatGeolocation *chatGeolocation = (ChatGeolocation *)message;
                
                CLLocation *location = [self createCLLocationFromGeolocationMessage:chatGeolocation];
                MKPlacemark *placeMark = [[MKPlacemark alloc] initWithCoordinate:location.coordinate addressDictionary:nil];
                MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placeMark];
                
                if ([chatGeolocation isSentByLocalUser]) {
                    mapItem.name = kSMLocalStringMeLabel;
                } else {
                    mapItem.name = chatGeolocation.userName;
                }
                
                _mapViewController.boundingRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 500, 500);
                _mapViewController.mapItemList = [NSArray arrayWithObject:mapItem];
                [self.chatViewController.navigationController pushViewController:_mapViewController animated:YES];
			}
		}
	}
}


- (UIColor *)chatViewController:(STChatViewController *)chatViewController colorForCellAtIndex:(NSInteger)index
{
	UIColor *color = nil;
	
	id<STChatMessage> message = [self chatMessageForIndex:index];
	
	if ([message respondsToSelector:@selector(userUniqueId)]) {
		NSString *userUniqueId = [message userUniqueId];
		if ([userUniqueId length] > 0) {
			color = [_cellsColorController colorForId:userUniqueId];
		}
	}
	
	return color;
}


- (void)chatViewController:(STChatViewController *)chatViewController wantsToShareMediaWithInfo:(NSDictionary *)info
{
	[self tempFileForAssetFromMediaInfo:info completionBlock:^(NSString *filePath) {
        NSString* fileName = [filePath lastPathComponent];
        [self startSharingFileAtPath:filePath withFileName:fileName];
		spreed_me_log("Created temp file %s for upload %s", [filePath cDescription], [info cDescription]);
	} failureBlock:^(NSError *error) {
		spreed_me_log("Failed to create temp file for upload: %s", [error cDescription]);
	}];
}


- (void)chatViewController:(STChatViewController *)chatViewController wantsToShareFileAtPath:(NSString *)filePath
{
    NSString *tempFile = [self tempFilePathFromFilePath:filePath];
    NSString* fileName = [filePath lastPathComponent];
    
    if (tempFile) {
        [self startSharingFileAtPath:tempFile withFileName:fileName];
    }
}


- (NSInteger)indexOfLastActivitySeenByUserInChatViewController:(STChatViewController *)chatViewController
{
    return [_userActivityManager indexOfLastActivitySeenByUser];
}


- (void)startSharingFileAtPath:(NSString *)filePath  withFileName:(NSString*)fileName
{
    CFStringRef fileExtension = (__bridge CFStringRef)[filePath pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    NSString *MIMETypeString = (__bridge_transfer NSString *)MIMEType;
    
    NSSet *users = nil;
    
    if (![_userActivityManager.userSessionId isEqualToString:[UsersManager defaultManager].currentUser.room.name]) {
        users = [NSSet setWithObject:_userActivityManager.userSessionId];
    }
    
    [[FileSharingManagerObjC defaultManager] startSharingFileAtPath:filePath fileName:fileName fileType:MIMETypeString fileIsTemporary:YES forUsers:users];
}


#pragma mark - TypingNotifications Notifications

- (void)didReceiveTypingNotification:(NSNotification *)notification
{
	ChatTypingNotification *chatMessage = [notification.userInfo objectForKey:kMessageUserInfoKey];
	
	BOOL isTypingNotificationForUs = NO;
	BOOL isThisRoomChat = [[UsersManager defaultManager].currentUser.room.name isEqualToString:_userActivityManager.userSessionId];
	if (isThisRoomChat) {
		isTypingNotificationForUs = ([chatMessage.to length] == 0);
	} else {
		isTypingNotificationForUs = [chatMessage.from isEqualToString:_userActivityManager.userSessionId];
	}
	
    if (isTypingNotificationForUs) {
	
		switch (chatMessage.typingNotifType) {
			case kStartedTyping:
				[_currentlyTypingUsers addObject:chatMessage.from];
                if ([_typingNotificationTimer isValid]) {
                    [_typingNotificationTimer invalidate];
                }
				break;
				
			case kFinishedTyping:
				[_currentlyTypingUsers removeObject:chatMessage.from];
                _typingNotificationTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(notificationTimerTicked:) userInfo:nil repeats:YES];
				break;
			default:
				break;
		}
		
		if (self.chatViewController && self.chatViewController.isViewLoaded && self.chatViewController.view.window) {
			if ([_currentlyTypingUsers count] > 0) {
				NSMutableArray *userNames = [NSMutableArray array];
				for (NSString *sessionId in _currentlyTypingUsers) {
					User *buddy = [[UsersManager defaultManager] userForSessionId:sessionId];
					if (buddy) {
						[userNames addObject:buddy.displayName];
					} else {
						spreed_me_log("No buddy for session id %s in didReceiveTypingNotification:", sessionId);
					}
				}
				if ([userNames count] > 0) {
					[self.chatViewController showTypingNotificationFromUserNames:userNames];
				}
				
			} else {
				[self.chatViewController hideTypingNotificationWhenNewMessageReceived:NO];
			}
		}
	}
}


#pragma mark - File Sharing notifications

- (void)fileHasBeenDownloaded:(NSNotification *)notification
{
	NSString *fileToken = [notification.userInfo objectForKey:kFileTokenUserInfoKey];
	
	NSInteger index = [[_fileSharingActivities objectForKey:fileToken] integerValue];
	if (index > -1) {
		id<STChatMessage> message = [self chatMessageForIndex:index];
		if (message) {
			if ([message isKindOfClass:[ChatFileInfo class]]) {
				ChatFileInfo *fileInfo = (ChatFileInfo *)message;

				if (fileInfo.downloadedBytes != fileInfo.fileSize) {
					spreed_me_log("File has been downloaded but downloadedBytes!=fileSize. This is weird. Set downloadBytes=fileSize manually");
					fileInfo.downloadedBytes = fileInfo.fileSize;
				}
				fileInfo.isCanceled = YES; // set isCanceled YES to reliably signal that file was downloaded. 
				
				[self.chatViewController updateChatMessageStateAtIndex:index];
				[_fileSharingActivities removeObjectForKey:fileToken];
			}
		}
	}
}


- (void)fileDownloadProgressHasChanged:(NSNotification *)notification
{
	NSString *fileToken = [notification.userInfo objectForKey:kFileTokenUserInfoKey];
	uint64_t downloadProgress = [[notification.userInfo objectForKey:kFileDownloadProgressUserInfoKey] unsignedLongLongValue];
	
	NSInteger index = [[_fileSharingActivities objectForKey:fileToken] integerValue];
	if (index > -1) {
		id<STChatMessage> message = [self chatMessageForIndex:index];
		if (message) {
			if ([message isKindOfClass:[ChatFileInfo class]]) {
				ChatFileInfo *fileInfo = (ChatFileInfo *)message;
				fileInfo.downloadedBytes = downloadProgress;
				
				[self.chatViewController updateChatMessageStateAtIndex:index];
			}
		}
	}
}


#pragma mark - FileSharing

- (void)tempFileForAssetFromMediaInfo:(NSDictionary *)info completionBlock:(void (^)(NSString *filePath))complBlock failureBlock:(void (^)(NSError *error))failureBlock
{
	NSURL *assetUrl = [info objectForKey:UIImagePickerControllerReferenceURL];
	
	NSString *surl = [assetUrl absoluteString];
    NSString *ext = [surl substringFromIndex:[surl rangeOfString:@"ext="].location + 4];
    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
    NSString *filename = [NSString stringWithFormat: @"%f.%@",ti,ext];
    NSString *tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
	
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation * rep = [myasset defaultRepresentation];
		
        NSUInteger size = [rep size];
        const int bufferSize = 8192;
		
        spreed_me_log("Writing to %s", [tmpfile cDescription]);
		NSOutputStream *fileStream = [NSOutputStream outputStreamToFileAtPath:tmpfile append:YES];
		[fileStream open];
		
        uint8_t *buffer = (uint8_t *)malloc(bufferSize);
        int read = 0, offset = 0, written = 0;
        NSError* err;
        if (size != 0) {
            do {
                read = [rep getBytes:buffer
                          fromOffset:offset
                              length:bufferSize
                               error:&err];
				written = [fileStream write:buffer maxLength:read];
                offset += read;
            } while (read != 0);
        }
		[fileStream close];
		free(buffer);
		
		if (complBlock){
			complBlock(tmpfile);
		}
    };
	
	
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *error)
    {
        spreed_me_log("Can not get asset - %s",[[error localizedDescription] cDescription]);
		if (failureBlock) {
			failureBlock(error);
		}
    };
	
    if(assetUrl)
    {
        ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
        [assetslibrary assetForURL:assetUrl
                       resultBlock:resultblock
                      failureBlock:failureblock];
    }
}


- (NSString *)tempFilePathFromFilePath:(NSString *)filePath
{
    NSError *error;
    NSString* fileName = [filePath lastPathComponent];
    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
    NSString *tempFileName = [NSString stringWithFormat: @"%f.%@",ti,fileName];
    NSString *tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    
    if ([[NSFileManager defaultManager] copyItemAtPath:filePath toPath:tmpFilePath error:&error]) {
        spreed_me_log("Copy %s to temp folder correctly", [fileName cDescription]);
    } else {
        spreed_me_log("Failed copying %s to temp. %s", [fileName cDescription], [error.localizedDescription cDescription]);
        return nil;
    }
    return tmpFilePath;
}


#pragma mark - Geolocation

- (ChatGeolocation *)createGeolocationMessageFromCLLocation:(CLLocation *)location
{
    ChatGeolocation *geolocationMessage = (ChatGeolocation *)[ChatManager chatMessageWithType:kChatMessageTypeGeolocation
                                                                                           to:[self checkedRecipientId]
                                                                                         from:[UsersManager defaultManager].currentUser.sessionId
                                                                                          mId:[ChatManager generateNewMId]
                                                                                         date:[NSDate date]
                                                                                   dateString:nil
                                                                                      message:kSMLocalStringGeolocationLabel];
    geolocationMessage.accuracy = location.horizontalAccuracy;
    geolocationMessage.latitude = location.coordinate.latitude;
    geolocationMessage.longitude = location.coordinate.longitude;
    geolocationMessage.altitude = location.altitude;
    geolocationMessage.altitudeAccuracy = location.verticalAccuracy;
    
    return geolocationMessage;
}


- (CLLocation *)createCLLocationFromGeolocationMessage:(ChatGeolocation *)geolocation
{
    CLLocationCoordinate2D locationCoordinates = CLLocationCoordinate2DMake(geolocation.latitude, geolocation.longitude);
    CLLocation *location = [[CLLocation alloc] initWithCoordinate:locationCoordinates altitude:geolocation.altitude horizontalAccuracy:geolocation.accuracy verticalAccuracy:geolocation.altitudeAccuracy timestamp:nil];
    
    return location;
}


@end
