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

#import <UIKit/UIKit.h>

@class STChatViewController;

typedef enum STChatMessageVisualType {
	kSTChatMessageVisualTypeUnspecified = 0,
	kSTChatMessageVisualTypeServiceMessage,
	kSTChatMessageVisualTypeText,
	kSTChatMessageVisualTypeImage,
	kSTChatMessageVisualTypeFileDownload,
    kSTChatMessageVisualTypeGeolocation,
} STChatMessageVisualType;

typedef enum STChatServiceMessageType {
	kSTChatServiceMessageTypeUnspecified = 0,
	kSTChatServiceMessageTypeMissedCall,
	kSTChatServiceMessageTypeReceivedCall,
}
STChatServiceMessageType;

typedef enum : NSUInteger {
    kSTChatFileTransferTypeUnspecified = 0, // this is error
	
	kSTChatFileTransferTypeUpload, // Upload only. Can be to one or multiple peers
    kSTChatFileTransferTypeDownload, // Download only. Can be from one or multiple peers

	kSTChatFileTransferTypePeerToPeerSharing, // peer to peer sharing. Not implemented yet
	
} STChatFileTransferType;


@protocol STChatMessage <NSObject>
@required
- (STChatMessageVisualType)messageVisualType;
- (NSDate *)date;
- (NSString *)userName;
- (BOOL)isSentByLocalUser; // YES if sent by local user, NO if sent to local user by some other remote user
- (BOOL)isStartOfGroup;
- (BOOL)isEndOfGroup;
@optional
- (UIImage *)localUserAvatar;
- (UIImage *)remoteUserAvatar;
- (UIImage *)deliveryStatusIcon;
- (NSMutableAttributedString *)deliveryStatusText;
- (NSString *)userUniqueId;
- (BOOL)hasBeenDelivered;
- (BOOL)hasBeenRead;
@end

@protocol STServiceChatMessage <STChatMessage>
@required
- (STChatServiceMessageType)serviceMessageType;
@optional

// Missed call
- (NSString *)missedCallFrom;
- (NSDate *)missedCallWhen;
- (NSAttributedString *)attributedTextForMissedCallFrom:(NSString *)from;
- (NSAttributedString *)attributedTextForMissedCallDate:(NSDate *)date;

// Received call
- (NSString *)callWith;
- (NSDate *)callWhen;
- (NSTimeInterval)callDuration;

@end

@protocol STTextChatMessage <STChatMessage>
@required
- (NSString *)message;
@end

@protocol STImageChatMessage <STTextChatMessage>
@required
- (UIImage *)chatMessageImage;
@end

@protocol STFileTransferChatMesage <STTextChatMessage>
@required
- (NSString *)fileName; // example: "filename.txt"
- (uint64_t)fileSize; // in bytes
- (uint64_t)downloadedBytes; // in bytes
- (uint64_t)sharingSpeed; // in bytes per second, can be used as activity indicator
- (STChatFileTransferType)fileTransferType;

/* 
 Sharing has started. This is more user intention than a actual file transfer.
 It can be that user pressed start download button, but file cannot be downloaded.
 */
- (BOOL)hasTransferStarted;

/*
 File transfer has been canceled/finished. It means it cannot be recovered/restarted anymore.
 FileTransferMessage should return YES on isCanceled in such cases:
 1. When file has been downloaded.
 2. When file download has been canceled by remote user, meaning no remote peer doen't share file anymore.
 3. When file upload has been canceled by local user.
 */
- (BOOL)isCanceled;

@end

@protocol STGeolocationChatMessage <STChatMessage>
@required
- (CGFloat)accuracy;
- (CGFloat)latitude;
- (CGFloat)longitude;
- (CGFloat)altitude;
- (CGFloat)altitudeAccuracy;
@end


@protocol STChatViewControllerDataSource <NSObject>
@required
- (NSInteger)numberOfMessagesInChatViewController:(STChatViewController *)chatViewController;
- (id<STChatMessage>)chatViewController:(STChatViewController *)chatViewController chatMessageForIndex:(NSInteger)index;
- (STChatMessageVisualType)chatViewController:(STChatViewController *)chatViewController chatMessageTypeForIndex:(NSInteger)index;


@end


@protocol STChatViewControllerDelegate <NSObject>
@required
- (void)chatViewController:(STChatViewController *)chatViewController sendTextMessage:(NSString *)text;
- (void)chatViewController:(STChatViewController *)chatViewController sendTypingNotification:(NSString *)type;
- (void)chatViewController:(STChatViewController *)chatViewController wantsToShareMediaWithInfo:(NSDictionary *)info;
- (void)chatViewController:(STChatViewController *)chatViewController wantsToShareFileAtPath:(NSString *)filePath;
- (void)clearMessagesInChatViewController:(STChatViewController *)chatViewController;

@optional
- (void)chatViewControllerDidAppear:(STChatViewController *)chatViewController;
- (NSInteger)indexOfLastActivitySeenByUserInChatViewController:(STChatViewController *)chatViewController;
- (void)sendMessageReadNotification:(STChatViewController *)chatViewController untilIndex:(NSInteger)index;

- (void)chatViewControllerSendGeolocation:(STChatViewController *)chatViewController;

- (void)chatViewController:(STChatViewController *)chatViewController startDownloadFileButtonPressedAtIndex:(NSInteger)index;
- (void)chatViewController:(STChatViewController *)chatViewController pauseDownloadFileButtonPressedAtIndex:(NSInteger)index;
- (void)chatViewController:(STChatViewController *)chatViewController cancelTransferFileButtonPressedAtIndex:(NSInteger)index;
- (void)chatViewController:(STChatViewController *)chatViewController openDownloadedFileButtonPressedAtIndex:(NSInteger)index;

- (void)chatViewController:(STChatViewController *)chatViewController showLocationButtonPressedAtIndex:(NSInteger)index;

- (UIColor *)chatViewController:(STChatViewController *)chatViewController colorForCellAtIndex:(NSInteger)index;

@end


@interface STChatViewController : UIViewController

- (void)addNewChatMessage:(id<STChatMessage>)message;
- (void)removeChatMessage:(id<STChatMessage>)message atIndex:(NSUInteger)index;
- (void)updateChatMessageStateAtIndex:(NSUInteger)index;

- (void)showTypingNotificationFromUserNames:(NSArray *)userNames;
- (void)hideTypingNotificationWhenNewMessageReceived:(BOOL)yesNo;

- (void)showSendingCurrentLocationMessage;
- (void)hideSendingCurrentLocationMessage;

- (void)setUserActivityEnabled:(BOOL)yesNo;

- (void)presentChatInputViewKeyBoard;
- (void)shareUserCurrentLocation;
- (void)shareUserSelectedFileWithInfo:(NSDictionary *)info;
- (void)shareUserSelectedFileAtPath:(NSString *)path;

@property (nonatomic, weak) id<STChatViewControllerDataSource> datasource;
@property (nonatomic, weak) id<STChatViewControllerDelegate> delegate;

/* 
 This is optional possibility to give chatViewController an object which will be in charge of chatViewController.
 You can always init STChatViewController wtihout 'chatController' and use 'datasource' and 'delegate' properties.
 NOTE: setting this property will change 'datasource' and 'delegate' to use given object.
*/
@property (nonatomic, strong) id<STChatViewControllerDataSource, STChatViewControllerDelegate> chatController;

@property (nonatomic, copy) NSString *chatName;
@property (nonatomic, assign) BOOL wasSeen;

@end
