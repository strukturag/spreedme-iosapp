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

#import "SMDisplayUser.h"
#import "SMLocalUser.h"
#import "User.h"
#import "SMChannelingAPIInterface.h"
#import "SMUserView.h"


@class UsersManager;


typedef enum BuddySortOrder
{
	kBuddySortOrderByDisplayName = 1,
}
BuddySortOrder;


@protocol UserUpdatesProtocol <NSObject>
@optional
- (void)roomSessionsListReceived;
- (void)roomUsersListUpdated;
- (void)userHasBeenUpdated:(User *)user;
- (void)userSessionHasJoinedRoom:(User *)user;
- (void)userSessionHasLeft:(User *)user disconnectedFromServer:(BOOL)yesNo;
- (void)displayUserHasBeenUpdated:(SMDisplayUser *)displayUser;
@end


@interface UsersManager : NSObject <SMUsersManagementNotificationsProtocol>

@property (nonatomic, strong) SMLocalUser *currentUser; // Current user is set by SMConnectionController


+ (UsersManager *)defaultManager; // Shared instance. You should not create your own instance although it is technically possible now.

// Saved users management
- (SMLocalUser *)loadUserFromDir:(NSString *)dir;
- (BOOL)saveUser:(SMLocalUser *)localUser toDir:(NSString *)dir;
- (NSString *)savedUsersDirectory;
- (void)saveCurrentUser;
- (void)deleteAllSavedUsers;

// These methods will lookup for user in all 2 tiers in this sequence: room->held
- (User *)userForSessionId:(NSString *)sessionId;
- (NSString *)userDisplayNameForSessionId:(NSString *)userSessionId;
- (NSString *)userBase64ImageForSessionId:(NSString *)userSessionId;
- (UIImage *)userImageForSessionId:(NSString *)userSessionId;

// First tier of user management. Keeps users that are currently in a room
// Room
- (User *)roomUserForSessionId:(NSString *)sessionId;
- (NSString *)roomUserDisplayNameForSessionId:(NSString *)userSessionId;
- (NSString *)roomUserBase64ImageForSessionId:(NSString *)userSessionId;
- (UIImage *)roomUserImageForSessionId:(NSString *)userSessionId;

- (NSArray *)roomUsersSortedByDisplayName;
- (NSUInteger)roomUsersCount;
- (User *)roomUserForIndex:(NSUInteger)index; // Convenience method, inside calls userForIndex:withSortOrder: with order kBuddySortOrderByDisplayName
- (User *)roomUserForIndex:(NSUInteger)index withSortOrder:(BuddySortOrder)buddySortOrder;

- (NSArray *)roomDisplayUsersSortedByDisplayName;
- (NSUInteger)roomDisplayUsersCount;
- (SMDisplayUser *)roomDisplayUserForIndex:(NSUInteger)index; // Convenience method, inside calls userForIndex:withSortOrder: with order kBuddySortOrderByDisplayName
- (SMDisplayUser *)roomDisplayUserForIndex:(NSUInteger)index withSortOrder:(BuddySortOrder)buddySortOrder;
- (SMDisplayUser *)roomDisplayUserForUserId:(NSString *)userId;

// Second tier of user management. Keeps users with which we have interacted. These users can be the same as in room.
// Held
- (User *)heldUserForSessionId:(NSString *)sessionId;
- (NSString *)heldUserDisplayNameForSessionId:(NSString *)userSessionId;
- (NSString *)heldUserBase64ImageForSessionId:(NSString *)userSessionId;
- (UIImage *)heldUserImageForSessionId:(NSString *)userSessionId;

- (void)holdUser:(User *)user forSessionId:(NSString *)sessionId;
- (void)releaseHeldUserForSessionId:(NSString *)sessionId;


// Event subscription
- (void)subscribeForUpdates:(id<UserUpdatesProtocol>)observer;
- (void)unsubscribeForUpdates:(id<UserUpdatesProtocol>)observer;

// Rooms
- (void)addVisitedRoom:(NSString *)roomName;
- (BOOL)wasRoomVisited:(NSString *)roomName;
- (void)removeRoomUsers;

@end
