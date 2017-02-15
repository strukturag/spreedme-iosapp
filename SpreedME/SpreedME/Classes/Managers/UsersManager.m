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

#import "UsersManager.h"

#import "SortedDictionary/SortedDictionary/Public/MutableSortedDictionary.h"
#import "SortedDictionary/SortedDictionary/Public/SortedDictionaryEntry.h"

#import "AES256Encryptor.h"
#import "BuddyParser.h"
#import "ChatManager.h"
#import "JSONKit.h"
#import "NonRetainSubscriptionManager.h"
#import "NSString+SortedDictionaryAdditions.h"
#import "NSData+Conversion.h"
#import "SettingsController.h"
#import "SMAppIdentityController.h"
#import "SMConnectionController.h"
#import "SMDisplayUser.h"
#import "SMHmacHelper.h"
#import "STRandomStringGenerator.h"


@interface UsersManager ()
{
	NonRetainSubscriptionManager *_subscriptionManager;
	
	// Users
	// Room users
	NSMutableDictionary *_roomUsersKeyId;
	MutableSortedDictionary *_roomUsersKeySort;
	
	NSMutableDictionary *_roomDisplayUsersKeyUserId; // value-> SMDisplayUser object; key-> UserId of SMDisplayUser (not the same as User.userId)
	MutableSortedDictionary *_roomDisplayUsersKeySort; // value-> SMDisplayUser; key-> sortString of SMDisplayUser
	
	// Held users
	NSMutableDictionary *_heldUsersMap; // value->User key->User.sessionId
	
	// Parsing
	BuddyParser *_buddyParser;
	
	// Rooms
	NSMutableSet *_visitedRoomsNames;
	
	
	NSTimer *_cleanupTimer;
	NSTimeInterval _lastCleanupOfAttestedUsers; // since 1970
}

@end


@implementation UsersManager

#pragma mark - Init

+ (UsersManager *)defaultManager
{
	static dispatch_once_t once;
    static UsersManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		_subscriptionManager = [[NonRetainSubscriptionManager alloc] init];
		
		_roomUsersKeyId = [[NSMutableDictionary alloc] init];
		_roomUsersKeySort = [[MutableSortedDictionary alloc] init];
		_roomDisplayUsersKeyUserId = [[NSMutableDictionary alloc] init];
		_roomDisplayUsersKeySort = [[MutableSortedDictionary alloc] init];
		
		_heldUsersMap = [[NSMutableDictionary alloc] init];
		
		_buddyParser = [[BuddyParser alloc] init];
		
		_visitedRoomsNames = [[NSMutableSet alloc] init];
		
		_lastCleanupOfAttestedUsers = [[NSDate date] timeIntervalSince1970];
//		_cleanupTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(performCleanup:) userInfo:nil repeats:YES];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeActive:) name:ChannelingConnectionBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionBecomeInactive:) name:ChannelingConnectionBecomeInactiveNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyImageHasChanged:) name:BuddyImageHasBeenUpdatedNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserDidJoinRoom:) name:LocalUserDidJoinRoomNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserHasBeenUpdated:) name:UserHasChangedDisplayNameNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserHasBeenUpdated:) name:UserHasChangedStatusMessageNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localUserHasBeenUpdated:) name:UserHasChangedDisplayImageNotification object:nil];
        
		// We no longer need to ask users list on init here since UsersManager is instantiated before any connections made.
		
		// We no longer need to add user current room to visited rooms list on init here since UsersManager is instantiated before any connections made.
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - Users methods Public

#pragma mark - Saved users management

- (SMLocalUser *)loadUserFromDir:(NSString *)dir
{
	SMLocalUser *user = [SMLocalUser localUserFromDir:dir];
	return user;
}


- (BOOL)saveUser:(SMLocalUser *)localUser toDir:(NSString *)dir
{
	BOOL success = [localUser saveToDir:dir];
	return success;
}


- (NSString *)savedUsersDirectory
{
	NSString *savedUsersDirectory = nil;
	
	NSString *appSupportDir = applicationSupportDirectory();
	if (appSupportDir) {
		savedUsersDirectory = [appSupportDir stringByAppendingPathComponent:@"users"];
		
		BOOL isDirectory = YES;
		if (![[NSFileManager defaultManager] fileExistsAtPath:savedUsersDirectory isDirectory:&isDirectory]) {
			NSError *error = nil;
			BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:savedUsersDirectory withIntermediateDirectories:YES attributes:nil error:&error];
			if (!succes) {
				spreed_me_log("We couldn't create directory to store users!");
			} else {
				return nil;
			}
		}
	}
	
	return savedUsersDirectory;
}


