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

#include "CallDelegate.h"

#import "PeerConnectionController_ObjectiveCPP.h"
#import "VideoRendereriOSInfo.h"

#import "utils_objcpp.h"

using namespace spreedme;

CallDelegate::CallDelegate(PeerConnectionController *peerConnectionController) :
	peerConnectionController_(peerConnectionController)
{}


void CallDelegate::FirstOutgoingCallStarted(Call *call, const std::string &userId, bool withVideo)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver firstOutgoingCallStarted:call withUserSessionId:userSessionId_objc withVideo:withVideo];
	});
}


void CallDelegate::OutgoingCallStarted(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver outgoingCallStarted:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::FirstIncomingCallReceived(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver firstIncomingCallReceived:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::IncomingCallReceived(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver incomingCallReceived:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::ConnectionEstablished(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callConnectionEstablished:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::ConnectionLost(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callConnectionLost:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::ConnectionFailed(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callConnectionFailed:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::CallHasStarted(Call *call)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callHasStarted:call];
	});
}


void CallDelegate::RemoteUserHangUp(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver remoteUserHangUp:userSessionId_objc inCall:call];
	});
}


void CallDelegate::CallIsFinished(spreedme::Call *call, CallFinishReason finishReason)
{
	SMCallFinishReason smFinishReason = kSMCallFinishReasonUnspecified;
	switch (finishReason) {
		case kCallFinishReasonUnspecified:
			smFinishReason = kSMCallFinishReasonUnspecified;
			break;
		case kCallFinishReasonLocalHangUp:
			smFinishReason = kSMCallFinishReasonLocalHangUp;
			break;
		case kCallFinishReasonRemoteHungUp:
			smFinishReason = kSMCallFinishReasonRemoteHungUp;
			break;
		case kCallFinishReasonInternalError:
			smFinishReason = kSMCallFinishReasonInternalError;
			break;
			
		default:
			break;
	}
	PeerConnectionController *messageReceiver = peerConnectionController_;
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callIsFinished:call callFinishReason:smFinishReason];
	});
}


void CallDelegate::IncomingCallWasAutoRejected(Call *call, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver incomingCallWasAutoRejected:call withUserSessionId:userSessionId_objc];
	});
}


void CallDelegate::LocalStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	
	NSMutableArray *videoTracksIdsArray = [NSMutableArray array];
	for (STDStringVector::iterator it = videoTracksIds.begin(); it != videoTracksIds.end(); ++it) {
		NSString *copyVideoTrackId = [NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding];
		[videoTracksIdsArray addObject:copyVideoTrackId];
	}
	
	NSString *copyStreamLabel = NSStr(streamLabel.c_str());
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callLocalStreamHasBeenAdded:call withUserSessionId:userSessionId_objc streamLabel:copyStreamLabel videoTracksIds:[NSArray arrayWithArray:videoTracksIdsArray]];
	});
}


void CallDelegate::LocalStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	
	NSMutableArray *videoTracksIdsArray = [NSMutableArray array];
	for (STDStringVector::iterator it = videoTracksIds.begin(); it != videoTracksIds.end(); ++it) {
		NSString *copyVideoTrackId = [NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding];
		[videoTracksIdsArray addObject:copyVideoTrackId];
	}
	
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *copyStreamLabel = NSStr(streamLabel.c_str());
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callLocalStreamHasBeenRemoved:call withUserSessionId:userSessionId_objc streamLabel:copyStreamLabel videoTracksIds:[NSArray arrayWithArray:videoTracksIdsArray]];
	});
}


void CallDelegate::RemoteStreamHasBeenAdded(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	
	NSMutableArray *videoTracksIdsArray = [NSMutableArray array];
	for (STDStringVector::iterator it = videoTracksIds.begin(); it != videoTracksIds.end(); ++it) {
		NSString *copyVideoTrackId = [NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding];
		[videoTracksIdsArray addObject:copyVideoTrackId];
	}
	
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *copyStreamLabel = NSStr(streamLabel.c_str());
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callRemoteStreamHasBeenAdded:call withUserSessionId:userSessionId_objc streamLabel:copyStreamLabel videoTracksIds:[NSArray arrayWithArray:videoTracksIdsArray]];
	});
}


