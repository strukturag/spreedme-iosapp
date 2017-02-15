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
#import "User.h"


extern NSString * const BuddyImageHasBeenUpdatedNotification;
extern NSString * const UserSessionIdUserInfoKey;
extern NSString * const BuddyImageUserInfoKey;
extern NSString * const SMUserImageRevisionUserInfoKey;


typedef enum BuddyDictionaryType {
	
	kBuddyDictionaryTypeStatus = 0,
	kBuddyDictionaryTypeUsers,
	kBuddyDictionaryTypeJoined,
	
} BuddyDictionaryType;


@interface BuddyParser : NSObject

- (User *)createBuddyFromDictionary: (NSDictionary*)buddy withType:(BuddyDictionaryType)type;
- (NSArray *)createBuddyListFromUsersArray:(NSArray *)buddyArray;

- (void)updateBuddy:(User *)buddy
	 withDictionary:(NSDictionary *)dictionary
		   withType:(BuddyDictionaryType)type
			 userId:(NSString *)userId
	 statusRevision:(uint64_t)statusRev;

+ (UIImage *)defaultUserImage;
+ (NSString *)defaultUserDisplayNameForSessionId:(NSString *)sessionId;


// These methods are thread safe unless you are going to change BuddyParser class in runtime or change parameters during these methods execution
+ (UIImage *)imageFromBase64String:(NSString *)base64ImageString;
+ (UIImage *)imageFromBase64StringWithFormatPrefix:(NSString *)base64ImageString; // removes first 23 characters of prefix - 'data:image/jpeg;base64,'
+ (NSString *)base64EncodedStringFromImage:(UIImage *)image;
+ (NSString *)base64EncodedStringWithFormatPrefixFromImage:(UIImage *)image; // returns base64 encoded image with first 23 characters of prefix - 'data:image/jpeg;base64,'

@end