- (void)saveCurrentUser
{
	SMLocalUser *userToSave = self.currentUser;
			
	if (userToSave) {
		NSString *userId = userToSave.userId;
		if (userId.length == 0) {
			userId = [[SMAppIdentityController sharedInstance] defaultUserUID];
		}
		
		NSString *hashedName = [SMHmacHelper sha256Hash:userId];
		NSString *dir = [[self savedUsersDirectory] stringByAppendingPathComponent:hashedName];
		BOOL success = [self saveUser:userToSave toDir:dir];
		if (!success) {
			spreed_me_log("Couldn't save current user!");
		}
	}
}


- (void)deleteAllSavedUsers
{
	NSString *dir = [self savedUsersDirectory];
	NSArray *userDirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
	
	for (NSString *userDir in userDirs) {
		NSString *fullDirPath = [dir stringByAppendingPathComponent:userDir];
		NSError *error = nil;
		BOOL success = [[NSFileManager defaultManager] removeItemAtPath:fullDirPath error:&error];
		if (!success) {
			spreed_me_log("Couldn't delete user dir at path %s", [fullDirPath cDescription]);
		}
	}
	
}


- (void)setCurrentUser:(SMLocalUser *)currentUser
{
	if (_currentUser != currentUser) {
		_currentUser = currentUser;
				
		if (_currentUser.room) {
			[_visitedRoomsNames addObject:_currentUser.room.name];
		}
		
		[[NSNotificationCenter defaultCenter] postNotificationName:UserHasBeenChangedNotification
															object:self
														  userInfo:nil];
	}
}


#pragma mark - ALL tiers methods

- (User *)userForSessionId:(NSString *)sessionId
{
	User *user = nil;
	
	user = [self roomUserForSessionId:sessionId];
		
	if (!user) {
		user = [self heldUserForSessionId:sessionId];
	}
	
	return user;
}


- (NSString *)userDisplayNameForSessionId:(NSString *)userSessionId
{
	NSString *displayName = nil;
	
	displayName = [self roomUserDisplayNameForSessionId:userSessionId];
		
	if (!displayName) {
		displayName = [self heldUserDisplayNameForSessionId:userSessionId];
	}
	
	return displayName;
}


- (NSString *)userBase64ImageForSessionId:(NSString *)userSessionId
{
	NSString *base64image = nil;
	
	base64image = [self roomUserBase64ImageForSessionId:userSessionId];
		
	if (!base64image) {
		base64image = [self heldUserBase64ImageForSessionId:userSessionId];
	}
	
	return base64image;

}


- (UIImage *)userImageForSessionId:(NSString *)userSessionId
{
	UIImage *image = nil;
	
	image = [self roomUserImageForSessionId:userSessionId];
		
	if (!image) {
		image = [self heldUserImageForSessionId:userSessionId];
	}
	
	return image;
}


#pragma mark - ROOM 1 tier

- (User *)roomUserForSessionId:(NSString *)userSessionId
{
	return [_roomUsersKeyId objectForKey:userSessionId];
}


- (NSString *)roomUserDisplayNameForSessionId:(NSString *)userSessionId
{
	User *buddy = [self roomUserForSessionId:userSessionId];
	return buddy.displayName;
}

- (NSString *)roomUserBase64ImageForSessionId:(NSString *)userSessionId
{
	User *buddy = [self roomUserForSessionId:userSessionId];
	return buddy.base64Image;
}

- (UIImage *)roomUserImageForSessionId:(NSString *)userSessionId
{
	User *buddy = [self roomUserForSessionId:userSessionId];
	return buddy.iconImage;
}


- (NSArray *)roomUsersSortedByDisplayName
{
	return [_roomUsersKeySort allValues];
}


- (NSUInteger)roomUsersCount
{
	return [_roomUsersKeyId count];
}


- (User *)roomUserForIndex:(NSUInteger)index
{
	return [self roomUserForIndex:index withSortOrder:kBuddySortOrderByDisplayName];
}


