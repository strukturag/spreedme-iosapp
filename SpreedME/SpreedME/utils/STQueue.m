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

#import "STQueue.h"

@interface STQueue ()
{
	NSMutableArray *_array;
}


@end


@implementation STQueue


#pragma mark - Object lifecycle

- (instancetype)init
{
	self = [super init];
	if (self) {
		_array = [[NSMutableArray alloc] init];
		_length = NSUIntegerMax;
	}
	return self;
}


#pragma mark - Public methods

- (NSUInteger)size
{
	return [_array count];
}


- (void)push:(id)object
{
	if ([self canPushNewObject]) {
		[_array addObject:object];
	}
}


- (id)pop
{
	if ([_array count] == 0) {
        return nil;
    }
	
    id queueObject = [_array objectAtIndex:0];
	
    [_array removeObjectAtIndex:0];
	
    return queueObject;
}


- (id)peek
{
	if ([_array count] == 0) {
        return nil;
    }
	
    id queueObject = [_array objectAtIndex:0];
	
	return queueObject;
}


- (BOOL)canPushNewObject
{
	BOOL answer = [self size] < _length;
	return answer;
}


- (void)clear
{
	[_array removeAllObjects];
}


- (NSArray *)allObjects
{
	return [NSArray arrayWithArray:_array];
}


- (void)removeObject:(id)obj
{
	[_array removeObject:obj];
}


@end
