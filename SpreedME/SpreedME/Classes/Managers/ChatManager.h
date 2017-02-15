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

#import "ChannelingConstants.h"
#import "ChatMessage.h"


extern NSString * const ChatMessageReceivedNotification;
extern NSString * const ChatTypingNotificationReceivedNotification;
extern NSString * const ChatFileInfoMessageReceivedNotification;
extern NSString * const ChatMessageDeliveryStatusNotification;

extern NSString * const kMessageUserInfoKey;
extern NSString * const kDeliveryStatusSeenIdsKey;
extern NSString * const kDeliveryStatusDeliveredMidKey;

@interface ChatManager : NSObject


+ (instancetype)defaultManager;

- (void)sendChatMessage:(NSString *)message to:(NSString *)recepientId;
- (void)sendChatTypingNotification:(NSString *)message to:(NSString *)recepientId;
- (void)sendChatFileInfoMessage:(ChatFileInfo *)chatFileInfo to:(NSString *)recepientId;
- (void)sendChatGeolocationMessage:(ChatGeolocation *)chatGeolocation to:(NSString *)recepientId;
- (void)sendSeenMids:(NSArray *)mIds to:(NSString *)recepientId;

- (void)receivedChatMessage:(NSDictionary *)message transportType:(ChannelingMessageTransportType)transportType;

- (NSDictionary *)jsonDictionaryWithChatMessage:(ChatMessage *)message messageType:(ChatMessageType)type;

+ (ChatMessage *)chatMessageWithType:(ChatMessageType)type
								  to:(NSString *)to
								from:(NSString *)from
								 mId:(NSString *)mId
								date:(NSDate *)date
						  dateString:(NSString *)dateString
							 message:(NSString *)message;

+ (NSString *)generateNewMId;


@end
