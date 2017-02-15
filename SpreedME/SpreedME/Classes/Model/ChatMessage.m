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

#import "ChatMessage.h"

#import "UsersManager.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"

#pragma mark - ChatMessage

@implementation ChatMessage

- (id)init
{
	self = [super init];
	if (self) {
		_type = kChatMessageTypeMessage;
	}
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ChatMessage *newMessage = [[[self class] alloc] init];
	
	newMessage.message = self.message;
	newMessage.from = self.from;
	newMessage.to = self.to;
	newMessage.date = self.date;
	newMessage.dateString = self.dateString;
	newMessage.type = self.type;

	newMessage.deliveryStatus = self.deliveryStatus;
	
	newMessage.isStartOfGroup = self.isStartOfGroup;
	newMessage.isEndOfGroup = self.isEndOfGroup;
	
	newMessage.userName = self.userName;
	
	return newMessage;
}

#pragma mark - UserRecentActivity protocol implementation

// all these methods are already implemented as properties
//- (NSDate *)date;
//- (NSString *)to;
//- (NSString *)from;



#pragma mark - STChatMessage protocol implementation

//- (NSDate *)date; - (BOOL)isStartOfGroup; - (BOOL)isEndOfGroup; - (NSString *)userName; are implemented already as properties


- (STChatMessageVisualType)messageVisualType
{
	return kSTChatMessageVisualTypeText;
}


- (BOOL)isSentByLocalUser
{
	return [self.from isEqualToString:[UsersManager defaultManager].currentUser.sessionId];
}


- (UIImage *)localUserAvatar
{
	return [UsersManager defaultManager].currentUser.iconImage;
}


- (UIImage *)remoteUserAvatar
{
	UIImage *avatar = nil;
	if (!self.isSentByLocalUser) {
		User *buddy = [[UsersManager defaultManager] userForSessionId:self.from];
		avatar = buddy.iconImage;
	} else {
		User *buddy = [[UsersManager defaultManager] userForSessionId:self.to];
		avatar = buddy.iconImage;
	}
	
	return avatar;
}

/* Uncomment this method if you want to use images for delivery status */

//- (UIImage *)deliveryStatusIcon
//{
//	UIImage *deliveryStatusImage = nil;
//	
//	switch (_deliveryStatus) {
//		case kChatMessageDeliveryStatusRemoteMessage:
//			deliveryStatusImage = [UIImage imageNamed:@"chat_message_seen"];
//		break;
//			
//		case kChatMessageDeliveryStatusSent:
//			deliveryStatusImage = [UIImage imageNamed:@"chat_message_sent"];
//		break;
//			
//		case kChatMessageDeliveryStatusRemoteReceived:
//			deliveryStatusImage = [UIImage imageNamed:@"chat_message_received"];
//		break;
//			
//		case kChatMessageDeliveryStatusRemoteSeen:
//			deliveryStatusImage = [UIImage imageNamed:@"chat_message_seen"];
//		break;
//		
//		default:
//		break;
//	}
//	
//	return deliveryStatusImage;
//}


- (NSMutableAttributedString *)deliveryStatusText
{
    NSString *iconName = nil;
    UIColor *iconColor = nil;
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:12];
	
	switch (_deliveryStatus) {
		case kChatMessageDeliveryStatusRemoteMessage:
			iconName = [NSString fontAwesomeIconStringForEnum:FACheck];
            iconColor = kSMChatMessageRemoteStatusColor;
            break;
			
		case kChatMessageDeliveryStatusSent:
			iconName = [NSString fontAwesomeIconStringForEnum:FAEnvelopeO];
            iconColor = kSMChatMessageSentStatusColor;
            break;
			
		case kChatMessageDeliveryStatusRemoteReceived:
			iconName = [NSString fontAwesomeIconStringForEnum:FADownload];
            iconColor = kSMChatMessageDeliveredStatusColor;
            break;
			
		case kChatMessageDeliveryStatusRemoteSeen:
			iconName = [NSString fontAwesomeIconStringForEnum:FAEye];
            iconColor = kSMChatMessageSeenStatusColor;
            break;
        
        case kChatMessageDeliveryStatusGroupChat:
            iconName = [NSString fontAwesomeIconStringForEnum:FAComment];
            iconColor = kSMChatMessageGroupStatusColor;
            break;
            
		default:
            break;
	}
    
    NSString *icon = [NSString stringWithFormat:@"%@", iconName];
    NSMutableAttributedString *deliveryStatusImage = [[NSMutableAttributedString alloc] initWithString:icon];
    [deliveryStatusImage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
    [deliveryStatusImage addAttribute:NSForegroundColorAttributeName value:iconColor range:NSMakeRange(0,1)];
	
	return deliveryStatusImage;
}


- (NSString *)userUniqueId
{
	return self.from;
}


@end


#pragma mark - ChatTypingNotification


@implementation ChatTypingNotification

- (id)init
{
	self = [super init];
	if (self) {
		_type = kChatMessageTypeTyping;
	}
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	ChatTypingNotification *newMessage = [[[self class] alloc] init];
	
	newMessage.typingNotifType = self.typingNotifType;
	
	return newMessage;
}


@end


#pragma mark - ChatFileInfo

@implementation ChatGeolocation

- (id)init
{
	self = [super init];
	if (self) {
		_type = kChatMessageTypeGeolocation;
	}
	return self;
}


- (STChatMessageVisualType)messageVisualType
{
	return kSTChatMessageVisualTypeGeolocation;
}

@end


#pragma mark - ChatFileInfo

@implementation ChatFileInfo

- (id)init
{
	self = [super init];
	if (self) {
		_type = kChatMessageTypeFileInfo;
	}
	return self;
}


- (STChatMessageVisualType)messageVisualType
{
	return kSTChatMessageVisualTypeFileDownload;
}


#pragma mark - STFileTransferChatMesage protocol

// These protocol methods are implemented as a part of the class by properties or in superclass
//- (NSString *)fileName; already implemented
//- (uint64_t)fileSize; already implemented
//- (uint64_t)downloadedBytes; already implemented
//- (uint64_t)sharingSpeed; already implemented
//- (STChatFileTransferType)fileTransferType; already implemented
//- (BOOL)hasTransferStarted; already implemented
//- (BOOL)isCanceled; already implemented


@end
