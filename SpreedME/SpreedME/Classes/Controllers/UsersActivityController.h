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


@class UsersActivityController;
@class UserActivityManager;

@protocol UserRecentActivity <NSObject>
@required
- (NSDate *)date;
- (NSString *)to;
- (NSString *)from;

- (BOOL)isStartOfGroup;
- (BOOL)isEndOfGroup;
- (void)setIsStartOfGroup:(BOOL)yesNo;
- (void)setIsEndOfGroup:(BOOL)yesNo;

@optional
- (BOOL)shouldNotGroupAutomatically;

@end


@protocol UserRecentActivityControllerUpdatesListener <NSObject>
@optional

- (void)userActivityController:(UsersActivityController *)controller
				 userSessionId:(NSString *)userSessionId
			   hasBeenActiveAt:(NSString *)dayLimitedDateString
		   movedOnTopFromIndex:(NSUInteger)fromIndex;

- (void)userActivityControllerDidPurgeAllHistory:(UsersActivityController *)controller;


@end


@interface UsersActivityController : NSObject

+ (UsersActivityController *)sharedInstance;


- (void)addUserActivityToHistory:(id<UserRecentActivity>)recentActivity forUserSessionId:(NSString *)userSessionId;
- (void)removeAllUserActivitiesFromHistoryForUserSessionId:(NSString *)userSessionId;
- (void)purgeAllHistory;
- (id<UserRecentActivity>)recentActivityAtIndex:(NSInteger)index forUserSessionId:(NSString *)userSessionId;
- (NSUInteger)recentActivitiesCountForUserSessionId:(NSString *)userSessionId;
- (NSInteger)recentUsersCount;
- (NSArray *)recentUsersId;

- (NSArray *)recentUsersSessionIdSorted;

/* 
 Gets UserActivityManager for given userSessionId, if it doesn't exist creates and returns one.
 You shouldn't create UserActivityManager by your own. 
 If this method returns nil it means that something is wrong with userSessionId.
 */
- (UserActivityManager *)userActivityManagerForUserSessionId:(NSString *)userSessionId;

- (NSString *)dayLimitedDateStringForDate:(NSDate *)date;

/* 
 These methods work exactly the same as NSNotifications in terms of memory management. You should always unsubscribe 'listener' before dealocating it.
 You can only subscribe object once. This class uses NSMutableSet internally to keep track of subscriptions.
 */
- (void)subscribeForUpdates:(id<UserRecentActivityControllerUpdatesListener>)object;
- (void)unsubscribeForUpdates:(id<UserRecentActivityControllerUpdatesListener>)object;

@end