- (User *)roomUserForIndex:(NSUInteger)index withSortOrder:(BuddySortOrder)buddySortOrder
{
	NSString *keyAtIndex = [[_roomUsersKeySort allKeys] objectAtIndex:index];
	
	return [_roomUsersKeySort objectForKey:keyAtIndex];
}


- (NSArray *)roomDisplayUsersSortedByDisplayName
{
	return [_roomDisplayUsersKeySort allValues];
}


- (NSUInteger)roomDisplayUsersCount
{
	return [_roomDisplayUsersKeyUserId count];
}


- (SMDisplayUser *)roomDisplayUserForIndex:(NSUInteger)index
{
	return [self roomDisplayUserForIndex:index withSortOrder:kBuddySortOrderByDisplayName];
}


- (SMDisplayUser *)roomDisplayUserForIndex:(NSUInteger)index withSortOrder:(BuddySortOrder)buddySortOrder
{
	NSString *keyAtIndex = [[_roomDisplayUsersKeySort allKeys] objectAtIndex:index];
	
	return [_roomDisplayUsersKeySort objectForKey:keyAtIndex];
}


- (SMDisplayUser *)roomDisplayUserForUserId:(NSString *)userId
{
    return [_roomDisplayUsersKeyUserId objectForKey:userId];
}


#pragma mark - HELD users 2 tier

- (User *)heldUserForSessionId:(NSString *)sessionId
{
	return [_heldUsersMap objectForKey:sessionId];
}


- (NSString *)heldUserDisplayNameForSessionId:(NSString *)userSessionId
{
	User *heldUser = [self heldUserForSessionId:userSessionId];
	return heldUser.displayName;
}


- (NSString *)heldUserBase64ImageForSessionId:(NSString *)userSessionId
{
	User *heldUser = [self heldUserForSessionId:userSessionId];
	return heldUser.base64Image;
}


- (UIImage *)heldUserImageForSessionId:(NSString *)userSessionId
{
	User *heldUser = [self heldUserForSessionId:userSessionId];
	return heldUser.iconImage;
}


- (void)holdUser:(User *)user forSessionId:(NSString *)sessionId
{
	[_heldUsersMap setObject:user forKey:sessionId];
}


- (void)releaseHeldUserForSessionId:(NSString *)sessionId
{
	[_heldUsersMap removeObjectForKey:sessionId];
}


#pragma mark - Rooms management

- (void)addVisitedRoom:(NSString *)roomName
{
	[_visitedRoomsNames addObject:roomName];
}


- (BOOL)wasRoomVisited:(NSString *)roomName
{
	return [_visitedRoomsNames containsObject:roomName];
}


- (void)localUserDidJoinRoom:(NSNotification *)notification
{
	SMRoom *newRoom = [notification.userInfo objectForKey:kRoomUserInfoKey];
	[_visitedRoomsNames addObject:newRoom.name];
}


- (void)removeRoomUsers
{
    [self purgeRoomUsers];
    [self purgeRoomDisplayUsers];
    
    [self sendRoomUsersListUpdate];
}


#pragma mark - Subscriptions Public

- (void)subscribeForUpdates:(id<UserUpdatesProtocol>)observer
{
	if (observer && [observer conformsToProtocol:@protocol(UserUpdatesProtocol)]) {
		[_subscriptionManager subscribeObject:observer];
	}
}


- (void)unsubscribeForUpdates:(id<UserUpdatesProtocol>)observer
{
	if (observer && [observer conformsToProtocol:@protocol(UserUpdatesProtocol)]) {
		[_subscriptionManager unsubscribeObject:observer];
	}
}


#pragma mark - Subsciptions Private

- (void)sendRoomSessionsListReceivedUpdate
{
	[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(roomSessionsListReceived)]) {
			[obj roomSessionsListReceived];
		}
	}];
}


- (void)sendUserSessionJoinedUpdate:(User *)user
{
	if (user) {
		[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			if ([obj respondsToSelector:@selector(userSessionHasJoinedRoom:)]) {
				[obj userSessionHasJoinedRoom:user];
			}
		}];
	}
}


- (void)sendUserSessionLeftUpdate:(User *)user disconnectedFromServer:(BOOL)yesNo
{
	if (user) {
		[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			if ([obj respondsToSelector:@selector(userSessionHasLeft:disconnectedFromServer:)]) {
				[obj userSessionHasLeft:user disconnectedFromServer:yesNo];
			}
		}];
	}
}


