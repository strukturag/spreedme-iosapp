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

#import "SMRoom.h"

NSString * const kSMRoomRoomDisplayNameKey		= @"SMRoomRoomDisplayName";
NSString * const kSMRoomRoomNameKey				= @"SMRoomRoomName";


NSString * const DefaultRoomId				= @"";


static NSString * DefaultRoomName = nil;

@implementation SMRoom

+ (void)initialize
{
	if (self == [SMRoom class]) {
		DefaultRoomName = NSLocalizedStringWithDefaultValue(@"label_default-room-name",
															nil, [NSBundle mainBundle],
															@"Default Room",
															@"Default room. Room with empty name whihc was the default place user was put after login. ");
	}
}


+ (NSString *)defaultRoomName
{
	return DefaultRoomName;
}


+ (instancetype)roomWithDictionary:(NSDictionary *)roomDict
{
	if (!roomDict) {
		return nil;
	}
	
	SMRoom *room = [[SMRoom alloc] init];
	room.name = [roomDict objectForKey:kSMRoomRoomNameKey];
	room.displayName = [roomDict objectForKey:kSMRoomRoomDisplayNameKey];
	
	if (room.name) {
		return room;
	}
	
	return nil;
}


+ (instancetype)defaultRoomInstance
{
	SMRoom *room = [[SMRoom alloc] init];
	room.name = DefaultRoomId;
	room.displayName = DefaultRoomName;
	return room;
}


- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
	// We don't expect room name or displayName to be nil
	[dict setObject:self.name forKey:kSMRoomRoomNameKey];
	[dict setObject:self.displayName forKey:kSMRoomRoomDisplayNameKey];
	
	return [NSDictionary dictionaryWithDictionary:dict];
}


@end
