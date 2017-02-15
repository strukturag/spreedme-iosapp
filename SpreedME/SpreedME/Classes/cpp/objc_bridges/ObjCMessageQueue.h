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

#ifndef __SpreedME__ObjCMessageQueue__
#define __SpreedME__ObjCMessageQueue__


#include <dispatch/dispatch.h>


#include "MessageQueueInterface.h"


namespace spreedme {

class ObjCMessageQueue : public MessageQueueInterface
{
	
public:
	static ObjCMessageQueue* CreateObjCMessageQueueMainQueue();
	
	explicit ObjCMessageQueue(dispatch_queue_t dispatchQueue);
	virtual ~ObjCMessageQueue();
	
	virtual void Post(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL);
	virtual void Send(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL);
	virtual void PostDelayed(int cmsDelay,
							 rtc::MessageHandler *phandler,
							 uint32 id,
							 rtc::MessageData *pdata = NULL);
	
	// Be careful when using Clear() in ObjCMessageQueue since there is no way to clear ObjCMessageQueue
	virtual void Clear(rtc::MessageHandler *phandler,
					   uint32 id = rtc::MQID_ANY,
					   rtc::MessageList* removed = NULL) {};
	
private:
	
	dispatch_queue_t dispatchQueue_;
	
	
	// Disallow implicit constructor and copy assign
	ObjCMessageQueue();
	ObjCMessageQueue(const ObjCMessageQueue&);
	void operator=(const ObjCMessageQueue&);
};

} //namespace spreedme

#endif /* defined(__SpreedME__ObjCMessageQueue__) */
