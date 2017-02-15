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

#import "ObjCMessageQueue.h"

namespace spreedme {

ObjCMessageQueue* ObjCMessageQueue::CreateObjCMessageQueueMainQueue()
{
	return new ObjCMessageQueue(NULL);
}


ObjCMessageQueue::ObjCMessageQueue(dispatch_queue_t dispatchQueue) /*: dispatchQueue_(dispatchQueue)*/
{
	dispatchQueue_ = dispatchQueue;
	if (dispatchQueue_ == NULL) {
		dispatchQueue_ = dispatch_get_main_queue();
	}
}


ObjCMessageQueue::~ObjCMessageQueue()
{
	if (dispatchQueue_) {
		dispatchQueue_ = NULL; // TODO: Check if this really releases dispatchQueue_.
	}
}


void ObjCMessageQueue::Post(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata)
{
	rtc::Message *msg = new rtc::Message;
	msg->phandler = phandler;
	msg->message_id = id;
	msg->pdata = pdata;
	dispatch_async(dispatchQueue_, ^{
		phandler->OnMessage(msg);
		delete msg;
	});
}
	
	
void ObjCMessageQueue::PostDelayed(int cmsDelay,
						 rtc::MessageHandler *phandler,
						 uint32 id,
						 rtc::MessageData *pdata)
{
	rtc::Message *msg = new rtc::Message;
	msg->phandler = phandler;
	msg->message_id = id;
	msg->pdata = pdata;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(cmsDelay * NSEC_PER_MSEC)), dispatchQueue_, ^{
		phandler->OnMessage(msg);
	});
}


void ObjCMessageQueue::Send(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata)
{
	rtc::Message *msg = new rtc::Message;
	msg->phandler = phandler;
	msg->message_id = id;
	msg->pdata = pdata;
	dispatch_sync(dispatchQueue_, ^{
		phandler->OnMessage(msg);
	});
}

}
