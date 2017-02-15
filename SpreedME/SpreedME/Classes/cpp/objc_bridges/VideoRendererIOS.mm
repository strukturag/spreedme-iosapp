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

#import "VideoRendererIOS.h"

#import "SMRTCVideoRenderView.h"

#include <talk/app/webrtc/objc/public/RTCI420Frame.h>
#include <talk/app/webrtc/objc/RTCI420Frame+Internal.h>

using namespace spreedme;


VideoRendererIOS::VideoRendererIOS(VideoRendererDelegateInterface *delegate,
								   const std::string &name,
								   const std::string &videoTrackId,
								   const std::string &streamLabel) :
VideoRenderer(delegate, name, videoTrackId, streamLabel)

{
	// Check in order not to deadlock in main queue
	if ([NSThread isMainThread]) {
		spreed_me_log("Already in main queue. Instantiate SMRTCVideoRenderView");
		videoView_ = (void *)CFBridgingRetain([[SMRTCVideoRenderView alloc] initWithFrame:CGRectZero]);
	} else {
		spreed_me_log("Dispatch sync to instantiate SMRTCVideoRenderView in main queue");
		void * __block view = NULL;
		dispatch_sync(dispatch_get_main_queue(), ^{
			view = (void *)CFBridgingRetain([[SMRTCVideoRenderView alloc] initWithFrame:CGRectZero]);
		});
		videoView_ = view;
	}
}


VideoRendererIOS::~VideoRendererIOS()
{
	// release reference to renderView
	SMRTCVideoRenderView *renderView = (__bridge_transfer SMRTCVideoRenderView *)videoView_;
	renderView = nil;
}


void VideoRendererIOS::RenderFrame(const cricket::VideoFrame* frame)
{
	RTCI420Frame* i420Frame = [[RTCI420Frame alloc] initWithVideoFrame:frame];
	
	SMRTCVideoRenderView *renderView = (__bridge SMRTCVideoRenderView *)videoView_;
	
	renderView.i420Frame = i420Frame;
};


void VideoRendererIOS::Shutdown()
{
	SMRTCVideoRenderView *renderView = (__bridge SMRTCVideoRenderView *)videoView_;
	renderView.i420Frame = nil;
}
