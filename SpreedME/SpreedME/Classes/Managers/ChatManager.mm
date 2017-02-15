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

#import "ChatManager.h"

#include <webrtc/base/helpers.h>

#import "JSONKit.h"

#import "DateFormatterManager.h"
#import "SMConnectionController.h"
#import "SMLocalizedStrings.h"
#import "STLocalNotificationManager.h"
#import "UsersManager.h"



//Notifications
NSString * const ChatMessageReceivedNotification					= @"ChatMessageReceivedNotification";
NSString * const ChatTypingNotificationReceivedNotification			= @"ChatTypingNotificationReceivedNotification";
NSString * const ChatFileInfoMessageReceivedNotification			= @"ChatFileInfoMessageReceivedNotification";
NSString * const ChatGeolocationMessageReceivedNotification			= @"ChatGeolocationMessageReceivedNotification";
NSString * const ChatMessageDeliveryStatusNotification				= @"ChatMessageDeliveryStatusNotification";

// Notifications' user info keys
NSString * const kMessageUserInfoKey						= @"ChatMessageMessage";
NSString * const kDeliveryStatusSeenIdsKey				= @"kDeliveryStatusSeenIdsKey";
NSString * const kDeliveryStatusDeliveredMidKey			= @"kDeliveryStatusDeliveredMidKey";


//Api keys
NSString * const kStartTyping	= @"start";
NSString * const kStoppedTyping	= @"stop";


@implementation ChatManager
{
}