- (void)sendRoomUsersListUpdate
{
	[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if ([obj respondsToSelector:@selector(roomUsersListUpdated)]) {
			[obj roomUsersListUpdated];
		}
	}];
}


- (void)sendUserUpdateForUser:(User *)user
{
	if (user) {
		[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			if ([obj respondsToSelector:@selector(userHasBeenUpdated:)]) {
				[obj userHasBeenUpdated:user];
			}
		}];
	}
}


- (void)sendDisplayUserUpdateForDisplayUser:(SMDisplayUser *)displayUser
{
	if (displayUser) {
		[_subscriptionManager enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
			if ([obj respondsToSelector:@selector(displayUserHasBeenUpdated:)]) {
				[obj displayUserHasBeenUpdated:displayUser];
			}
		}];
	}
}


#pragma mark - Utilities

- (void)addRoomUser:(User *)roomUser displayUser:(SMDisplayUser *)displayUserHint
{
	if (![_roomUsersKeyId objectForKey:roomUser.sessionId]) {
		[_roomUsersKeyId setObject:roomUser forKey:roomUser.sessionId];
	} else {
		
	}

	NSString *buddySortKey = [roomUser sortString];
	if (![_roomUsersKeySort objectForKey:buddySortKey]) {
		[_roomUsersKeySort setObject:roomUser forKey:buddySortKey];
	} else {
		
	}
	
	SMDisplayUser *displayUser = nil;
	if (displayUserHint) {
		displayUser = displayUserHint;
		[_roomDisplayUsersKeySort removeObjectForKey:[displayUser sortString]];
		[displayUser addUserSession:roomUser];
		[_roomDisplayUsersKeyUserId setObject:displayUser forKey:displayUser.Id];
	} else {
		if (roomUser.userId) {
			displayUser = [_roomDisplayUsersKeyUserId objectForKey:roomUser.userId];
			if (!displayUser) {
				BOOL isAnotherOwnSession = [roomUser.userId isEqualToString:[UsersManager defaultManager].currentUser.userId];
				SMDisplayUserType dispUserType = kSMDisplayUserTypeRegistered;
				
                if (isAnotherOwnSession) {
					dispUserType = kSMDisplayUserTypeAnotherOwnSession;
				}
                
				displayUser = [SMDisplayUser displayUserWithType:dispUserType];
				[displayUser addUserSession:roomUser];
			} else {
				[_roomDisplayUsersKeySort removeObjectForKey:[displayUser sortString]];
				[displayUser addUserSession:roomUser];
			}
			
			[_roomDisplayUsersKeyUserId setObject:displayUser forKey:displayUser.Id];
			
		} else {
			displayUser = [SMDisplayUser displayUserWithType:kSMDisplayUserTypeAnonymous];
			[displayUser addUserSession:roomUser];
			[_roomDisplayUsersKeyUserId setObject:displayUser forKey:displayUser.Id];
		}
	}
	
	if (displayUser) {
		[_roomDisplayUsersKeySort setObject:displayUser forKey:[displayUser sortString]];
	}
}


- (SMDisplayUser *)removeRoomUser:(User *)roomUser
{
	BOOL removedFromIdDic = NO;
	BOOL removedFromSortDic = NO;
	
	if ([_roomUsersKeyId objectForKey:roomUser.sessionId]) {
		[_roomUsersKeyId removeObjectForKey:roomUser.sessionId];
		removedFromIdDic = YES;
	}
	
	if ([_roomUsersKeySort objectForKey:[roomUser sortString]]) {
		[_roomUsersKeySort removeObjectForKey:[roomUser sortString]];
		removedFromSortDic = YES;
	}
	
	SMDisplayUser *displayUser = nil;
	if (roomUser.userId) {
		displayUser = [_roomDisplayUsersKeyUserId objectForKey:roomUser.userId];
		if (displayUser) {
			// sort string can change so delete displayUser here and readd it, if appropriate, later
			[_roomDisplayUsersKeySort removeObjectForKey:[displayUser sortString]];
			
			[displayUser removeUserSessionWithId:roomUser.sessionId];
			if (displayUser.userSessions.count > 0) {
				[_roomDisplayUsersKeyUserId setObject:displayUser forKey:displayUser.Id];
				
				// sort string could have changed, readd displayUser
				[_roomDisplayUsersKeySort setObject:displayUser forKey:[displayUser sortString]];
			} else {
				[_roomDisplayUsersKeyUserId removeObjectForKey:roomUser.userId];
			}
		}
	} else {
		displayUser = [_roomDisplayUsersKeyUserId objectForKey:roomUser.sessionId];
		if (displayUser) {
			[_roomDisplayUsersKeyUserId removeObjectForKey:roomUser.sessionId];
			
			[_roomDisplayUsersKeySort removeObjectForKey:[displayUser sortString]];
		}
	}
    
    if (displayUser.userSessions.count == 1) {
        displayUser = nil;
    }
    
	return displayUser;
}


