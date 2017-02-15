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

extern NSString * const DefaultRoomId;


@interface SMRoom : NSObject

@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *name; // this is room id

+ (NSString *)defaultRoomName;

+ (instancetype)defaultRoomInstance; //Creates instance which represents default room

+ (instancetype)roomWithDictionary:(NSDictionary *)roomDict;
- (NSDictionary *)dictionaryRepresentation;

@end
