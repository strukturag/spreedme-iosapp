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

#import "MissedCall.h"

#import "UsersManager.h"
#import "DateFormatterManager.h"
#import "JSONKit.h"
#import "SMLocalizedStrings.h"
#import "STChatViewController.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"

NSString * const kMissedCallDateFormat = @"yyyy-MM-dd : HH:mm:ss";


NSString const * kMissedCallUserSessionIdKey	= @"UserSessionIdKey";
NSString const * kMissedCallSelfIdKey			= @"SelfIdKey";
NSString const * kMissedCallDateKey				= @"DateKey";
NSString const * kMissedCallBuddyNameKey		= @"BuddyNameKey";


@implementation MissedCall

- (id)copyWithZone:(NSZone *)zone
{
	MissedCall* copyObject = [[[self class] allocWithZone:zone] init];
	copyObject.date = [_date copyWithZone:zone];
	copyObject.userSessionId = [_userSessionId copyWithZone:zone];
	copyObject.selfId = [_selfId copyWithZone:zone];
	copyObject.userName = [_userName copyWithZone:zone];
	
	return copyObject;
}


+ (MissedCall *)missedCallFromJsonString:(NSString *)jsonString
{
	MissedCall *call = nil;
	
	if ([jsonString length]) {
		NSDictionary *missedCallDic = [jsonString objectFromJSONString];
		
		call = [[MissedCall alloc] init];
		call.userSessionId = [missedCallDic objectForKey:kMissedCallUserSessionIdKey];
		call.selfId = [missedCallDic objectForKey:kMissedCallSelfIdKey];
		call.userName = [missedCallDic objectForKey:kMissedCallBuddyNameKey];
		
		NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] fullReadableDateFormatter];
		
		call.date = [dateFormatter dateFromString:[missedCallDic objectForKey:kMissedCallDateKey]];
	}
		
	return call;
}

/*
 This method saves date as string using kMissedCallDateFormat date format to make a string
 */
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	
	[dictionary setObject:self.userSessionId forKey:kMissedCallUserSessionIdKey];
	[dictionary setObject:self.selfId forKey:kMissedCallSelfIdKey];
	
	NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] fullReadableDateFormatter];
	[dictionary setObject:[dateFormatter stringFromDate:self.date] forKey:kMissedCallDateKey];
	
	return [NSDictionary dictionaryWithDictionary:dictionary];
}


- (NSString *)jsonRepresentation
{
	NSString *jsonRepresentation = nil;
	
	NSDictionary *dicRepresentation = [self dictionaryRepresentation];
	if ([dicRepresentation count]) {
		jsonRepresentation = [dicRepresentation JSONString];
	}
	
	return jsonRepresentation;
}


#pragma mark - UserRecentActivity protocol

//- (NSDate *)date; implemented already
- (NSString *)to
{
	return self.selfId;
}


- (NSString *)from
{
	return self.userSessionId;
}


- (BOOL)isStartOfGroup
{
	return YES;
}


- (BOOL)isEndOfGroup
{
	return YES;
}


- (void)setIsStartOfGroup:(BOOL)yesNo
{}

- (void)setIsEndOfGroup:(BOOL)yesNo
{}


- (BOOL)shouldNotGroupAutomatically
{
	return YES;
}


#pragma mark - STServiceChatMessage protocol

- (STChatMessageVisualType)messageVisualType
{
	return kSTChatMessageVisualTypeServiceMessage;
}


- (NSString *)missedCallFrom
{
    return [[UsersManager defaultManager] userDisplayNameForSessionId:self.from];
}


- (NSDate *)missedCallWhen
{
    return self.date;
}


- (NSAttributedString *)attributedTextForMissedCallFrom:(NSString *)from
{
    NSString *tnicon = [NSString fontAwesomeIconStringForEnum:FAPhone];
    
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:14];
    UIFont *font2=[UIFont systemFontOfSize:14.0f];
	
	NSString *missedCallFromString = [NSString stringWithFormat:kSMLocalStringMissedCallFromLabelArg1, from];
	
    NSString *missedCallText = [NSString stringWithFormat:@"%@  %@", tnicon, missedCallFromString];
	
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:missedCallText];
    
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
    [attrString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(1, [attrString length]-1)];
    
    return attrString;
}


- (NSAttributedString *)attributedTextForMissedCallDate:(NSDate *)date
{
    UIFont *font=[UIFont systemFontOfSize:12.0f];
	NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] defaultLocalizedShortDateTimeStyleFormatter];
    NSString *missedCallDate = [NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:date]];
	
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:missedCallDate];
    
    [attrString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [attrString length])];
    
    return attrString;
}


//- (NSDate *)date; implemented already
//- (BOOL)isStartOfGroup; implemented already
//- (BOOL)isEndOfGroup; implemented already


- (BOOL)isSentByLocalUser
{
	return NO;
}


- (UIImage *)localUserAvatar
{
	return nil;
}


- (UIImage *)remoteUserAvatar
{
	return nil;
}


- (STChatServiceMessageType)serviceMessageType
{
	return kSTChatServiceMessageTypeMissedCall;
}

@end
