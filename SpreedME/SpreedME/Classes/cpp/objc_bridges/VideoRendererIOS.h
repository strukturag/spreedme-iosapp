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

#include "VideoRenderer.h"


namespace spreedme {
	
	class VideoRendererIOS;
	
	class VideoRendererIOSDelegateInterface
	{
	public:
		virtual void FrameSizeHasBeenSet(VideoRendererIOS *renderer, int width, int height) = 0;
		virtual ~VideoRendererIOSDelegateInterface() {};
	};
	
	class VideoRendererIOS : public VideoRenderer {
		
	public:
		
		VideoRendererIOS(VideoRendererDelegateInterface *delegate,
						 const std::string &name,
						 const std::string &videoTrackId,
						 const std::string &streamLabel);
		~VideoRendererIOS();
		
		virtual void SetSize(int width, int height)
		{
			if (delegate_) {
				delegate_->FrameSizeHasBeenSet(this, width, height);
			}
		};
		
		virtual void RenderFrame(const cricket::VideoFrame* frame);
		
		virtual void Shutdown();
	};
	
	
} // namespace spreedme
