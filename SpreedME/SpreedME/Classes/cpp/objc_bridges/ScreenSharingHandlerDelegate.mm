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

#import "ScreenSharingHandlerDelegate.h"

#import "PeerConnectionController_ObjectiveCPP.h"

using namespace spreedme;

void ScreenSharingHandlerDelegate::ScreenSharingConnectionEstablished(ScreenSharingHandler *handler, const std::string &token, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingConnectionEstablished:handler withToken:token_objc withUserSessionId:userSessionId_objc];
	});
}


void ScreenSharingHandlerDelegate::ScreenSharingConnectionLost(ScreenSharingHandler *handler, const std::string &token, const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingConnectionLost:handler withToken:token_objc withUserSessionId:userSessionId_objc];
	});
}


void ScreenSharingHandlerDelegate::ScreenSharingHasStarted(ScreenSharingHandler *handler,
									 const std::string &token,
									 const std::string &userId,
									 void *videoView,
									 const std::string &renderName)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	NSString *rendererName_objc = NSStr(renderName.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingHasStarted:handler
									   withToken:token_objc
							   withUserSessionId:userSessionId_objc
										withView:videoView
									rendererName:rendererName_objc];
	});
}


void ScreenSharingHandlerDelegate::ScreenSharingHasStopped(ScreenSharingHandler *handler,
									 const std::string &token,
									 const std::string &userId)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingHasStopped:handler withToken:token_objc withUserSessionId:userSessionId_objc];
	});
}


void ScreenSharingHandlerDelegate::ScreenSharingHasChangedFrameSize(ScreenSharingHandler *handler,
											  const std::string &token,
											  const std::string &userId,
											  const std::string &renderName,
											  int width, int height)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	NSString *rendererName_objc = NSStr(renderName.c_str());
	CGSize frameSize = CGSizeMake(width, height);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingHasChangedFrameSize:handler
												withToken:token_objc
										withUserSessionId:userSessionId_objc
											 rendererName:rendererName_objc
												frameSize:frameSize];
	});

}


void ScreenSharingHandlerDelegate::ScreenSharingHandlerHasBeenClosed(ScreenSharingHandler *handler,
																	 const std::string &token,
																	 const std::string &userId,
																	 const webrtc::StatsReports &reports)
{
	PeerConnectionController *messageReceiver = peerConnectionController_;
	NSString *userSessionId_objc = [NSString stringWithCString:userId.c_str() encoding:NSUTF8StringEncoding];
	NSString *token_objc = NSStr(token.c_str());
	webrtc::StatsReports copy_reports = reports;
	dispatch_async(dispatch_get_main_queue(), ^{
		[messageReceiver screenSharingHandlerHasBeenClosed:handler
												 withToken:token_objc
										 withUserSessionId:userSessionId_objc
													 stats:copy_reports];
	});
}
