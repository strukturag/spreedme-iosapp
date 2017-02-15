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

#import "UserActivityManager.h"

#import "User.h"
#import "UsersManager.h"
#import "ChannelingManager.h"
#import "ChatManager.h"
#import "NonRetainSubscriptionManager.h"
#import "UsersActivityController.h"


@interface IndexedChatMessageActivity : NSObject
@property (nonatomic, strong) ChatMessage *chatMessage;
@property (nonatomic, assign) NSInteger index;
+ (IndexedChatMessageActivity *)indexedChatMessageActivityWithChatMessage:(ChatMessage *)message atIndex:(NSInteger)index;
@end

@implementation IndexedChatMessageActivity
- (id)init
{
	self = [super init];
	if (self) {
		_index = -1;
	}
	return self;
}
+ (IndexedChatMessageActivity *)indexedChatMessageActivityWithChatMessage:(ChatMessage *)message atIndex:(NSInteger)index
{
	IndexedChatMessageActivity *activity = [[IndexedChatMessageActivity alloc] init];
	activity.chatMessage = message;
	activity.index = index;
	return activity;
}
@end



@interface UserActivityManager () <UserRecentActivityControllerUpdatesListener, UserUpdatesProtocol>
{
	NSString *_userSessionId;
	UsersActivityController *_usersAcitivityController;
	
	NSMutableArray *_userActivityArray;
	
	NonRetainSubscriptionManager *_subscriptionManager;
	
	NSMutableDictionary *_notSeenSelfMessages;
}

@end


@implementation UserActivityManager


- (id)initWithUserSessionId:(NSString *)userSessionId andActivityArray:(NSArray *)activityArray
{
	self = [super init];
	if (self) {
		_userSessionId = userSessionId;
		
		if (!activityArray) {
			_userActivityArray = [[NSMutableArray alloc] init];
		} else {
			_userActivityArray = [[NSMutableArray alloc] initWithArray:activityArray];
		}
		
        [[UsersManager defaultManager] subscribeForUpdates:self];
        
        if ([[UsersManager defaultManager] userForSessionId:_userSessionId]) {
            _isUserAvailable = YES;
        } else {
            if ([[UsersManager defaultManager] wasRoomVisited:_userSessionId]) {
                _isUserAvailable = YES;
            } else {
                _isUserAvailable = NO;
            }
        }
		
		_usersAcitivityController = [UsersActivityController sharedInstance];
		
		_subscriptionManager = [[NonRetainSubscriptionManager alloc] init];
		
		_notSeenSelfMessages = [[NSMutableDictionary alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deliveryStatusNotificationReceived:) name:ChatMessageDeliveryStatusNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidLeaveRoom:) name:LocalUserDidLeaveRoomNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidJoinRoom:) name:LocalUserDidJoinRoomNotification object:nil];
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UsersManager defaultManager] unsubscribeForUpdates:self];
}


#pragma mark - Subscription management

- (void)subscribeForUpdates:(id<UserActivityManagerListener>)object
{
	[_subscriptionManager subscribeObject:object];
}


- (void)unsubscribeForUpdates:(id<UserActivityManagerListener>)object
{
	[_subscriptionManager unsubscribeObject:object];
}


#pragma mark -

