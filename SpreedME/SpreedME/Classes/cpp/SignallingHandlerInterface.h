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

#ifndef __SpreedME__SignallingHandlerInterface__
#define __SpreedME__SignallingHandlerInterface__

#include <set>
#include <string>

#include <talk/app/webrtc/jsep.h>

#include "ChannelingConstants.h"

namespace spreedme {


class PeerConnectionWrapper;


class PeerConnectionWrapperProviderInterface {
public:
	virtual PeerConnectionWrapper *GetP2PWrapperForUserId(const std::string &userId) = 0;
	virtual PeerConnectionWrapper *GetP2PWrapperForWrapperId(const std::string &wrapperId) = 0;
};


class ServerBasedMessageSenderInterface {
public:
	// Sends message thru the server. At the moment it can be only websocket channeling server.
	virtual void SendMessage(const std::string &msg) = 0;
};


class SignallingMessageReceiverInterface {
public:
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId) = 0;
	virtual void MessageReceived(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId, const std::string &token) = 0;
};


class SignallingHandlerInterface {
public:
//================= General purpose methods ===============
	//All P2P methods try to send data thru the default data channel. 
	
	// Sends @msg thru the channeling server
	virtual void SendMessage(const std::string &type, const std::string &msg) = 0;
	
	// Sends p2p message thru the given peer connection wrapper data channel
	virtual void SendP2PMessage(const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	
	/*
	 If @peerConnectionWrapper is not NULL and has working data channel calls SendP2PMessage with @msg and @peerConnectionWrapper,
	 otherwise calls SendMessage with @msg.
	 */
	virtual void SendMessage(const std::string &type, const std::string &msg, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	/*
	 If implementation can get a wrapper for @userId calls SendP2PMessage with @msg and found peerConnectionWrapper,
	 otherwise calls SendMessage with @msg.
	 */
	virtual void SendMessage(const std::string &type, const std::string &msg, const std::string &userId) = 0;
	/*
	 If implementation can get a wrapper for @wrapperId and its userId equals to @userId calls SendP2PMessage with @msg and found peerConnectionWrapper,
	 otherwise calls SendMessage with @msg.
	 */
	virtual void SendMessage(const std::string &type, const std::string &msg, const std::string &userId, const std::string &wrapperId) = 0;
	
	/*
	 Receives message and dispatches it to message receivers.
	 */
	virtual void ReceiveMessage(const std::string &msg, ChannelingMessageTransportType transportType, const std::string& wrapperId) = 0;
	
	/* 
	 Registers and unregisters message receivers. Uses std:set inside, so you can't register one object twice.
	 SignallingHandlerInterface does not handle receivers so you should unregister receiver before deleting it.
	 */
	virtual void RegisterMessageReceiver(SignallingMessageReceiverInterface *receiver) = 0;
	virtual void UnRegisterMessageReceiver(SignallingMessageReceiverInterface *receiver) = 0;


	/*
	 Registers and unregisters message receivers. Uses std:set inside, so you can't register one object twice.
	 SignallingHandlerInterface does not handle receivers so you should unregister receiver before deleting it.
	 */
	virtual void RegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver) = 0;
	virtual void UnRegisterTokenMessageReceiver(SignallingMessageReceiverInterface *receiver) = 0;
};

} //namespace spreedme
#endif /* defined(__SpreedME__SignallingHandlerInterface__) */
