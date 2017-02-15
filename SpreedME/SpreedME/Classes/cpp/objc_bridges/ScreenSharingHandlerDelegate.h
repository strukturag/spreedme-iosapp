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

#import <Foundation/Foundation.h>

#include "ScreenSharingHandler.h"

@class PeerConnectionController;

namespace spreedme {
	
class ScreenSharingHandlerDelegate : public ScreenSharingHandlerDelegateInterface {
	
public:
	ScreenSharingHandlerDelegate(PeerConnectionController *peerConnectionController) : peerConnectionController_(peerConnectionController) {};
	virtual ~ScreenSharingHandlerDelegate() {};
	
	virtual void ScreenSharingHasStarted(ScreenSharingHandler *handler,
										 const std::string &token,
										 const std::string &userId,
										 void *videoView,
										 const std::string &renderName);
	virtual void ScreenSharingHasStopped(ScreenSharingHandler *handler,
										 const std::string &token,
										 const std::string &userId);
	
	virtual void ScreenSharingHasChangedFrameSize(ScreenSharingHandler *handler,
												  const std::string &token,
												  const std::string &userId,
												  const std::string &renderName,
												  int width, int height);
	
	virtual void ScreenSharingConnectionEstablished(ScreenSharingHandler *handler,
													const std::string &token,
													const std::string &userId);
	virtual void ScreenSharingConnectionLost(ScreenSharingHandler *handler,
											 const std::string &token,
											 const std::string &userId);
	
	virtual void ScreenSharingHandlerHasBeenClosed(ScreenSharingHandler *handler,
												   const std::string &token,
												   const std::string &userId,
												   const webrtc::StatsReports &reports);

	
private:
	
	ScreenSharingHandlerDelegate(){};
	
	__unsafe_unretained PeerConnectionController *peerConnectionController_;

};
	
} // namespace spreedme
