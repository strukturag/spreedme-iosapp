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

#import "SMNetworkDataStatisticsController.h"

#import "AES256Encryptor.h"
#import "JSONKit.h"
#import "NSData+Conversion.h"
#import "SMAppIdentityController.h"
#import "utils_objc.h"

@implementation SMNetworkDataStatisticsController

+ (NSString *)savedStatisticsDir
{
	NSString *appSupportDir = applicationSupportDirectory();
	
	NSString *savedStatisticsDir = nil;
	if (appSupportDir.length > 0) {
		savedStatisticsDir = [appSupportDir stringByAppendingPathComponent:kSTNetworkDataSaveDirInAppSupportDir];
        
        BOOL isDirectory = YES;
        if (![[NSFileManager defaultManager] fileExistsAtPath:savedStatisticsDir isDirectory:&isDirectory]) {
            NSError *error = nil;
            BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:savedStatisticsDir withIntermediateDirectories:YES attributes:nil error:&error];
            if (!succes) {
                spreed_me_log("We couldn't create directory to store network statistics!");
            } else {
                return nil;
            }
        }
	}
	
	return savedStatisticsDir;
}


- (void)saveStatistics:(NSDictionary *)jsonRepresentedDict toDir:(NSString *)dir
{
	NSString *jsonString = [jsonRepresentedDict JSONString];
	if (jsonString.length > 0) {
		
		NSData *stringData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
		
		AES256Encryptor *encr = [[AES256Encryptor alloc] init];
		[encr saveDataEncrypted:stringData
				   withPassword:[[[SMAppIdentityController sharedInstance] appBigIdentifier] hexadecimalString]
						  toDir:dir];
		
	} else {
		spreed_me_log("Couldn't create json string from stat data");
	}
}


- (NSDictionary *)loadJsonRepresentedStatisticsFromDir:(NSString *)dir
{
	AES256Encryptor *encr = [[AES256Encryptor alloc] init];
	NSData *decrData = [encr loadDataFromEncryptedFileInDir:dir
											   withPassword:[[[SMAppIdentityController sharedInstance] appBigIdentifier] hexadecimalString]];
	
	if (decrData) {
		NSString *stringRep = [[NSString alloc] initWithData:decrData encoding:NSUTF8StringEncoding];
		NSDictionary *dict = [stringRep objectFromJSONString];
		
		if ([dict isKindOfClass:[NSDictionary class]]) {
			return dict;
		}
	}
	
	return nil;
}



@end
