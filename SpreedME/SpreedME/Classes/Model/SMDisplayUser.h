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
#import "SMUserView.h"


typedef enum : NSInteger {
    kSMDisplayUserTypeAnonymous = 0,
    kSMDisplayUserTypeRegistered,
    kSMDisplayUserTypeAnotherOwnSession
} SMDisplayUserType;


@interface SMDisplayUser : NSObject <SMUserView>
{
	SMDisplayUserType _type;
}

@property (nonatomic, copy, readonly) NSString *Id;
@property (nonatomic, copy, readonly) NSString *displayName;
@property (nonatomic, copy, readonly) NSString *statusMessage;
@property (nonatomic, strong, readonly) UIImage *iconImage;
@property (nonatomic, readonly) BOOL isMixer;
@property (nonatomic, readonly) SMDisplayUserType type;

// Array of User objects. If the array doesn't have object this user is not usable.
// Array can be empty only for short periods of time.
@property (nonatomic, strong, readonly) NSArray *userSessions;

- (instancetype)initWithType:(SMDisplayUserType)type;
+ (instancetype)displayUserWithType:(SMDisplayUserType)type;


- (NSString *)sortString;


- (void)addUserSession:(User *)userSession;
- (void)removeUserSessionWithId:(NSString *)sessionId;
- (BOOL)hasUserSessionWithId:(NSString *)sessionId;


@end