- (void)purgeRoomUsers
{
	[_roomUsersKeyId removeAllObjects];
	[_roomUsersKeySort removeAllObjects];
}


- (void)purgeRoomDisplayUsers
{
	[_roomDisplayUsersKeyUserId removeAllObjects];
	[_roomDisplayUsersKeySort removeAllObjects];
}


- (void)performCleanup:(NSTimer *)theTimer
{
	NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
	
	if (fabs(now - _lastCleanupOfAttestedUsers) > 10 * 60.0) {
		_lastCleanupOfAttestedUsers = now;
		
		NSMutableArray *attestedUsersToRelease = [NSMutableArray array];
		
		for (NSString *sessionId in _heldUsersMap) {
			User *user = [_heldUsersMap objectForKey:sessionId];
			if (fabs(user.lastUpdate - now) > 10 * 60.0 ) {
				[attestedUsersToRelease addObject:user];
			}
		}
		
		for (User *user in attestedUsersToRelease) {
			[self releaseHeldUserForSessionId:user.sessionId];
		}
	}
}


#pragma mark - #pragma mark - Buddy handling Private Notifications

- (void)appicationWillResignActive:(NSNotification *)notification
{
	[self saveCurrentUser];
}


- (void)connectionBecomeActive:(NSNotification *)notification
{

}


- (void)connectionBecomeInactive:(NSNotification *)notification
{
	[self purgeRoomUsers];
    [self purgeRoomDisplayUsers];
	[self sendRoomUsersListUpdate];
}


- (void)userSessionHasJoined:(User *)user
{
	/*
	 There can be the situation when buddy has already left and reconnected but server couldn't manage that 
	 and sent 'buddy joined' event but not 'buddy left' so we have 2 same users. We should check against that.
	 */
	User *checkBuddy = [self roomUserForSessionId:user.sessionId];
	
	if (checkBuddy) {
		//TODO: Make correct checks
		
		if ([user.displayName length] == 0) {
			user.displayName = checkBuddy.displayName;
		}
		if ([user.base64Image length] == 0) {
			user.base64Image = checkBuddy.base64Image;
			user.iconImage = checkBuddy.iconImage;
		}
		
		[self removeRoomUser:checkBuddy];
	}
	
	if (user) {
        [self addRoomUser:user displayUser:nil];
		[self sendRoomUsersListUpdate];
		[self sendUserSessionJoinedUpdate:user];
	}
}


- (void)userSessionHasLeft:(NSString *)sessionId leftType:(NSString *)leftType
{
	User *buddyLeft = [self roomUserForSessionId:sessionId];
	
	if (buddyLeft) {
		[self removeRoomUser:buddyLeft];
		
		[self sendRoomUsersListUpdate];
	}

	//We should probably keep held users forever.
//	if ([leftType isEqualToString:NSStr(kLCHardKey)]) {
//		buddyLeft = [self heldUserForSessionId:sessionId];
//		if (buddyLeft) {
//			[self releaseHeldUserForSessionId:sessionId];
//		}
//	}
	
	if (buddyLeft) {
		[self sendUserSessionLeftUpdate:buddyLeft
				 disconnectedFromServer:[leftType isEqualToString:NSStr(kLCHardKey)]];
	}
}


