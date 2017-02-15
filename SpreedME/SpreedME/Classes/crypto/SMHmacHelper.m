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

#import "SMHmacHelper.h"

#import <CommonCrypto/CommonHMAC.h>

@implementation SMHmacHelper

- (NSString *)base64encHmacSHA256StringOfString:(NSString *)string withKey:(NSData *)key
{
	NSString *base64Hash = nil;
	
	if (string.length > 0 && key.length > 0) {
	
		NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
		NSMutableData* hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
		CCHmac(kCCHmacAlgSHA256,
			   key.bytes,
			   key.length,
			   stringData.bytes,
			   stringData.length,
			   hash.mutableBytes);
		
		base64Hash = [hash base64Encoding];
	}
	
	return base64Hash;
}


- (NSString *)base64encHmacSHA256StringOfString:(NSString *)string withStringKey:(NSString *)key
{
	NSString *base64Hash = nil;
	
	if (string.length > 0 && key.length > 0) {
		NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
		base64Hash = [self base64encHmacSHA256StringOfString:string withKey:keyData];
	}
	
	return base64Hash;
}


#pragma mark - Hashes

+ (NSString *)sha256Hash:(NSString *)input
{
    if (!input) {
        return nil;
    }
    
	const char *cstr = [input cStringUsingEncoding:NSUTF8StringEncoding];
	NSData *data = [NSData dataWithBytes:cstr length:input.length];
	uint8_t digest[CC_SHA256_DIGEST_LENGTH];
	
	// This is an iOS5-specific method.
	// It takes in the data, how much data, and then output format, which in this case is an int array.
	CC_SHA256(data.bytes, (uint32_t)data.length, digest);
	
	NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
	
	// Parse through the CC_SHA256 results (stored inside of digest[]).
	for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
		[output appendFormat:@"%02x", digest[i]];
	}
	
	return output;
}


@end
