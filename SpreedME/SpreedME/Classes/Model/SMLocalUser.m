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

#import "SMLocalUser.h"

#import <CommonCrypto/CommonDigest.h>

#import "AES256Encryptor.h"
#import "BuddyParser.h"
#import "JSONKit.h"
#import "NSData+Conversion.h"
#import "SMAppIdentityController.h"
#import "SMHmacHelper.h"
#import "UIImage+RoundedCorners.h"

NSString * const kSMLocalUserNameKey				= @"username";
NSString * const kSMLocalUserUserIdKey				= @"userId";
NSString * const kSMLocalUserSecureUserIdKey		= @"secureUserId";
NSString * const kSMLocalUserDisplayNameKey			= @"displayName";
NSString * const kSMLocalUserBase64ImageKey			= @"base64Image";
NSString * const kSMLocalUserStatusMessageKey		= @"statusMessage";
NSString * const kSMLocalUserStoredUserImagePathKey	= @"storedUserImagePath";
NSString * const kSMLocalUserRoomKey				= @"roomDict";
NSString * const kSMLocalUserRoomsListKey			= @"roomsList";
NSString * const kSMLocalUserWasConnectedKey		= @"wasConnected";
NSString * const kSMLocalUserAppTokenKey			= @"appToken";
NSString * const kSMLocalUserLastLoginTimeStampKey	= @"lastLoginTimeStamp";
NSString * const kSMLocalUserSettingsKey            = @"settings";


@interface SMLocalUser ()
{
	dispatch_queue_t _workerQueue;
	NSString *_serverToken;
}
@end


@implementation SMLocalUser

- (instancetype)init
{
	self = [super init];
	if (self) {
		_roomsList = [[NSMutableArray alloc] init];
		_displayName = @"";
        _settings = [SMLocalUserSettings defaultSettings];
	}
	return self;
}


#pragma mark - De/Serialization

+ (instancetype)localUserWithDictionary:(NSDictionary *)dict
{
	if (dict) {
		
		SMLocalUser *localUser = [[SMLocalUser alloc] init];
		localUser.username = [dict objectForKey:kSMLocalUserNameKey];
		localUser.userId = [dict objectForKey:kSMLocalUserUserIdKey];
		localUser.secUserId = [dict objectForKey:kSMLocalUserSecureUserIdKey];
		localUser.applicationToken = [dict objectForKey:kSMLocalUserAppTokenKey];
		localUser.lastLoginTimeStamp = [dict objectForKey:kSMLocalUserLastLoginTimeStampKey];
		
		localUser.displayName = [dict objectForKey:kSMLocalUserDisplayNameKey];
		localUser.base64Image = [dict objectForKey:kSMLocalUserBase64ImageKey];
		if (localUser.base64Image) {
			localUser.iconImage = [[BuddyParser imageFromBase64StringWithFormatPrefix:localUser.base64Image]
								   roundCornersWithRadius:kViewCornerRadius];
		}
		
		localUser.statusMessage = [dict objectForKey:kSMLocalUserStatusMessageKey];
		localUser.wasConnected = [[dict objectForKey:kSMLocalUserWasConnectedKey] boolValue];
		
		localUser.storedUserImagePath = [dict objectForKey:kSMLocalUserStoredUserImagePathKey];
		if (localUser.storedUserImagePath) {
			localUser.iconImage = [[UIImage alloc] initWithContentsOfFile:localUser.storedUserImagePath];
		}
		localUser.room = [SMRoom roomWithDictionary:[dict objectForKey:kSMLocalUserRoomKey]];
		
		NSArray *roomsList = [dict objectForKey:kSMLocalUserRoomsListKey];
		if (roomsList.count > 0) {
			NSMutableArray *realRoomsList = [NSMutableArray array];
			for (NSDictionary *roomDict in roomsList) {
				SMRoom *room = [SMRoom roomWithDictionary:roomDict];
				if (room) {
					[realRoomsList addObject:room];
				}
			}
			
			localUser.roomsList = realRoomsList;
		}
        
        localUser.settings = [SMLocalUserSettings settingsFromDictionary:[dict objectForKey:kSMLocalUserSettingsKey]];
        if (!localUser.settings) {
            localUser.settings = [SMLocalUserSettings defaultSettings];
        }
		
		return localUser;
	} else {
		return nil;
	}
}


