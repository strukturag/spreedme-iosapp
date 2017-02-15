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

#import "STPair.h"

@implementation STPair

- (instancetype)init
{
	self = [super init];
	self = nil;
	return nil;
}


- (instancetype)initWithKey:(id)key value:(id)value
{
	self = [super init];
	if (self) {
		if (key && value) {
			_key = key;
			_value = value;
		} else {
			self = nil;
			return nil;
		}
	}
	return self;
}


+ (instancetype)pairWithKey:(id)key value:(id)value
{
	return [[[self class] alloc] initWithKey:key value:value];
}

@end
