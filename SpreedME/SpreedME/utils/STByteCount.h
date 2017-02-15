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

#ifndef __SpreedME__STByteCount__
#define __SpreedME__STByteCount__


#ifdef __cplusplus
extern "C"
{
#endif

#ifndef _UINT64_T
#define _UINT64_T
typedef unsigned long long uint64_t;
#endif /* _UINT64_T */

#ifndef ULLONG_MAX
#define	ULLONG_MAX	0xffffffffffffffffULL	/* max unsigned long long taken from Apple limits.h */
#endif
	
typedef struct STByteCount
{
	uint64_t bytes;
	uint64_t numberOf64BitOverflows; // number of counted ULLONG_MAX bytes
}
STByteCount; // total bytes are (numberOf64BitOverflows * ULLONG_MAX + bytes)

	
STByteCount STByteCountMakeZero();
STByteCount STByteCountMakeInvalid();
int STByteCountsEqual(const STByteCount byteCount1, const STByteCount byteCount2);

void STAddBytesToByteCount(uint64_t bytes, STByteCount *byteCount);
void STAddByteCountToByteCount(const STByteCount byteCount, STByteCount *byteCountOut);
STByteCount STAddByteCounts(const STByteCount byteCount1, const STByteCount byteCount2);

// STByteCount is valid if it is not equal to what is returned from STByteCountMakeInvalid()
int STIsByteCountValid(STByteCount byteCount);

#ifdef __cplusplus
} // extern C
#endif
	
#endif /* defined(__SpreedME__STByteCount__) */
