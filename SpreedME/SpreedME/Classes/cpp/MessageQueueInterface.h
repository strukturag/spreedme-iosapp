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

#ifndef __SpreedME__MessageQueueInterface__
#define __SpreedME__MessageQueueInterface__

#include <webrtc/base/messageQueue.h>
#include <webrtc/base/messageHandler.h>


namespace spreedme {
	
// This class mimics rtc::Thread interface for 'Post'-ing and 'Send'-ing messages.
class MessageQueueInterface {
public:
	virtual void Post(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL) = 0;
	virtual void Send(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL) = 0;
	virtual void PostDelayed(int cmsDelay, // milliseconds
							 rtc::MessageHandler *phandler,
							 uint32 id,
							 rtc::MessageData *pdata = NULL) = 0;
	
	virtual void Clear(rtc::MessageHandler *phandler,
					   uint32 id = rtc::MQID_ANY,
					   rtc::MessageList* removed = NULL) = 0;
};
	
	
} //namespace spreedme


#endif /* defined(__SpreedME__MessageQueueInterface__) */
