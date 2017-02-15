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

#ifndef __SpreedME__WebrtcCommonDefinitions__
#define __SpreedME__WebrtcCommonDefinitions__


namespace spreedme {
	


typedef enum VideoRendererManagementError {
	kVRMENoError = 0,
	kVRMERendererAlreadyExists,
	kVRMECouldNotFindVideoTrack,
	kVRMECouldNotFindRenderer,
}
VideoRendererManagementError;
	
	
	
struct IceCandidateStringRepresentation
{
	IceCandidateStringRepresentation()
	{
		sdp_mid = std::string();
		sdp_mline_index = 0;
		string_rep = std::string();
	};
	
	IceCandidateStringRepresentation(const std::string &sdp_mid,
									 int sdp_mline_index,
									 const std::string &string_rep) :
	sdp_mid(sdp_mid), sdp_mline_index(sdp_mline_index), string_rep(string_rep) {};
	
	
	std::string sdp_mid;
	int sdp_mline_index;
	std::string string_rep;
};
	
	
}; // namespace spreedme

#endif /* defined(__SpreedME__WebrtcCommonDefinitions__) */