- (void)deliveryStatusNotificationReceived:(NSNotification *)notification
{
	NSString *deliveredMId = [notification.userInfo objectForKey:kDeliveryStatusDeliveredMidKey];
	NSArray *seenMIds = [notification.userInfo objectForKey:kDeliveryStatusSeenIdsKey];
	
	NSMutableArray *activities = [NSMutableArray array];
	NSMutableArray *activitiesIndices = [NSMutableArray array];
	
	if ([seenMIds count]) {
		for (NSString *seenMid in seenMIds) {
			IndexedChatMessageActivity *indexedChatMessage = [_notSeenSelfMessages objectForKey:seenMid];
			if (indexedChatMessage) {
				indexedChatMessage.chatMessage.deliveryStatus = kChatMessageDeliveryStatusRemoteSeen;
				[activities addObject:indexedChatMessage.chatMessage];
				[activitiesIndices addObject:@(indexedChatMessage.index)];
				[_notSeenSelfMessages removeObjectForKey:seenMid];
			}
		}
	}
	
	if ([deliveredMId length] > 0) {
		IndexedChatMessageActivity *indexedChatMessage = [_notSeenSelfMessages objectForKey:deliveredMId];
		if (indexedChatMessage) {
			indexedChatMessage.chatMessage.deliveryStatus = kChatMessageDeliveryStatusRemoteReceived;
			[activities addObject:indexedChatMessage.chatMessage];
			[activitiesIndices addObject:@(indexedChatMessage.index)];
		}
	}
	
	[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(userActivityManager:didUpdateActivities:atIndices:)]) {
			[obj userActivityManager:self didUpdateActivities:activities atIndices:activitiesIndices];
		}
	}];
}


#pragma mark - UserAvailability management

- (void)setIsUserAvailable:(BOOL)isUserAvailable
{
	if (_isUserAvailable != isUserAvailable) {
		_isUserAvailable = isUserAvailable;
		if (_isUserAvailable) {
			[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
				if ([obj respondsToSelector:@selector(userActivityManagerDidBecomeActive:)]) {
					[obj userActivityManagerDidBecomeActive:self];
				}
			}];
		} else {
			[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
				if ([obj respondsToSelector:@selector(userActivityManagerDidBecomeInactive:)]) {
					[obj userActivityManagerDidBecomeInactive:self];
				}
			}];
		}
	}
}


- (void)userSessionHasJoinedRoom:(User *)user
{
	if ([user.sessionId isEqualToString:self.userSessionId]) {
		self.isUserAvailable = YES;
	}
}


- (void)userSessionHasLeft:(User *)user disconnectedFromServer:(BOOL)yesNo
{
	NSString *buddyLeftId = user.sessionId;
	if ([buddyLeftId isEqualToString:self.userSessionId] &&
		![[UsersManager defaultManager] userForSessionId:buddyLeftId]) {
		
		self.isUserAvailable = NO;
	}
}


- (void)roomUsersListUpdated
{
    if ([[UsersManager defaultManager] userForSessionId:_userSessionId]) {
        self.isUserAvailable = YES;
    } else {
        if ([[UsersManager defaultManager] wasRoomVisited:_userSessionId] &&
			[_userSessionId isEqualToString:[UsersManager defaultManager].currentUser.room.name]) {
			
			self.isUserAvailable = YES;
        } else {
            self.isUserAvailable = NO;
        }
    }
}


- (void)localUserDidLeaveRoom:(NSNotification *)notification
{
	SMRoom *oldRoom = [notification.userInfo objectForKey:kRoomUserInfoKey];
	if ([oldRoom.name isEqualToString:self.userSessionId]) {
		self.isUserAvailable = NO;
	}
}


- (void)localUserDidJoinRoom:(NSNotification *)notification
{
	SMRoom *newRoom = [notification.userInfo objectForKey:kRoomUserInfoKey];
	if ([newRoom.name isEqualToString:self.userSessionId]) {
		self.isUserAvailable = YES;
	}
}


#pragma mark -

- (NSArray *)userActivity
{
	return [NSArray arrayWithArray:_userActivityArray];
}


