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

#import "NonRetainSubscriptionManager.h"


@interface NonRetainObjectWrapper : NSObject
{
	id __unsafe_unretained _object;
}

@property (nonatomic, assign) id object;

- (instancetype)initWithObject:(id)object;

@end

@implementation NonRetainObjectWrapper

- (instancetype)initWithObject:(id)object
{
	self = [super init];
	if (self) {
		if (object) {
			_object = object;
		} else {
			return nil;
		}
	}
	return self;
}


- (instancetype)init
{
	self = [super init];
	return nil;
}


- (NSUInteger)hash
{
	return [_object hash];
}


- (BOOL)isEqual:(id)object
{
	BOOL answer = NO;
	if ([object isKindOfClass:[self class]]) {
		NonRetainObjectWrapper *obj2 = (NonRetainObjectWrapper *)object;
		answer = [_object isEqual:obj2.object];
	}
	
	return answer;
}


- (NSString *)description
{
	NSString *desc = [super description];
	desc = [desc stringByAppendingFormat:@" - container object <%@>", [_object description]];
	return desc;
}

@end



@implementation NonRetainSubscriptionManager
{
	NSMutableSet *_subscibersPool;
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		_subscibersPool = [[NSMutableSet alloc] init];
	}
	return self;
}


- (void)subscribeObject:(id)object
{
	if (object) {
		NonRetainObjectWrapper *wrapper = [[NonRetainObjectWrapper alloc] initWithObject:object];
		[_subscibersPool addObject:wrapper];
	}
}


- (void)unsubscribeObject:(id)object
{
	if (object) {
		NonRetainObjectWrapper *wrapper = [[NonRetainObjectWrapper alloc] initWithObject:object];
		[_subscibersPool removeObject:wrapper];
	}
}


- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block
{
	return [_subscibersPool enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
		if (block) {
			NonRetainObjectWrapper *wrapper = (NonRetainObjectWrapper *)obj;
			block(wrapper.object, stop);
		}
	}];
}


@end