- (void)userSessionStatusUpdateReceived:(NSDictionary *)info
{
	// TODO: optimize this. At the moment after receiveing status update
	// we send update for the whole list which shouldn't be the case.
	// We could do better by checking if display name has changed and track changes
	// of indices in the list.
    	
    NSString *userSessionId = [[info objectForKey:NSStr(kIdKey)] isKindOfClass:
							   [NSString class]] ? [info objectForKey:NSStr(kIdKey)] :
													[[info objectForKey:NSStr(kIdKey)] stringValue];
	uint64_t statusRevision = [[info objectForKey:NSStr(kRevKey)] unsignedLongLongValue];
	
	
	User *buddyToUpdate = [self roomUserForSessionId:userSessionId];
	
	if (buddyToUpdate.statusRevision > statusRevision) {
		spreed_me_log("User status revision is more recent than revision of status update. Do not update.");
		return;
	}
	
	
    SMDisplayUser *userToUpdate = nil;
    
    if (buddyToUpdate.userId) {
        userToUpdate = [_roomDisplayUsersKeyUserId objectForKey:buddyToUpdate.userId];
    } else {
        userToUpdate = [_roomDisplayUsersKeyUserId objectForKey:buddyToUpdate.sessionId];
    }
    
    [_roomDisplayUsersKeySort removeObjectForKey:[userToUpdate sortString]];
    
    
	if (buddyToUpdate) {
		SMDisplayUser *dispUserHint = [self removeRoomUser:buddyToUpdate];
		
		NSString *userId = [info objectForKey:NSStr(kUserIdKey)];
		[_buddyParser updateBuddy:buddyToUpdate
				   withDictionary:[info objectForKey:NSStr(kStatusKey)]
						 withType:kBuddyDictionaryTypeStatus
						   userId:userId
				   statusRevision:statusRevision];
		[self addRoomUser:buddyToUpdate displayUser:dispUserHint];
			
//        [_roomDisplayUsersKeySort setObject:userToUpdate forKey:[userToUpdate sortString]];
	}
    
	[self sendRoomUsersListUpdate];
	[self sendUserUpdateForUser:buddyToUpdate];
}


- (void)buddyImageHasChanged:(NSNotification *)notification
{
	NSString *userSessionId = [notification.userInfo objectForKey:UserSessionIdUserInfoKey];
	UIImage *buddyImage = [notification.userInfo objectForKey:BuddyImageUserInfoKey];
	NSNumber *imageRev = [notification.userInfo objectForKey:SMUserImageRevisionUserInfoKey];
	
	User *buddy = [self userForSessionId:userSessionId];
	
	if (buddy) {
		
		if (buddy.statusRevision > [imageRev unsignedLongLongValue]) {
			spreed_me_log("This image revision(%llu) is older than user revision (%llu). Do not update.", [imageRev unsignedLongLongValue], buddy.statusRevision);
			return;
		}
		
		buddy.iconImage = buddyImage;
		[self sendUserUpdateForUser:buddy];
		
		// Send update for display user
		SMDisplayUser *displayUser = nil;
		if (buddy.userId) {
			displayUser = [_roomDisplayUsersKeyUserId objectForKey:buddy.userId];
		} else {
			displayUser = [_roomDisplayUsersKeyUserId objectForKey:buddy.sessionId];
		}
		
		if (displayUser) {
			[self sendDisplayUserUpdateForDisplayUser:displayUser];
		}
	}
}


- (void)localUserHasBeenUpdated:(NSNotification *)notification
{
	if (notification.object == self.currentUser) {
		if ([SMConnectionController sharedInstance].connectionState == kSMConnectionStateConnected) {
			[[SMConnectionController sharedInstance].channelingManager sendStatusWithDisplayName:self.currentUser.displayName
																				   statusMessage:self.currentUser.statusMessage
																						 picture:self.currentUser.base64Image];
		}
	}
}


- (void)processRoomUserSessionsListMessage:(NSArray *)roomUserSessions
{
	NSArray *usersList = [_buddyParser createBuddyListFromUsersArray:roomUserSessions];
	
	[self purgeRoomUsers];
	[self purgeRoomDisplayUsers];
	
	if (usersList) {
		
		NSMutableArray *mutableBuddies = [NSMutableArray arrayWithArray:usersList];
		
		// TODO: Optimize
		User *selfToDelete = nil;
		for (User *buddy in mutableBuddies) {
			if ([self.currentUser.sessionId isEqual:buddy.sessionId]) {
				selfToDelete = buddy;
				break;
			}
		}
		if (selfToDelete) {
			[mutableBuddies removeObject:selfToDelete];
		}
		
		for (User *buddy in mutableBuddies) {
			[self addRoomUser:buddy displayUser:nil];
		}
	}
	
	[self sendRoomSessionsListReceivedUpdate];
	[self sendRoomUsersListUpdate];
}


