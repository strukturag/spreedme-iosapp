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

#import "SMLocalUserSettings.h"
#import "SMRoom.h"
#import "User.h"


@class SMLocalUser;


@interface SMLocalUser : User

@property (nonatomic, copy) NSString *username; //unique but changable

@property (nonatomic, copy) NSString *secUserId; //secure userId known only to this user.

@property (nonatomic, copy) NSString *lastUserIdCombo;
@property (nonatomic, copy) NSString *lastUserIdComboSecret;

@property (nonatomic, readwrite) BOOL wasConnected;
@property (nonatomic, readwrite) BOOL isAdmin;
@property (nonatomic, readwrite) BOOL isSpreedMeAdmin;
@property (nonatomic, copy) NSString *storedUserImagePath;
@property (nonatomic, strong) NSMutableArray *roomsList; // list of rooms user has created/joined
@property (nonatomic, strong) SMRoom *room;

@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSDate *accessTokenExpirationDate;

@property (nonatomic, copy) NSString *sessionToken;

@property (nonatomic, strong) NSString *applicationToken;
@property (nonatomic, copy) NSNumber *lastLoginTimeStamp;//NSTimeInterval

@property (nonatomic, strong) SMLocalUserSettings *settings;


+ (instancetype)localUserFromDir:(NSString *)dir;
- (BOOL)saveToDir:(NSString *)dir;

+ (instancetype)localUserWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryFromUser;

@end
