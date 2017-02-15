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

#import "NSData+XorData.h"

@implementation NSData (XorData)

- (NSData *)dataXORedWithData:(NSData *)xorData
{
	// Derived from SO post http://stackoverflow.com/questions/11724527/xor-file-encryption-in-ios
	NSMutableData *result = self.mutableCopy;

	uint8_t *dataPtr = (uint8_t *)result.mutableBytes;

	uint8_t *keyData = (uint8_t *)xorData.bytes;

	uint8_t *keyPtr = keyData;
	NSUInteger keyIndex = 0;
	// For each byte in data, xor with current value in key
	for (NSUInteger x = 0; x < self.length; x++) {
		*dataPtr = *dataPtr ^ *keyPtr;
		dataPtr++;
		keyPtr++;
		keyIndex++;
		// At end of key data wrap
		if (keyIndex >= xorData.length) {
			keyIndex = 0;
			keyPtr = keyData;
		}
	}
	return result;
}

@end