- (NSDictionary *)dictionaryFromUser
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
	if (self.username) {
		[dict setObject:self.username forKey:kSMLocalUserNameKey];
	}
	
	if (self.userId) {
		[dict setObject:self.userId forKey:kSMLocalUserUserIdKey];
	}
	
	if (self.secUserId) {
		[dict setObject:self.secUserId forKey:kSMLocalUserSecureUserIdKey];
	}
	
	if (self.applicationToken) {
		[dict setObject:self.applicationToken forKey:kSMLocalUserAppTokenKey];
	}
	
	if (self.lastLoginTimeStamp) {
		[dict setObject:self.lastLoginTimeStamp forKey:kSMLocalUserLastLoginTimeStampKey];
	}

	if (self.displayName) {
		[dict setObject:self.displayName  forKey:kSMLocalUserDisplayNameKey];
	}
	
	if (self.base64Image) {
		[dict setObject:self.base64Image forKey:kSMLocalUserBase64ImageKey];
	}
	
	if (self.statusMessage) {
		[dict setObject:self.statusMessage forKey:kSMLocalUserStatusMessageKey];
	}
	
	[dict setObject:@(self.wasConnected) forKey:kSMLocalUserWasConnectedKey];

	if (self.storedUserImagePath) {
		[dict setObject:self.storedUserImagePath forKey:kSMLocalUserStoredUserImagePathKey];
	}
	
	if (self.room) {
		[dict setObject:[self.room dictionaryRepresentation] forKey:kSMLocalUserRoomKey];
	}
	
	if (self.roomsList.count > 0) {
		NSMutableArray *rooms = [NSMutableArray array];
		for (SMRoom *room in self.roomsList) {
			NSDictionary *roomDict = [room dictionaryRepresentation];
			[rooms addObject:roomDict];
		}
		[dict setObject:rooms forKey:kSMLocalUserRoomsListKey];
	}
	
    if (self.settings) {
        [dict setObject:[self.settings dictionaryFromSettings] forKey:kSMLocalUserSettingsKey];
    }
    
	// maybe save current image to given storedUserImagePath
	
	return [NSDictionary dictionaryWithDictionary:dict];
}


#pragma mark - Encrypted save/load

+ (instancetype)localUserFromDir:(NSString *)dir
{
	SMLocalUser *user = nil;
	if (dir.length > 0) {
		AES256Encryptor *encryptor = [[AES256Encryptor alloc] init];
		
		NSData *decryptedData = [encryptor loadDataFromEncryptedFileInDir:dir
															 withPassword:[[[SMAppIdentityController sharedInstance] appBigIdentifier] hexadecimalString]];
		if (!decryptedData) {
			spreed_me_log("Error loading user string from dir (%s)", [dir cDescription]);
			return nil;
		}
		
		NSString *userJsonString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
		NSDictionary *userDict = [userJsonString objectFromJSONString];
		user = [SMLocalUser localUserWithDictionary:userDict];
	}
	
	return user;
}


- (BOOL)saveToDir:(NSString *)dir
{
	BOOL success = NO;
	
	if (dir.length > 0) {
		
		BOOL isDirectory = YES;
		if (![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDirectory]) {
			NSError *error = nil;
			BOOL successDir = [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error];
			if (!successDir) {
				spreed_me_log("We couldn't create directory to user!");
				return NO;
			}
		}
		
		
		NSDictionary *dict = [self dictionaryFromUser];
		if (dict) {
			NSString *userString = [dict JSONString];
			if (userString) {
				
				NSData *dataToEncrypt = [userString dataUsingEncoding:NSUTF8StringEncoding];
				
				AES256Encryptor *encryptor = [[AES256Encryptor alloc] init];
				
				success = [encryptor saveDataEncrypted:dataToEncrypt
										  withPassword:[[[SMAppIdentityController sharedInstance] appBigIdentifier] hexadecimalString]
												 toDir:dir];
				
				if (!success) {
					spreed_me_log("Error saving user string to dir (%s)", [dir cDescription]);
				}
			}
		}
	}
	
	return success;
}


#pragma mark - Setters/getters

- (void)setDisplayName:(NSString *)displayName
{
	if (_displayName != displayName) {
		[super setDisplayName:displayName];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasChangedDisplayNameNotification object:self userInfo:nil];
	}
}


- (void)setStatusMessage:(NSString *)statusMessage
{
	if (_statusMessage != statusMessage) {
		[super setStatusMessage:statusMessage];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasChangedStatusMessageNotification object:self userInfo:nil];
	}
}


- (void)setBase64Image:(NSString *)base64Image
{
	if (_base64Image != base64Image) {
		[super setBase64Image:base64Image];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasChangedDisplayImageNotification object:self userInfo:nil];
	}
}


@end
