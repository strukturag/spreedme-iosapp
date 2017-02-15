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

#import "UsersActivityController.h"

@class UserActivityManager;

@protocol UserActivityManagerListener <NSObject>
@optional
- (void)userActivityManager:(UserActivityManager *)manager didAddActivity:(id<UserRecentActivity>)activity atIndex:(NSInteger)index;
- (void)userActivityManager:(UserActivityManager *)manager didUpdateActivity:(id<UserRecentActivity>)activity atIndex:(NSInteger)index;
- (void)userActivityManager:(UserActivityManager *)manager didUpdateActivities:(NSArray *)activities atIndices:(NSArray *)indices;
- (void)userActivityManagerDidBecomeActive:(UserActivityManager *)manager;
- (void)userActivityManagerDidBecomeInactive:(UserActivityManager *)manager;
@end


@interface UserActivityManager : NSObject 

@property (nonatomic, readonly, strong) NSString *userSessionId;

@property (nonatomic, readonly, strong) NSString *lastDayLimitedDateString;
@property (nonatomic, readonly, strong) NSDate *lastUserActivityDate;
@property (nonatomic, readonly, strong) NSArray *userActivity;

@property (nonatomic, assign) NSUInteger indexOfLastActivitySeenByUser;
@property (nonatomic, assign) NSUInteger numberOfActivitiesSeenByUser;

@property (nonatomic, assign) BOOL isUserAvailable;


- (id)initWithUserSessionId:(NSString *)userSessionId andActivityArray:(NSArray *)activityArray;

- (void)addUserActivityToHistory:(id<UserRecentActivity>)recentActivity;
- (void)purgeAllHistory;
- (id<UserRecentActivity>)activityAtIndex:(NSInteger)index;
- (NSUInteger)activitiesCount;
- (NSInteger)getNumberOfUnreadMessages;


/*
 These methods work exactly the same as NSNotifications in terms of memory management. You should always unsubscribe 'listener' before dealocating it.
 You can only subscribe object once. This class uses NSMutableSet internally to keep track of subscriptions.
 */
- (void)subscribeForUpdates:(id<UserActivityManagerListener>)object;
- (void)unsubscribeForUpdates:(id<UserActivityManagerListener>)object;

@end