void CallDelegate::RemoteStreamHasBeenRemoved(Call *call, const std::string &userId, const std::string &streamLabel, STDStringVector videoTracksIds)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	
	NSMutableArray *videoTracksIdsArray = [NSMutableArray array];
	for (STDStringVector::iterator it = videoTracksIds.begin(); it != videoTracksIds.end(); ++it) {
		NSString *copyVideoTrackId = [NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding];
		[videoTracksIdsArray addObject:copyVideoTrackId];
	}
	
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *copyStreamLabel = NSStr(streamLabel.c_str());
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callRemoteStreamHasBeenRemoved:call withUserSessionId:userSessionId_objc streamLabel:copyStreamLabel videoTracksIds:[NSArray arrayWithArray:videoTracksIdsArray]];
	});
}


void CallDelegate::CallHasEncounteredAnError(Call *call, const Error &error)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	
	NSError *nsError = convertErrorToNSError(error);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callHasEncounteredAnError:call error:nsError];
	});
}


void CallDelegate::TokenDataChannelOpened(Call *call, const std::string &userId, const std::string &wrapperId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = NSStr(userId.c_str());
	NSString *copyWrapperId = NSStr(wrapperId.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver tokenDataChannelOpened:call userSessionId:userSessionId_objc wrapperId:copyWrapperId];
	});
}


void CallDelegate::TokenDataChannelClosed(Call *call, const std::string &userId, const std::string &wrapperId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = NSStr(userId.c_str());
	NSString *copyWrapperId = NSStr(wrapperId.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver tokenDataChannelClosed:call userSessionId:userSessionId_objc wrapperId:copyWrapperId];
	});
}


void CallDelegate::VideoRendererWasCreated(spreedme::Call *call, const spreedme::VideoRendererInfo &rendererInfo)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	VideoRendereriOSInfo *rendererInfoiOS = this->ConvertVideoRendererInfo(rendererInfo);
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver videoRendererWasCreatedIn:call
										  info:rendererInfoiOS];
	});
}


void CallDelegate::VideoRendererHasSetFrame(spreedme::Call *call, const spreedme::VideoRendererInfo &rendererInfo)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	VideoRendereriOSInfo *rendererInfoiOS = this->ConvertVideoRendererInfo(rendererInfo);
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver videoRendererHasSetFrameIn:call
											   info:rendererInfoiOS];
	});
}


void CallDelegate::VideoRendererWasDeleted(spreedme::Call *call, const spreedme::VideoRendererInfo &rendererInfo)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	VideoRendereriOSInfo *rendererInfoiOS = this->ConvertVideoRendererInfo(rendererInfo);
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver videoRendererWasDeletedIn:call
											  info:rendererInfoiOS];
	});
}


void CallDelegate::FailedToSetupVideoRenderer(spreedme::Call *call,
											  const spreedme::VideoRendererInfo &rendererInfo,
											  VideoRendererManagementError error)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	VideoRendereriOSInfo *rendererInfoiOS = this->ConvertVideoRendererInfo(rendererInfo);
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver failedToSetupVideoRendererIn:call
												 info:rendererInfoiOS
												error:error];
	});
}


void CallDelegate::FailedToDeleteVideoRenderer(spreedme::Call *call,
											   const spreedme::VideoRendererInfo &rendererInfo,
											   VideoRendererManagementError error)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	VideoRendereriOSInfo *rendererInfoiOS = this->ConvertVideoRendererInfo(rendererInfo);
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver failedToDeleteVideoRendererIn:call
												  info:rendererInfoiOS
												 error:error];
	});
}


void CallDelegate::CallHasReceivedStatistics(Call *call, const webrtc::StatsReports &reports)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	webrtc::StatsReports reports_copy = reports;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver callHasReceivedStatistics:call
											 stats:reports_copy];
	});
}


VideoRendereriOSInfo *CallDelegate::ConvertVideoRendererInfo(const spreedme::VideoRendererInfo &rendererInfo)
{
	VideoRendereriOSInfo *rendererInfoiOS = [VideoRendereriOSInfo new];
	
	rendererInfoiOS.userSessionId = NSStr(rendererInfo.userSessionId.c_str());
	
	rendererInfoiOS.streamLabel = NSStr(rendererInfo.streamLabel.c_str());
	rendererInfoiOS.videoTrackId = NSStr(rendererInfo.videoTrackId.c_str());
	rendererInfoiOS.rendererName = NSStr(rendererInfo.rendererName.c_str());
	
	rendererInfoiOS.outputView = (__bridge UIView *)rendererInfo.videoView;
	
	CGSize frame = CGSizeZero;
	frame.width = (CGFloat)rendererInfo.frameWidth;
	frame.height = (CGFloat)rendererInfo.frameHeight;
	
	rendererInfoiOS.frameSize = frame;
	
	return rendererInfoiOS;
}
