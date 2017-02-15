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

#import "STRandomStringGenerator.h"


static NSString * const kSTRandomStringGeneratorAlphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
static NSString * const kSTRandomStringGeneratorAlphabetNoNumbers = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString * const kSTRandomStringGeneratorAlphabetLowercaseAndNumbers = @"abcdefghijklmnopqrstuvwxyz0123456789";
static NSString * const kSTRandomStringGeneratorAlphabetUppercaseAndNumbers = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";


@implementation STRandomStringGenerator

+ (NSString *)randomStringWithLength:(uint32_t)len alphabet:(NSString *)alphabet
{
	NSMutableString *randomString = [NSMutableString stringWithCapacity:len];
	
	for (uint32_t i = 0; i < len; i++) {
		[randomString appendFormat:@"%C", [alphabet characterAtIndex:arc4random() % alphabet.length]];
	}
	
	return randomString;
}


+ (NSString *)randomStringWithLength:(uint32_t)len
{
	return [self randomStringWithLength:len alphabet:kSTRandomStringGeneratorAlphabet];
}


@end