- (void)addUserActivityToHistory:(id<UserRecentActivity>)recentActivity
{
	_lastUserActivityDate = [NSDate date];
	_lastDayLimitedDateString = [[UsersActivityController sharedInstance] dayLimitedDateStringForDate:_lastUserActivityDate];
	
	NSInteger previousActivityIndex = [_userActivityArray count] - 1;
	if (previousActivityIndex >= 0) {
		id<UserRecentActivity> previousActivity = [_userActivityArray objectAtIndex:previousActivityIndex];
		
		BOOL shouldGroupAutomatticalyRecent = YES;
		if ([recentActivity respondsToSelector:@selector(shouldNotGroupAutomatically)]) {
			shouldGroupAutomatticalyRecent = ![recentActivity shouldNotGroupAutomatically];
		}
		BOOL shouldGroupAutomatticalyPrevious = YES;
		if ([previousActivity respondsToSelector:@selector(shouldNotGroupAutomatically)]) {
			shouldGroupAutomatticalyPrevious = ![previousActivity shouldNotGroupAutomatically];
		}

		
		if ([[previousActivity from] isEqualToString:[recentActivity from]] &&
			fabs([[previousActivity date] timeIntervalSinceReferenceDate] - [[recentActivity date] timeIntervalSinceReferenceDate]) < 60.0 &&
			shouldGroupAutomatticalyRecent && shouldGroupAutomatticalyPrevious ) {
			[previousActivity setIsEndOfGroup:NO];
			[recentActivity setIsStartOfGroup:NO];
			[recentActivity setIsEndOfGroup:YES];
		} else {
			[previousActivity setIsEndOfGroup:YES];
			[recentActivity setIsStartOfGroup:YES];
			[recentActivity setIsEndOfGroup:YES];
		}
		
	} else {
		[recentActivity setIsStartOfGroup:YES];
		[recentActivity setIsEndOfGroup:YES];
	}
	
	[_userActivityArray addObject:recentActivity];
	
	
	NSInteger indexOfAddedActivity = [_userActivityArray count] - 1;
	
	[self optionalActivityCheck:recentActivity atIndex:indexOfAddedActivity];
	
	[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(userActivityManager:didAddActivity:atIndex:)]) {
			[obj userActivityManager:self didAddActivity:recentActivity atIndex:indexOfAddedActivity];
		}
	}];
}


- (void)purgeAllHistory
{
	[_userActivityArray removeAllObjects];
}


- (NSInteger)getNumberOfUnreadMessages
{
	return [_userActivityArray count] - _numberOfActivitiesSeenByUser;
}


- (id<UserRecentActivity>)activityAtIndex:(NSInteger)index
{
	id<UserRecentActivity> activity = nil;
	
	if (index >= 0 && index < [_userActivityArray count]) {
		activity = [_userActivityArray objectAtIndex:index];
	}
		
	return activity;
}


- (NSUInteger)activitiesCount
{
	return [_userActivityArray count];
}


#pragma mark - Optional activities methods

- (void)optionalActivityCheck:(id<UserRecentActivity>)activity atIndex:(NSInteger)index
{
	if ([activity isKindOfClass:[ChatMessage class]]) {
		ChatMessage *chatMessageActivity = (ChatMessage *)activity;
		
		[self optionalCheckChatMessage:chatMessageActivity atIndex:index];
	}
}


- (void)optionalCheckChatMessage:(ChatMessage *)chatMessageActivity atIndex:(NSInteger)index
{
	if (chatMessageActivity.deliveryStatus != kChatMessageDeliveryStatusRemoteMessage &&
		chatMessageActivity.deliveryStatus != kChatMessageDeliveryStatusRemoteSeen &&
		[chatMessageActivity.mId length] > 0) {
		IndexedChatMessageActivity *indexedActivity = [IndexedChatMessageActivity indexedChatMessageActivityWithChatMessage:chatMessageActivity atIndex:index];
		[_notSeenSelfMessages setObject:indexedActivity forKey:chatMessageActivity.mId];
	}
}


#pragma mark - UserRecentActivityControllerUpdatesListener implementation

- (void)userActivityController:(UsersActivityController *)controller
				 userSessionId:(NSString *)userSessionId
			   hasBeenActiveAt:(NSString *)dayLimitedDateString
		   movedOnTopFromIndex:(NSUInteger)fromIndex
{
	if ([userSessionId isEqualToString:_userSessionId]) {
		
	}
}


@end
