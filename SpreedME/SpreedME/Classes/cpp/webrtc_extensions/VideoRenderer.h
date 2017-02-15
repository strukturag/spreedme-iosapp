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

#ifndef __SpreedME__VideoRenderer__
#define __SpreedME__VideoRenderer__


#include <talk/app/webrtc/mediastreaminterface.h>


namespace spreedme {
	
class VideoRenderer;

class VideoRendererDelegateInterface
{
public:
	virtual void FrameSizeHasBeenSet(VideoRenderer *renderer, int width, int height) = 0;
	virtual ~VideoRendererDelegateInterface() {};
};

class VideoRenderer : public webrtc::VideoRendererInterface {
	
public:
	
	VideoRenderer(VideoRendererDelegateInterface *delegate,
				  const std::string &name,
				  const std::string &videoTrackId,
				  const std::string &streamLabel) :
	delegate_(delegate), name_(name), videoTrackId_(videoTrackId), streamLabel_(streamLabel) {};
	
	~VideoRenderer() {};
	
	virtual void SetSize(int width, int height)
	{
		if (delegate_) {
			delegate_->FrameSizeHasBeenSet(this, width, height);
		}
	};
	
	virtual void RenderFrame(const cricket::VideoFrame* frame) = 0;
	
	virtual void Shutdown() = 0;
	
	virtual std::string name() {return name_;};
	virtual std::string videoTrackId() {return videoTrackId_;};
	virtual std::string streamLabel() {return streamLabel_;};
	virtual void *videoView() {return videoView_;};
	
protected:
	void *videoView_; // subclasses should release/free this object properly!
	VideoRendererDelegateInterface *delegate_; // We don't own it
	
	std::string name_;
	std::string videoTrackId_;
	std::string streamLabel_;
	
private:
	VideoRenderer(){};

};
	
	
} // namespace spreedme

#endif /* defined(__SpreedME__VideoRenderer__) */