- (void)processAttestationSessionsListMessage:(NSArray *)sessionsList
{
	for (NSDictionary *userDict in sessionsList) {
		
		NSString *sessionId = [userDict objectForKey:NSStr(kIdKey)];
		User *heldUser = [self heldUserForSessionId:sessionId];
		
		if (heldUser) {
			NSString *userId = [userDict objectForKey:NSStr(kUserIdKey)];
			NSDictionary *statusDict = [userDict objectForKey:NSStr(kStatusKey)];
			uint64_t statusRev = [[userDict objectForKey:NSStr(kRevKey)] unsignedLongLongValue];
			
			[_buddyParser updateBuddy:heldUser
					   withDictionary:statusDict
						withType:kBuddyDictionaryTypeUsers
							   userId:userId
					   statusRevision:statusRev];
			
			heldUser.lastUpdate = [[NSDate date] timeIntervalSince1970];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[self sendUserUpdateForUser:heldUser];
			});
		} else {
			spreed_me_log("No held user for attestation update");
		}
	}
}


#pragma mark - SMUsersManagementNotificationsProtocol

- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager
  hasReceivedSessionsList:(NSDictionary *)info
{
	if (info) {
	
		NSString *sessionsMessageType = [info objectForKey:NSStr(kTypeKey)];
		
		if ([sessionsMessageType isEqualToString:NSStr(kUsersKey)]) {
			
			NSArray *users = [info objectForKey:NSStr(kUsersKey)];
			
			[self processRoomUserSessionsListMessage:users];
			
		} else if ([sessionsMessageType isEqualToString:NSStr(kSessionsKey)]) {
			
			NSDictionary *sessionsSpecDict = [info objectForKey:NSStr(kSessionsKey)];
			NSString *tokenType = [sessionsSpecDict objectForKey:NSStr(kTypeKey)];
			NSString *token = [sessionsSpecDict objectForKey:NSStr(kTokenKey)];
			NSArray *sessionsList = [info objectForKey:NSStr(kUsersKey)];
			
			if ([tokenType isEqualToString:NSStr(kLCSessionKey)]) {
				[self processAttestationSessionsListMessage:sessionsList];
			} else {
				spreed_me_log("Unsupported attestation token type: %s", [tokenType cDescription]);
			}
		}
	}
}


- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager
hasReceivedUserSessionLeftEvent:(NSDictionary *)info
{
	if (info) {
		id sessionId = [info objectForKey:NSStr(kIdKey)];
		
		NSString *userSessionId = [sessionId isKindOfClass:[NSString class]] ? sessionId : [sessionId stringValue];
		NSString *leftType = [info objectForKey:NSStr(kStatusKey)];
		
		[self userSessionHasLeft:userSessionId leftType:leftType];
	}
}


- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager
hasReceivedUserSessionJoinedEvent:(NSDictionary *)info
{
	User *newUserSession = [_buddyParser createBuddyFromDictionary:info withType:kBuddyDictionaryTypeJoined];
	
	[self userSessionHasJoined:newUserSession];
}


- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager
hasReceivedUserSessionStatusEvent:(NSDictionary *)info
{
	[self userSessionStatusUpdateReceived:info];
}


- (void)channelingManager:(id<SMChannelingAPIInterface>)channelingManager
hasReceivedMessageWithAttestationToken:(NSDictionary *)info
{
	NSString *sessionId = [info objectForKey:NSStr(kIdKey)];
	NSString *attToken = [info objectForKey:NSStr(kAttestationTokenKey)];
	
	if (sessionId) {
		
		User *user = [self userForSessionId:sessionId];
		
		if (!user) {
			user = [[User alloc] init];
			user.sessionId = sessionId;
			user.displayName = [BuddyParser defaultUserDisplayNameForSessionId:sessionId];
			user.iconImage = [BuddyParser defaultUserImage];
			
			[self holdUser:user forSessionId:user.sessionId];
			
			[channelingManager sendSessionsRequestWithTokenType:NSStr(kLCSessionKey) token:attToken];
		}
	} else {
		spreed_me_log("Received empty sessionId claiming to be message with attestation token.");
	}
}


@end
