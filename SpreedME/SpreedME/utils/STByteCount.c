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

#include "STByteCount.h"

#ifdef __cplusplus
extern "C"
{
#endif

	
STByteCount STByteCountMakeZero()
{
	STByteCount zero = {0, 0};
	return zero;
};
	
	
STByteCount STByteCountMakeInvalid()
{
	STByteCount invalid = {ULLONG_MAX, ULLONG_MAX};
	return invalid;
};
	

int STByteCountsEqual(const STByteCount byteCount1, const STByteCount byteCount2)
{
	int equal = 0;
	if (byteCount1.bytes == byteCount2.bytes &&
		byteCount1.numberOf64BitOverflows == byteCount2.numberOf64BitOverflows) {
		equal = 1;
	}
	
	return equal;
};
	
	
void STAddBytesToByteCount(uint64_t bytes, STByteCount *byteCount)
{
	uint64_t remaining = ULLONG_MAX - byteCount->bytes;
	
	if (remaining < bytes) {
		
		uint64_t toAdd = bytes - remaining;
		byteCount->bytes = toAdd;
		byteCount->numberOf64BitOverflows += 1;
	} else {
		byteCount->bytes += bytes;
	}
};


void STAddByteCountToByteCount(const STByteCount byteCount, STByteCount *byteCountOut)
{
	byteCountOut->numberOf64BitOverflows += byteCount.numberOf64BitOverflows;
	STAddBytesToByteCount(byteCount.bytes, byteCountOut);
};
	
	
STByteCount STAddByteCounts(const STByteCount byteCount1, const STByteCount byteCount2)
{
	STByteCount total = {0,0};
	STAddByteCountToByteCount(byteCount1, &total);
	STAddByteCountToByteCount(byteCount2, &total);
	return total;
};
	
	
int STIsByteCountValid(STByteCount byteCount)
{
	int equal = 0;
	equal = !STByteCountsEqual(byteCount, STByteCountMakeInvalid());
	return equal;
};

	
#ifdef __cplusplus
} // extern C
#endif
