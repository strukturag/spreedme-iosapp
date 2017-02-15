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

#import "UsersActivityController.h"

#import "CommonDefinitions.h"
#import "DateFormatterManager.h"
#import "NonRetainSubscriptionManager.h"
#import "SettingsController.h"
#import "UserActivityManager.h"
#import "UserInterfaceManager.h"
#import "UsersManager.h"

@implementation UsersActivityController
{
	NSMutableDictionary *_userActivityHistoryJournal; // contains (as value) UserActivityManager for userSessionId key
	NSMutableDictionary *_lastUserActivityDateDict; // contains (as value) last date of user activity for userSessionId key
	
	NSMutableArray *_userActivityArray; // array of userSessionIds sorted by date of most recent activity

	
	NonRetainSubscriptionManager *_subscriptionManager;
}


#pragma mark -

+ (instancetype)sharedInstance
{
	static dispatch_once_t once;
    static UsersActivityController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		_userActivityHistoryJournal = [[NSMutableDictionary alloc] init];
		_lastUserActivityDateDict = [[NSMutableDictionary alloc] init];
		_userActivityArray = [[NSMutableArray alloc] init];

		_subscriptionManager = [[NonRetainSubscriptionManager alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasResetApplication:) name:UserHasResetApplicationNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userHasChangedApplicationMode:) name:UserHasChangedApplicationModeNotification object:nil];
        
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Listener subscription

- (void)subscribeForUpdates:(id<UserRecentActivityControllerUpdatesListener>)object
{
	[_subscriptionManager subscribeObject:object];
}


- (void)unsubscribeForUpdates:(id<UserRecentActivityControllerUpdatesListener>)object
{
	[_subscriptionManager unsubscribeObject:object];
}


#pragma mark -

- (void)addUserActivityToHistory:(id<UserRecentActivity>)recentActivity forUserSessionId:(NSString *)userSessionId
{
	// If userSessionId is nil or empty we assume that this is 'room' activity
	if ([userSessionId length] == 0) {
		userSessionId = [[UsersManager defaultManager].currentUser.room.name copy];
	}
	
	// Add recentActivity to journal
	UserActivityManager *userActivityManager = [_userActivityHistoryJournal objectForKey:userSessionId];
	if (!userActivityManager) {
		userActivityManager = [[UserActivityManager alloc] initWithUserSessionId:userSessionId andActivityArray:nil];
	}

	[userActivityManager addUserActivityToHistory:recentActivity];
	[_userActivityHistoryJournal setObject:userActivityManager forKey:userSessionId];
	
	
	NSDate *currentDate = [NSDate date];
	
	// Check if we need to make changes in sorted userActivity array and if we need issue an updated id we changed order
	NSUInteger index = [_userActivityArray indexOfObject:userSessionId];
	if (index != NSNotFound && index != 0) {
		[_userActivityArray removeObjectAtIndex:index];
		[_userActivityArray insertObject:userSessionId atIndex:0];
	} else if (index == NSNotFound) {
		[_userActivityArray insertObject:userSessionId atIndex:0];
	}
	
	// Remember precise date of last user activity for user
	[_lastUserActivityDateDict setObject:currentDate forKey:userSessionId];
	
	// Issue updates
	NSString *dayLimitedDateString = [self dayLimitedDateStringForDate:currentDate];
	
	[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(userActivityController:userSessionId:hasBeenActiveAt:movedOnTopFromIndex:)]) {
			[obj userActivityController:self userSessionId:userSessionId hasBeenActiveAt:dayLimitedDateString movedOnTopFromIndex:index];
		}
	}];
}


- (void)removeAllUserActivitiesFromHistoryForUserSessionId:(NSString *)userSessionId
{
    // If userSessionId is nil or empty we assume that this is 'room' activity
    if ([userSessionId length] == 0) {
        userSessionId = [[UsersManager defaultManager].currentUser.room.name copy];
    }
    
    UserActivityManager *userActivityManager = [_userActivityHistoryJournal objectForKey:userSessionId];
    if (!userActivityManager) {
        userActivityManager = [[UserActivityManager alloc] initWithUserSessionId:userSessionId andActivityArray:nil];
    }
    
    [userActivityManager purgeAllHistory];
    [_userActivityHistoryJournal removeObjectForKey:userSessionId];
    
    NSUInteger index = [_userActivityArray indexOfObject:userSessionId];
    if (index != NSNotFound) {
        [_userActivityArray removeObjectAtIndex:index];
    }
}


- (void)purgeAllHistory
{
	[_userActivityHistoryJournal removeAllObjects];
    [_userActivityArray removeAllObjects];
    
    [_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(userActivityControllerDidPurgeAllHistory:)]) {
			[obj userActivityControllerDidPurgeAllHistory:self];
		}
	}];
}


- (id<UserRecentActivity>)recentActivityAtIndex:(NSInteger)index forUserSessionId:(NSString *)userSessionId
{
	id<UserRecentActivity> activity = nil;
	UserActivityManager *userActivityManager = [_userActivityHistoryJournal objectForKey:userSessionId];
	if (userActivityManager) {
		activity = [userActivityManager activityAtIndex:index];
	}
	
	return activity;
}


- (NSUInteger)recentActivitiesCountForUserSessionId:(NSString *)userSessionId
{
	NSUInteger recentActivitiesCount = 0;
	
	UserActivityManager *userActivityManager = [_userActivityHistoryJournal objectForKey:userSessionId];
	if (userActivityManager) {
		recentActivitiesCount = [userActivityManager activitiesCount];
	}
	
	return recentActivitiesCount;
}


- (NSInteger)recentUsersCount
{
	return [_userActivityHistoryJournal count];
}


- (UserActivityManager *)userActivityManagerForUserSessionId:(NSString *)userSessionId
{
	UserActivityManager *userActivityManager = nil;
	
	if (userSessionId) {
		userActivityManager = [_userActivityHistoryJournal objectForKey:userSessionId];
		if (!userActivityManager) {
			userActivityManager = [[UserActivityManager alloc] initWithUserSessionId:userSessionId andActivityArray:nil];
			[_userActivityHistoryJournal setObject:userActivityManager forKey:userSessionId];
		}
	}
	
	return userActivityManager;
}


- (NSArray *)recentUsersId
{
	return [_userActivityHistoryJournal allKeys];
}


- (NSArray *)recentUsersSessionIdSorted
{
	return _userActivityArray;
}


#pragma mark -

- (NSString *)dayLimitedDateStringForDate:(NSDate *)date
{
	NSDateFormatter *dayLimitedDateDormatter = [[DateFormatterManager sharedInstance] dayLimitedDateDormatter];
	NSString *dayLimitedDateString = [dayLimitedDateDormatter stringFromDate:date];
	
	return dayLimitedDateString;
}


#pragma mark - Notifications

- (void)userHasResetApplication:(NSNotification *)notification
{
    [self purgeAllHistory];
}


- (void)userHasChangedApplicationMode:(NSNotification *)notification
{
	[self purgeAllHistory];
}


- (void)appplicationDidEnterBackground:(NSNotification *)notification
{
	if ([UsersManager defaultManager].currentUser.settings.shouldClearDataOnBackground) {
		[self purgeAllHistory];
	}
}


@end
