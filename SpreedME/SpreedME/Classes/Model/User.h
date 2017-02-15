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


@interface User : NSObject
{
	NSString *_sessionId;
	NSString *_secSessionId;
	NSString *_userId;
	NSString *_displayName;
	NSString *_Ua;
	NSString *_base64Image;
	NSString *_statusMessage;
	UIImage *_iconImage;
	BOOL _isMixer;
}



@property (nonatomic, strong) NSString *sessionId;
@property (nonatomic, strong) NSString *secSessionId;
@property (nonatomic, strong) NSString *userId;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *Ua;
@property (nonatomic, strong) NSString *base64Image;
@property (nonatomic, strong) NSString *statusMessage;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) BOOL isMixer;

@property (nonatomic, assign) uint64_t statusRevision;

@property (nonatomic, readwrite) NSTimeInterval lastUpdate; // should be as timeIntervalSince1970

- (NSString *)sortString;

@end
