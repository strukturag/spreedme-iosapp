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

#import "ResourceDownloadManager.h"

@interface ResourceDownloadTask : NSObject
@property (nonatomic, copy) NSURL *url;
@property (nonatomic, copy) ResourceDownloadCompletionBlock block;

@property (nonatomic, assign) uint64_t number;
@property (nonatomic, copy) NSString *hostKey;

@property (nonatomic, assign) NSUInteger contextNumber; // This is used for iOS7 NSURLSessionTask number. This number is only valid in limited context and intended for internal use

@property (nonatomic, unsafe_unretained) void *pointer;

@end
