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

#import "LoginManager.h"
#import "User.h"


typedef void (^GetUserDataCompletionBlock)(NSDictionary *jsonResponse, NSError *error);
typedef void (^GetAppTokenCompletionBlock)(NSDictionary *jsonResponse, NSError *error);


// Since we use this class only in SpreedMe security policy is 'SpreedMeStrictSSLSecurityPolicy'
@interface SMLoginManager : NSObject

+ (instancetype)sharedInstance;

- (LoginManagerOperation *)getUserComboUsername:(NSString *)userName
									   password:(NSString *)password
									   clientId:(NSString *)clientId
								   clientSecret:(NSString *)clientSecret
								completionBlock:(GetUserDataCompletionBlock)block;


- (LoginManagerOperation *)getAppTokenWithAccessToken:(NSString *)accessToken
										applicationId:(NSString *)applicationId
									  applicationName:(NSString *)appName
											 clientId:(NSString *)clientId
										 clientSecret:(NSString *)clientSecret
									  completionBlock:(GetAppTokenCompletionBlock)block;


- (LoginManagerOperation *)refreshUserComboAndSecretWithAppToken:(NSString *)apptoken
														clientId:(NSString *)clientId
													clientSecret:(NSString *)clientSecret
												 completionBlock:(GetUserDataCompletionBlock)block;


@end
