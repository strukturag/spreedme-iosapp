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

#ifndef __SpreedME__cpp_utils__
#define __SpreedME__cpp_utils__

#include <iostream>
#include <string>
#include <vector>

namespace spreedme {
	
void split(std::vector<std::string> &theStringVector,  /* Altered/returned value */
		   const std::string &theString,
		   const std::string &theDelimiter);
	
std::string trim(const std::string &str,
				 const std::string &whitespace = " \t");

std::string trim_sdp(const std::string &sdp);

std::string join(std::vector<std::string> &strings, const std::string &theDelimiter);
	
}



#endif /* defined(__SpreedME__cpp_utils__) */
