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

#include "cpp_utils.h"

using namespace spreedme;

void spreedme::split(std::vector<std::string> &theStringVector,  /* Altered/returned value */
	  const  std::string  &theString,
	  const  std::string  &theDelimiter)
{
	
    size_t start = 0, end = 0;
	
    while (end != std::string::npos)
    {
        end = theString.find( theDelimiter, start);
		
        // If at end, use length=maxLength.  Else use length=end-start.
        theStringVector.push_back( theString.substr(start,
													(end ==std::string::npos) ? std::string::npos : end - start));
		
        // If at end, use start=maxSize.  Else use start=end+delimiter.
        start = ((end > (std::string::npos - theDelimiter.size()) )
				 ?  std::string::npos  :  end + theDelimiter.size());
    }
}


std::string spreedme::join(std::vector<std::string> &strings, const std::string &theDelimiter)
{
	std::string joinedString;
	
	for (std::vector<std::string>::iterator it = strings.begin(); it != strings.end(); ++it) {
		joinedString += *it + theDelimiter;
	}
	
	return joinedString;
}


std::string spreedme::trim(const std::string& str,
                 const std::string& whitespace)
{
    const auto strBegin = str.find_first_not_of(whitespace);
    if (strBegin == std::string::npos)
        return ""; // no content
	
    const auto strEnd = str.find_last_not_of(whitespace);
    const auto strRange = strEnd - strBegin + 1;
	
    return str.substr(strBegin, strRange);
}


std::string spreedme::trim_sdp(const std::string &sdp)
{
	std::string trimmedSdp;
	
	if (!sdp.empty()) {
		std::vector<std::string> splitSdp;
		split(splitSdp, sdp, "\r\n");
		
		if (splitSdp.size()) {
		
			std::vector<std::string>::iterator end = splitSdp.end();
			--end; // iterate to last element
			if (*end == ""){
				splitSdp.erase(end);
			}
			
			for (std::vector<std::string>::iterator it = splitSdp.begin(); it != splitSdp.end(); ++it) {
				*it = trim(*it);
			}
			
			trimmedSdp = join(splitSdp, "\r\n");
		}
	}
	
	return trimmedSdp;
}
