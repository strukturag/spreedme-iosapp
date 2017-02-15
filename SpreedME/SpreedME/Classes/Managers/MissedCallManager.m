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

#import "MissedCallManager.h"
#import "MissedCall.h"

@interface MissedCallManager ()
{
	NSMutableDictionary *_storage;
}


@end


@implementation MissedCallManager


+ (MissedCallManager *)sharedInstance
{
	static dispatch_once_t once;
    static MissedCallManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		_storage = [[NSMutableDictionary alloc] init];
	}
	return self;
}


- (NSArray *)missedCallsForUserSessionId:(NSString *)userSessionId
{
	NSArray *array = nil;
	if ([userSessionId length]) {
		array = [_storage objectForKey:userSessionId];
	}
	return [NSArray arrayWithArray:array];
}


- (MissedCall *)lastMissedCallForUserSessionId:(NSString *)userSessionId
{
	MissedCall *lastMissedCall = nil;
	if ([userSessionId length]) {
		NSArray *array = [_storage objectForKey:userSessionId];
		lastMissedCall = [array lastObject];
	}
	return lastMissedCall;
}


- (void)addMissedCall:(MissedCall *)missedCall forUserSessionId:(NSString *)userSessionId
{
	if ([userSessionId length] && missedCall) {
		NSMutableArray *calls = [_storage objectForKey:userSessionId];
		if (!calls) {
			calls = [NSMutableArray array];
		}
		
		if ([calls count] >= 10) {
			[calls removeObjectAtIndex:0];
			[calls addObject:missedCall];
		} else {
			[calls addObject:missedCall];
		}
		
		[_storage setObject:calls forKey:userSessionId];
	}
}


@end
