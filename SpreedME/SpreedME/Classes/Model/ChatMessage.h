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

#import "UsersActivityController.h"
#import "STChatViewController.h"

typedef enum ChatMessageType
{
	kChatMessageTypeUndefined = 0,
	kChatMessageTypeTyping,
	kChatMessageTypeMessage,
	kChatMessageTypeFileInfo,
    kChatMessageTypeGeolocation
}
ChatMessageType;


typedef enum TypingNotificationType
{
	kStartedTyping = 0,
	kFinishedTyping
}
TypingNotificationType;


typedef enum ChatMessageDeliveryStatus
{
	kChatMessageDeliveryStatusRemoteMessage = -1,
	kChatMessageDeliveryStatusSent = 0,
	kChatMessageDeliveryStatusRemoteReceived,
	kChatMessageDeliveryStatusRemoteSeen,
    kChatMessageDeliveryStatusGroupChat
}
ChatMessageDeliveryStatus;


@interface ChatMessage : NSObject <NSCopying, UserRecentActivity, STChatMessage>
{
	NSString *_message;
	NSString *_from;
	NSString *_to;
	NSDate *_date;
	NSString *_dateString;
	NSString *_mId;
	ChatMessageType _type;
	
	BOOL _isStartOfGroup;
	BOOL _isEndOfGroup;
}

@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) NSString *from;
@property (nonatomic, copy) NSString *to;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic, copy) NSString *dateString;
@property (nonatomic, copy) NSString *mId;
@property (nonatomic, assign) ChatMessageType type;
@property (nonatomic, assign) ChatMessageDeliveryStatus deliveryStatus;

@property (nonatomic, assign) BOOL isStartOfGroup;
@property (nonatomic, assign) BOOL isEndOfGroup;

@property (nonatomic, copy) NSString *userName;

@end


@interface ChatTypingNotification : ChatMessage

@property (nonatomic, assign) TypingNotificationType typingNotifType;

@end


@interface ChatFileInfo : ChatMessage <STFileTransferChatMesage>

@property (nonatomic, assign) unsigned int chunks;
@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, assign) uint64_t fileSize;
@property (nonatomic, copy) NSString *fileType;

@property (nonatomic, assign) uint64_t downloadedBytes;
@property (nonatomic, assign) uint64_t sharingSpeed;

@property (nonatomic, assign) STChatFileTransferType fileTransferType;

@property (nonatomic, assign) BOOL hasTransferStarted;
@property (nonatomic, assign) BOOL isCanceled;

@end


@interface ChatGeolocation : ChatMessage <STGeolocationChatMessage>

@property (nonatomic, assign) CGFloat accuracy;
@property (nonatomic, assign) CGFloat latitude;
@property (nonatomic, assign) CGFloat longitude;
@property (nonatomic, assign) CGFloat altitude;
@property (nonatomic, assign) CGFloat altitudeAccuracy;

@end