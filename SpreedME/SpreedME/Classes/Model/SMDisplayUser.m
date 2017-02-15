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

#import "SMDisplayUser.h"


@interface SMDisplayUser ()
{
	NSMutableArray *_userSessions;
}
@end


@implementation SMDisplayUser

#pragma mark - Object lifecycle

- (instancetype)init
{
	self = nil;
	return nil;
}


- (instancetype)initWithType:(SMDisplayUserType)type
{
	self = [super init];
	if (self) {
		_userSessions = [[NSMutableArray alloc] init];
		_type = type;
	}
	
	return self;
}


+ (instancetype)displayUserWithType:(SMDisplayUserType)type
{
    return [(SMDisplayUser *)[self alloc] initWithType:type];
}


#pragma mark - Properties

- (NSString *)displayName
{
	User *userSession = nil;
    
	if (self.userSessions.count > 0) {
		userSession = [self.userSessions objectAtIndex:0];
	}
	
    if (!userSession.displayName) {
        userSession.displayName = @"";
    }
    
	return userSession.displayName;
}


- (NSString *)statusMessage
{
	User *userSession = nil;
	if (self.userSessions.count > 0) {
		userSession = [self.userSessions objectAtIndex:0];
	}
	
	return userSession.statusMessage;
}


- (UIImage *)iconImage
{
	User *userSession = nil;
	if (self.userSessions.count > 0) {
		userSession = [self.userSessions objectAtIndex:0];
	}
	
	return userSession.iconImage;
}


- (NSString *)Id
{
	User *userSession = nil;
	if (self.userSessions.count > 0) {
		userSession = [self.userSessions objectAtIndex:0];
	}
	
	NSString *Id = nil;
	switch (self.type) {
		case kSMDisplayUserTypeAnonymous:
			Id = userSession.sessionId;
		break;
		case kSMDisplayUserTypeRegistered:
        case kSMDisplayUserTypeAnotherOwnSession:
			Id = userSession.userId;
		break;
		default:
		break;
	}
	
	return Id;
}


#pragma mark - SMUserViewProtocol

- (NSString *)sessionId
{
    if (self.userSessions.count > 0) {
        return [[self.userSessions objectAtIndex:0] sessionId];
    }
    return nil;
}


- (SMUserViewType)userViewType
{
    SMUserViewType type = kSMUserViewTypeRegisteredUser;
    
    switch (self.type) {
        case kSMDisplayUserTypeAnonymous:
            type = kSMUserViewTypeAnonymousUser;
            break;
            
        case kSMDisplayUserTypeAnotherOwnSession:
            type = kSMUserViewTypeAnotherOwnSession;
            break;
        
        case kSMDisplayUserTypeRegistered:
            type = kSMUserViewTypeRegisteredUser;
            break;
            
        default:
            break;
    }
    
    return type;
}


- (NSString *)userId
{
    return self.Id;
}


#pragma mark - Public methods -
#pragma mark - UserSessions

- (NSArray *)userSessions
{
	return [NSArray arrayWithArray:_userSessions];
}


#pragma mark - Sort String

- (NSString *)sortString
{
	return [self.displayName stringByAppendingString:self.Id];
}


#pragma mark - User session management

- (void)addUserSession:(User *)userSession
{
	NSUInteger index = [_userSessions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		User *testUserSession = (User *)obj;
		return [testUserSession.sessionId isEqualToString:userSession.sessionId];
	}];
	
	if (index != NSNotFound) {
		[_userSessions removeObjectAtIndex:index];
		[_userSessions insertObject:userSession atIndex:0];
	} else {
		[_userSessions insertObject:userSession atIndex:0];
	}
}


- (void)removeUserSessionWithId:(NSString *)sessionId
{
	NSUInteger index = [_userSessions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		User *testUserSession = (User *)obj;
		return [testUserSession.sessionId isEqualToString:sessionId];
	}];
	
	if (index != NSNotFound) {
		[_userSessions removeObjectAtIndex:index];
	}
}


- (BOOL)hasUserSessionWithId:(NSString *)sessionId
{
	NSUInteger index = [_userSessions indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		User *testUserSession = (User *)obj;
		return [testUserSession.sessionId isEqualToString:sessionId];
	}];
	
	return (index != NSNotFound);
}


@end
