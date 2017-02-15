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

#import "CommonNetDefinitions.h"
#import "User.h"

typedef void (^GetNonceCompletionBlock)(NSDictionary *jsonResponse, NSError *error);

@class AFHTTPRequestOperation;

@interface LoginManagerOperation : NSObject <STNetworkOperation>
@property (nonatomic, strong) AFHTTPRequestOperation *requestOperation;
- (void)cancel;
@end


@interface LoginManager : NSObject

+ (LoginManager *)sharedInstance;


- (LoginManagerOperation *)getNonceWithSessionId:(NSString *)sessionId
								 secureSessionId:(NSString *)secureSessionId
									 userIdCombo:(NSString *)userIdCombo
										  secret:(NSString *)secret
								 completionBlock:(GetNonceCompletionBlock)block;


@end
