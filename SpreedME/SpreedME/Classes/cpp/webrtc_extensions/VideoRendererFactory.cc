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

#include "VideoRendererFactory.h"


#ifdef __APPLE__

#include "TargetConditionals.h"

#if TARGET_IPHONE_SIMULATOR
#include "VideoRendererIOS.h"
#elif TARGET_OS_IPHONE
#include "VideoRendererIOS.h"
#elif TARGET_OS_MAC
// Other kinds of Mac OS
#else
// Unsupported platform
#endif


#endif



using namespace spreedme;




VideoRenderer *
VideoRendererFactory::CreateVideoRenderer(VideoRendererDelegateInterface *delegate,
										  const std::string &name,
										  const std::string &videoTrackId,
										  const std::string &streamLabel)
{
	
	VideoRenderer *renderer = NULL;
	
#ifdef __APPLE__
	
	
#include "TargetConditionals.h"
#if TARGET_IPHONE_SIMULATOR
	// iOS Simulator
#elif TARGET_OS_IPHONE
	
	renderer = new VideoRendererIOS(delegate, name, videoTrackId, streamLabel);

#elif TARGET_OS_MAC
	// Other kinds of Mac OS
#else
	// Unsupported platform
#endif
	
	
#endif

	return renderer;
}