+ (instancetype)defaultManager
{
	static dispatch_once_t once;
    static ChatManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {

	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -

- (void)sendChatMessage:(NSString *)message to:(NSString *)recepientId
{
	NSString *mId = [[self class] generateNewMId];
	NSDictionary *chatMessage = @{NSStr(kToKey): recepientId, NSStr(kTypeKey): NSStr(kChatKey), NSStr(kChatKey) :
									  @{NSStr(kMessageKey):message, NSStr(kMidKey) : mId, NSStr(kNoEchoKey) : [NSNumber numberWithBool:YES]}};
	NSString *jsonChatMessage = [chatMessage JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
	
	ChatMessage *chatMessageObject = [[self class] chatMessageWithType:kChatMessageTypeMessage
																	to:recepientId
																  from:[UsersManager defaultManager].currentUser.sessionId
																   mId:mId
																  date:[NSDate date]
															dateString:nil
															   message:message];
	
	chatMessageObject.userName = kSMLocalStringMeLabel;
	
	[[UsersActivityController sharedInstance] addUserActivityToHistory:chatMessageObject forUserSessionId:chatMessageObject.to];
}


- (void)sendChatTypingNotification:(NSString *)message to:(NSString *)recepientId
{
	NSDictionary *chatMessage = @{NSStr(kToKey) : recepientId, NSStr(kTypeKey): NSStr(kChatKey), NSStr(kChatKey): @{NSStr(kStatusKey): @{NSStr(kTypingKey): message}}};
	NSString *jsonChatMessage = [chatMessage JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
}


- (void)sendChatFileInfoMessage:(ChatFileInfo *)chatFileInfo to:(NSString *)recepientId
{
	NSDictionary *jsonFileInfoDict = [self jsonDictionaryWithChatMessage:chatFileInfo messageType:kChatMessageTypeFileInfo];
	NSString *jsonChatMessage = [jsonFileInfoDict JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
}


- (void)sendChatGeolocationMessage:(ChatGeolocation *)chatGeolocation to:(NSString *)recepientId
{
	NSDictionary *jsonFileInfoDict = [self jsonDictionaryWithChatMessage:chatGeolocation messageType:kChatMessageTypeGeolocation];
	NSString *jsonChatMessage = [jsonFileInfoDict JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
    
    [[UsersActivityController sharedInstance] addUserActivityToHistory:chatGeolocation forUserSessionId:chatGeolocation.to];
}


- (void)sendDeliveryConfirmationForMid:(NSString *)mId to:(NSString *)recepientId
{
	NSDictionary *chatMessage = @{NSStr(kToKey) : recepientId,
								  NSStr(kTypeKey): NSStr(kChatKey),
								  NSStr(kChatKey): @{NSStr(kStatusKey): @{NSStr(kStateKey): NSStr(kLCDeliveredKey), NSStr(kMidKey) : mId}, NSStr(kNoEchoKey) : @(YES)}
								  };
	NSString *jsonChatMessage = [chatMessage JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
}


- (void)sendSeenMids:(NSArray *)mIds to:(NSString *)recepientId
{
	NSDictionary *chatMessage = @{NSStr(kToKey) : recepientId,
								  NSStr(kTypeKey): NSStr(kChatKey),
								  NSStr(kChatKey): @{NSStr(kStatusKey): @{NSStr(kSeenMidsKey) : mIds}, NSStr(kNoEchoKey) : @(YES)}
								  };
	NSString *jsonChatMessage = [chatMessage JSONString];
	spreed_me_log("Chat request: %s", [jsonChatMessage cDescription]);
	[[SMConnectionController sharedInstance].channelingManager sendMessage:jsonChatMessage type:NSStr(kChatKey) to:recepientId];
}


#pragma mark -

- (void)receivedChatMessage:(NSDictionary *)chatMessage transportType:(ChannelingMessageTransportType)transportType
{
	NSDictionary *userInfo = nil;
	
	NSString *to = [chatMessage objectForKey:NSStr(kToKey)];
	NSString *from = [chatMessage objectForKey:NSStr(kFromKey)];
	NSString *recentActivityControllerUserSessionId = from; // Since this is received message we need to take 'from' field to account this activity
	
	/*
     We need to use the 'To' field inside the Data object because is the field that tell us to whom was written that message.
     In the field 'To' outside the Data object is created by the server and it should be the same as our current session Id.
     */
	BOOL roomChatMessage = NO;
    NSString *toInData = [[chatMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kToKey)];
	if ([toInData length] == 0) {
		// Since this is received message and inner 'to' is empty we assume that this is 'room' activity
		recentActivityControllerUserSessionId = [[UsersManager defaultManager].currentUser.room.name copy];
		roomChatMessage = YES;
	}
	
	if ([to isEqualToString:from] && [from isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
		// This is an echo message. Ignore it.
		return;
	}
	
	if (!roomChatMessage) {
		// this should be just a normal user, so hold it
		User *user = [[UsersManager defaultManager] userForSessionId:recentActivityControllerUserSessionId];
		if (user) {
			// This holding covers all cases when we need to hold user.
			// We will hold user for real incoming message and as well when we send message
			// delivery status makes us hold user to whom we have sent message, providing the user is online.
			[[UsersManager defaultManager] holdUser:user forSessionId:user.sessionId];
		} else {
			spreed_me_log("We have received message but we don't know the sender. from %s", [from cDescription]);
		}
	}
	
	NSString *userName = [[UsersManager defaultManager] userDisplayNameForSessionId:from];
	
	//Adding Time in String
    NSString *time = [[[chatMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kChatKey)] objectForKey:NSStr(kTimeKey)];
	NSDate *date = nil;
    if (time!= NULL && ![time isEqualToString:@""]) {
        date = [self dateFromRFC3339DateTimeString:time];
	}
	if (!date) {
		date = [[NSDate alloc] init];
	}
	time = [self userVisibleDateTimeString:date];
	
	
	BOOL shouldSendDeliveryConfirmation = NO;
	NSString *mId = [[[chatMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kChatKey)] objectForKey:NSStr(kMidKey)];
	if (mId && [mId isKindOfClass:[NSString class]] && !roomChatMessage) { //Do not send status to room chat messages
		if ([mId length] > 0) {
			shouldSendDeliveryConfirmation = YES;
		}
	} else {
		mId = nil;
	}

	// Getting chat message type
	NSDictionary *statusDict = [[[chatMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kChatKey)] objectForKey:NSStr(kStatusKey)];
	if ([statusDict isKindOfClass:[NSDictionary class]]) {
		id statusObject = nil;
		if ((statusObject = [statusDict objectForKey:NSStr(kTypingKey)]))
		{
			if (shouldSendDeliveryConfirmation) {
				[self sendDeliveryConfirmationForMid:mId to:from];
			}
			
			TypingNotificationType typing = kFinishedTyping;
			
			// We assume that message format is correct and typing specifier is string
			if ([statusObject isEqualToString:kStartTyping]) {
				typing = kStartedTyping;
			} else if ([statusObject isEqualToString:kStoppedTyping]) {
				typing = kFinishedTyping;
			}
			
			ChatTypingNotification *message = (ChatTypingNotification *)[[self class] chatMessageWithType:kChatMessageTypeTyping
																									   to:toInData from:from mId:mId date:date
																							   dateString:time message:nil];
			message.typingNotifType = typing;
			message.userName = userName;
			
			userInfo = @{kMessageUserInfoKey : message};
			
			[[NSNotificationCenter defaultCenter] postNotificationName:ChatTypingNotificationReceivedNotification
																object:self
															  userInfo:userInfo];
			return;
			
		} else if ((statusObject = [statusDict objectForKey:NSStr(kFileInfoKey)])) {
			if ([from isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
				return;
			}
			
			if (shouldSendDeliveryConfirmation) {
				[self sendDeliveryConfirmationForMid:mId to:from];
			}
			
			ChatFileInfo *message = (ChatFileInfo *)[[self class] chatMessageWithType:kChatMessageTypeFileInfo
																				   to:toInData from:from mId:mId date:date
																		   dateString:time message:nil];
			message.userName = userName;
			
			[self fillChatFileInfo:message withDictionary:statusObject];
			message.fileTransferType = kSTChatFileTransferTypeDownload;
		
			[[UsersActivityController sharedInstance] addUserActivityToHistory:message forUserSessionId:recentActivityControllerUserSessionId];
			
			userInfo = @{kMessageUserInfoKey : message};
			
			[[NSNotificationCenter defaultCenter] postNotificationName:ChatFileInfoMessageReceivedNotification
																object:self
															  userInfo:userInfo];
			return;
		} else if ((statusObject = [statusDict objectForKey:NSStr(kGeolocationKey)])) {
			if ([from isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
				return;
			}
			
			if (shouldSendDeliveryConfirmation) {
				[self sendDeliveryConfirmationForMid:mId to:from];
			}
			
			ChatGeolocation *message = (ChatGeolocation *)[[self class] chatMessageWithType:kChatMessageTypeGeolocation
																				   to:toInData from:from mId:mId date:date
																		   dateString:time message:nil];
			message.userName = userName;
			
			[self fillChatGeolocation:message withDictionary:statusObject];
            
			[[UsersActivityController sharedInstance] addUserActivityToHistory:message forUserSessionId:recentActivityControllerUserSessionId];
			
			userInfo = @{kMessageUserInfoKey : message};
			
			[[NSNotificationCenter defaultCenter] postNotificationName:ChatGeolocationMessageReceivedNotification
																object:self
															  userInfo:userInfo];
			return;
		} else if ((statusObject = [statusDict objectForKey:NSStr(kStateKey)]) && !roomChatMessage) { // Ignore State on group chat
			if ([statusObject isKindOfClass:[NSString class]]) {
				if ([statusObject isEqualToString:NSStr(kLCSentKey)]) {
					// Ignore 'sent' for now
				} else if ([statusObject isEqualToString:NSStr(kLCDeliveredKey)]) {
					NSString *deliveredMId = [statusDict objectForKey:NSStr(kMidKey)];
					if ([deliveredMId length] > 0) {
						userInfo = @{kDeliveryStatusDeliveredMidKey : deliveredMId};
						[[NSNotificationCenter defaultCenter] postNotificationName:ChatMessageDeliveryStatusNotification
																			object:self
																		  userInfo:userInfo];
					}
				}
			}
			return;
		} else if ((statusObject = [statusDict objectForKey:NSStr(kSeenMidsKey)]) && !roomChatMessage) { // Ignore SeenMids on group chat
			if ([statusObject isKindOfClass:[NSArray class]]) {
				NSArray *seenMids = (NSArray *)statusObject;
				if ([seenMids count] > 0) {
					userInfo = @{kDeliveryStatusSeenIdsKey : seenMids};
					[[NSNotificationCenter defaultCenter] postNotificationName:ChatMessageDeliveryStatusNotification
																		object:self
																	  userInfo:userInfo];
				}
			}
			return;
		} else if (statusDict) {
			// Unknown message. We should skip it.
			
			spreed_me_log("Unknown message: \n %s\n", [chatMessage cDescription]);
			
			return;
		}
	}

	// This appears to be a regular chat message
	NSString *message = [[[chatMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kChatKey)] objectForKey:NSStr(kMessageKey)];
    if ([message isKindOfClass:[NSString class]] && ![message isEqualToString:@""]) {
		
		if (shouldSendDeliveryConfirmation) {
			[self sendDeliveryConfirmationForMid:mId to:from];
		}
		
		ChatMessage *defaultMessage = [[self class] chatMessageWithType:kChatMessageTypeMessage
																	 to:toInData from:from mId:mId date:date
															 dateString:time message:message];
		defaultMessage.userName = userName;
		
		[[UsersActivityController sharedInstance] addUserActivityToHistory:defaultMessage forUserSessionId:recentActivityControllerUserSessionId];
		
		userInfo = @{kMessageUserInfoKey : defaultMessage};
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ChatMessageReceivedNotification
															object:self
														  userInfo:userInfo];
		
		[self postChatMessageLocalNotification:message from:from];
	}
}


#pragma mark -
+ (ChatMessage *)chatMessageWithType:(ChatMessageType)type
								  to:(NSString *)to
								from:(NSString *)from
								 mId:(NSString *)mId
								date:(NSDate *)date
						  dateString:(NSString *)dateString
							 message:(NSString *)message
{
	ChatMessage *chatMessage = nil;
	
	switch (type) {
		case kChatMessageTypeMessage:
			chatMessage = [[ChatMessage alloc] init];
		break;
			
		case kChatMessageTypeTyping:
			chatMessage = [[ChatTypingNotification alloc] init];
		break;
			
		case kChatMessageTypeFileInfo:
			chatMessage = [[ChatFileInfo alloc] init];
		break;
        
        case kChatMessageTypeGeolocation:
        chatMessage = [[ChatGeolocation alloc] init];
		break;
		
		case kChatMessageTypeUndefined:
		default:
		break;
	}
	
	chatMessage.to = to;
	chatMessage.from = from;
    if ([chatMessage.to isEqualToString:@""]){
        chatMessage.deliveryStatus = kChatMessageDeliveryStatusGroupChat;
    } else if ([chatMessage.from isEqualToString:[UsersManager defaultManager].currentUser.sessionId]) {
		chatMessage.deliveryStatus = kChatMessageDeliveryStatusSent;
	} else {
		chatMessage.deliveryStatus = kChatMessageDeliveryStatusRemoteMessage;
	}
	
	chatMessage.mId = mId;
	chatMessage.date = date;
	chatMessage.dateString = dateString;
	chatMessage.message = message;
	
	return chatMessage;
}


+ (NSString *)generateNewMId
{
	NSString *mId = nil;
	std::string randomString;
	int idLength = 16;
	bool succes = rtc::CreateRandomString(idLength, &randomString);
	if (!succes) {
		spreed_me_log("Couldn't generate random string to create mId!\n");
		assert(false);
	} else {
		mId = [NSString stringWithCString:randomString.c_str() encoding:NSUTF8StringEncoding];
	}
	
	return mId;
}


#pragma mark -

- (void)postChatMessageLocalNotification:(NSString *)message from:(NSString *)userSessionId
{
	if (![message isEqualToString:@""] && userSessionId) {
		
		User *buddy = [[UsersManager defaultManager] userForSessionId:userSessionId];
        UIApplication *app = [UIApplication sharedApplication];
        if (app.applicationState != UIApplicationStateActive) {
            [[STLocalNotificationManager sharedInstance] postLocalNotificationWithSoundName:@"message1.wav"
                                                                                  alertBody:[NSString stringWithFormat:@"%@: %@", buddy.displayName, message]
                                                                                alertAction:kSMLocalStringReadMessageButton];
        }
    }
}


#pragma mark - Utilities

- (void)fillChatFileInfo:(ChatFileInfo *)fileInfo withDictionary:(NSDictionary *)dict
{
	if (fileInfo && dict && [fileInfo isKindOfClass:[ChatFileInfo class]]) {
	
		unsigned int chunks = [[dict objectForKey:NSStr(kLCChunksKey)] unsignedIntValue];
		NSString *token = [dict objectForKey:NSStr(kLCIdKey)];
		NSString *fileName = [dict objectForKey:NSStr(kLCNameKey)];
		NSString *fileType = [dict objectForKey:NSStr(kLCTypeKey)];
		unsigned long long fileSize = [[dict objectForKey:NSStr(kLCSizeKey)] unsignedLongLongValue];
		
		fileInfo.chunks = chunks;
		fileInfo.token = token;
		fileInfo.fileName = fileName;
		fileInfo.fileType = fileType;
		fileInfo.fileSize = fileSize;
	} else {
		spreed_me_log("No fileInfo object or no dictionary to fill with or fileInfo object is of incorrect class!");
	}
}


- (void)fillChatGeolocation:(ChatGeolocation *)geolocation withDictionary:(NSDictionary *)dict
{
	if (geolocation && dict && [geolocation isKindOfClass:[ChatGeolocation class]]) {
        
		CGFloat accuracy = [[dict objectForKey:NSStr(kLCAccuracyKey)] floatValue];
		CGFloat latitude = [[dict objectForKey:NSStr(kLCLatitudeKey)] floatValue];
		CGFloat longitude = [[dict objectForKey:NSStr(kLCLongitudeKey)] floatValue];
		CGFloat altitude = [[dict objectForKey:NSStr(kLCAltitudeKey)] floatValue];
		CGFloat altitudeAccuracy = [[dict objectForKey:NSStr(kLCAltitudeAccuKey)] floatValue];
		
		geolocation.accuracy = accuracy;
		geolocation.latitude = latitude;
		geolocation.longitude = longitude;
		geolocation.altitude = altitude;
		geolocation.altitudeAccuracy = altitudeAccuracy;
	} else {
		spreed_me_log("No geolocation object or no dictionary to fill with or geolocation object is of incorrect class!");
	}
}


- (NSDictionary *)jsonDictionaryWithChatMessage:(ChatMessage *)message messageType:(ChatMessageType)type
{
	NSDictionary *retDict = nil;
	
	message.to = [message.to length] > 0 ? message.to : @"";
	
	switch (type) {
		case kChatMessageTypeFileInfo:
		{
			ChatFileInfo *fileInfo = (ChatFileInfo *)message;
			
			NSDictionary *fileInfoDict = @{
										   NSStr(kLCChunksKey) : @(fileInfo.chunks),
											   NSStr(kLCIdKey) : fileInfo.token,
											   NSStr(kLCNameKey) : fileInfo.fileName,
											   NSStr(kLCTypeKey) : fileInfo.fileType,
											   NSStr(kLCSizeKey) : @(fileInfo.fileSize)
										   };
			
			retDict = @{
						NSStr(kToKey): fileInfo.to, NSStr(kTypeKey): NSStr(kChatKey), NSStr(kChatKey): @{
								NSStr(kMessageKey) : fileInfo.message,
								NSStr(kMidKey) : message.mId,
								NSStr(kNoEchoKey) : @(YES),
								NSStr(kStatusKey) : @{NSStr(kFileInfoKey) : fileInfoDict}
								}
						};
		}
		break;
		
        case kChatMessageTypeGeolocation:
        {
			ChatGeolocation *geolocation = (ChatGeolocation *)message;
			
			NSDictionary *geolocationDict = @{
										   NSStr(kLCAccuracyKey) : @(geolocation.accuracy),
                                           NSStr(kLCLatitudeKey) : @(geolocation.latitude),
                                           NSStr(kLCLongitudeKey) : @(geolocation.longitude),
                                           NSStr(kLCAltitudeKey) : @(geolocation.altitude),
                                           NSStr(kLCAltitudeAccuKey) : @(geolocation.altitudeAccuracy)
										   };
			
			retDict = @{
						NSStr(kToKey): geolocation.to, NSStr(kTypeKey): NSStr(kChatKey), NSStr(kChatKey): @{
								NSStr(kMessageKey) : geolocation.message,
								NSStr(kMidKey) : message.mId,
								NSStr(kNoEchoKey) : @(YES),
								NSStr(kStatusKey) : @{NSStr(kGeolocationKey) : geolocationDict}
								}
						};
		}
        break;
        
		case kChatMessageTypeMessage:
		break;

		case kChatMessageTypeTyping:
			
		break;
		
		case kChatMessageTypeUndefined:
		default:
		break;
	}
	
	return retDict;
}


- (NSDate *)dateFromRFC3339DateTimeString:(NSString *)rfc3339DateTimeString
// Returns a date that corresponds to the specified RFC 3339 date time string.
// Note that this does not handle all possible RFC 3339 date time strings,
// just one of the most common styles.
{
	NSDateFormatter *RFC3339DateFormatter = [[DateFormatterManager sharedInstance] RFC3339DateFormatter];
    NSDate *date = [RFC3339DateFormatter dateFromString:rfc3339DateTimeString];
    return date;
}


- (NSString *)userVisibleDateTimeString:(NSDate *)date
{
    NSString *userVisibleDateTimeString = nil;
    
	NSDateFormatter *sUserVisibleDateFormatter = [[DateFormatterManager sharedInstance] userVisibleDateFormatter];
	userVisibleDateTimeString = [sUserVisibleDateFormatter stringFromDate:date];
    
    return userVisibleDateTimeString;
}


@end
