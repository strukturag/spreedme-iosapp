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

#import "PeerConnectionController.h"

#include <string>
#include <talk/app/webrtc/mediastreaminterface.h>
#include <talk/app/webrtc/statstypes.h>
#include <webrtc/base/scoped_ref_ptr.h>

#include "WebrtcCommonDefinitions.h"

#import "VideoRendereriOSInfo.h"


namespace spreedme {
	class PeerConnectionWrapperFactory;
}

@class ChatFileInfo;

namespace spreedme {
	class Call;
	class FileDownloader;
	class FileUploader;
	class ScreenSharingHandler;
}


@interface PeerConnectionController ()

// CallDelegate methods
- (void)firstOutgoingCallStarted:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId withVideo:(BOOL)withVideo;
- (void)outgoingCallStarted:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)firstIncomingCallReceived:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)incomingCallReceived:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)callConnectionEstablished:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)callConnectionLost:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)callConnectionFailed:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;
- (void)callHasStarted:(spreedme::Call *)call;

- (void)remoteUserHangUp:(NSString *)userSessionId inCall:(spreedme::Call *)call;
- (void)callIsFinished:(spreedme::Call *)call callFinishReason:(SMCallFinishReason)finishReason;

- (void)incomingCallWasAutoRejected:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId;


- (void)callLocalStreamHasBeenAdded:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds;
- (void)callLocalStreamHasBeenRemoved:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds;
- (void)callRemoteStreamHasBeenAdded:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds;
- (void)callRemoteStreamHasBeenRemoved:(spreedme::Call *)call withUserSessionId:(NSString *)userSessionId streamLabel:(NSString *)streamLabel videoTracksIds:(NSArray *)videoTracksIds;

- (void)callHasEncounteredAnError:(spreedme::Call *)call error:(NSError *)error;


- (void)tokenDataChannelOpened:(spreedme::Call *)call userSessionId:(NSString *)userSessionId wrapperId:(NSString *)wrapperId;
- (void)tokenDataChannelClosed:(spreedme::Call *)call userSessionId:(NSString *)userSessionId wrapperId:(NSString *)wrapperId;

- (void)videoRendererWasCreatedIn:(spreedme::Call *)call
							 info:(VideoRendereriOSInfo *)info;
- (void)videoRendererHasSetFrameIn:(spreedme::Call *)call
							  info:(VideoRendereriOSInfo *)info;
- (void)videoRendererWasDeletedIn:(spreedme::Call *)call
							 info:(VideoRendereriOSInfo *)info;
- (void)failedToSetupVideoRendererIn:(spreedme::Call *)call
								info:(VideoRendereriOSInfo *)info
							   error:(spreedme::VideoRendererManagementError)error;
- (void)failedToDeleteVideoRendererIn:(spreedme::Call *)call
								 info:(VideoRendereriOSInfo *)info
								error:(spreedme::VideoRendererManagementError)error;


- (void)callHasReceivedStatistics:(spreedme::Call *)call
							stats:(webrtc::StatsReports)reports;

// ScreenSharingUIDelegate methods
- (void)screenSharingHasStarted:(spreedme::ScreenSharingHandler *)handler
					  withToken:(NSString *)token
			  withUserSessionId:(NSString *)userSessionId
					   withView:(void *)renderView
				   rendererName:(NSString *)rendererName;

- (void)screenSharingHasStopped:(spreedme::ScreenSharingHandler *)handler
					  withToken:(NSString *)token
			  withUserSessionId:(NSString *)userSessionId;

- (void)screenSharingHasChangedFrameSize:(spreedme::ScreenSharingHandler *)handler
							   withToken:(NSString *)token
					   withUserSessionId:(NSString *)userSessionId
							rendererName:(NSString *)rendererName
							   frameSize:(CGSize)frameSize;

- (void)screenSharingConnectionEstablished:(spreedme::ScreenSharingHandler *)handler
								 withToken:(NSString *)token
						 withUserSessionId:(NSString *)userSessionId;

- (void)screenSharingConnectionLost:(spreedme::ScreenSharingHandler *)handler
						  withToken:(NSString *)token
				  withUserSessionId:(NSString *)userSessionId;

- (void)screenSharingHandlerHasBeenClosed:(spreedme::ScreenSharingHandler *)handler
								withToken:(NSString *)token
						withUserSessionId:(NSString *)userSessionId
									stats:(webrtc::StatsReports)reports;


- (spreedme::PeerConnectionWrapperFactory *)peerConnectionWrapperFactory;

@end
