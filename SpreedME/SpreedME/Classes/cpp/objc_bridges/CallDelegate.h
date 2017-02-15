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

#ifndef __SpreedME__CallDelegate__
#define __SpreedME__CallDelegate__

#include <iostream>

#include "Call.h"

@class PeerConnectionController, VideoRendereriOSInfo;

namespace spreedme {

class CallDelegate : public CallDelegateInterface
{
	
public:
	CallDelegate(PeerConnectionController *peerConnectionController);
	
	
	// ----------- Call events
	virtual void FirstOutgoingCallStarted(Call *call, const std::string &userId, bool withVideo);
	virtual void OutgoingCallStarted(Call *call, const std::string &userId);
	virtual void FirstIncomingCallReceived(Call *call, const std::string &userId);
	virtual void IncomingCallReceived(Call *call, const std::string &userId);
	virtual void RemoteUserHangUp(Call *call, const std::string &userId);
	virtual void CallIsFinished(Call *call, CallFinishReason finishReason);
	virtual void IncomingCallWasAutoRejected(Call *call, const std::string &userId);
	
	virtual void ConnectionEstablished(Call *call, const std::string &userId);
	virtual void ConnectionLost(Call *call, const std::string &userId);
	virtual void ConnectionFailed(Call *call, const std::string &userId);
	
	virtual void CallHasStarted(Call *call);
	
	virtual void LocalStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds);
	virtual void LocalStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds);
	virtual void RemoteStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds);
	virtual void RemoteStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds);
	
	virtual void CallHasEncounteredAnError(Call *call, const Error &error);
	
	virtual void TokenDataChannelOpened(Call *call, const std::string &userId, const std::string &wrapperId);
	virtual void TokenDataChannelClosed(Call *call, const std::string &userId, const std::string &wrapperId);
	
	virtual void VideoRendererWasCreated(Call *call,
										 const VideoRendererInfo &rendererInfo);
	virtual void VideoRendererHasSetFrame(Call *call,
										  const VideoRendererInfo &rendererInfo);
	virtual void VideoRendererWasDeleted(Call *call,
										 const VideoRendererInfo &rendererInfo);
	virtual void FailedToSetupVideoRenderer(Call *call,
											const VideoRendererInfo &rendererInfo,
											VideoRendererManagementError error);
	virtual void FailedToDeleteVideoRenderer(Call *call,
											 const VideoRendererInfo &rendererInfo,
											 VideoRendererManagementError error);
	
	virtual void CallHasReceivedStatistics(Call *call, const webrtc::StatsReports &reports);
	
private:
	
	VideoRendereriOSInfo *ConvertVideoRendererInfo(const VideoRendererInfo &rendererInfo);
	
	CallDelegate(){};
	
	__unsafe_unretained PeerConnectionController *peerConnectionController_;
};

} // namespace spreedme

#endif /* defined(__SpreedME__CallDelegate__) */
