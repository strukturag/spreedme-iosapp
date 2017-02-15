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

#ifndef SpreedME_CommonCppTypes_h
#define SpreedME_CommonCppTypes_h

#include <map>

#include <webrtc/base/refcount.h>
#include <webrtc/base/messagehandler.h>

#include "ChannelingConstants.h"
#include "PeerConnectionWrapper.h"


typedef std::pair< std::string, rtc::scoped_refptr<spreedme::PeerConnectionWrapper> > UserIdToWrapperPair;
typedef std::map< std::string, rtc::scoped_refptr<spreedme::PeerConnectionWrapper> > UserIdToWrapperMap;
typedef std::pair< std::string, rtc::scoped_refptr<spreedme::PeerConnectionWrapper> > WrapperIdToWrapperPair;
typedef std::map< std::string, rtc::scoped_refptr<spreedme::PeerConnectionWrapper> > WrapperIdToWrapperMap;


typedef std::vector<std::string> STDStringVector;

namespace spreedme {
	
struct StringMessageData : public rtc::MessageData {
	explicit StringMessageData(const std::string& value) : value(value) {};
	
	std::string value;
};
	
struct BooleanMessageData : public rtc::MessageData {
	explicit BooleanMessageData(bool value) : value(value) {};
	
	bool value;
};

struct SignallingMessageData : public rtc::MessageData {
    SignallingMessageData (const std::string& msg, ChannelingMessageTransportType transportType, std::string wrapperId) :
	msg(msg), transportType(transportType), wrapperId(wrapperId) {};
    SignallingMessageData (const std::string& msg, ChannelingMessageTransportType transportType, std::string wrapperId, std::string token) :
	msg(msg), transportType(transportType), wrapperId(wrapperId), token(token) {};
	
	std::string msg;
	ChannelingMessageTransportType transportType;
	std::string wrapperId;
	std::string token;
};
	
struct VideoRendererMessageData : public rtc::MessageData {
	explicit VideoRendererMessageData(const std::string &userId,
									  const std::string &streamLabel,
									  const std::string &videoTrackId,
									  const std::string &rendererName) :
	userId(userId), streamLabel(streamLabel), videoTrackId(videoTrackId), rendererName(rendererName) {};
	
	std::string userId;
	std::string streamLabel;
	std::string videoTrackId;
	std::string rendererName;
};
	
} // namespace spreedme

#endif
