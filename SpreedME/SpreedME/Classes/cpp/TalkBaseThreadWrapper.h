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

#ifndef __SpreedME__TalkBaseThreadWrapper__
#define __SpreedME__TalkBaseThreadWrapper__

#include "MessageQueueInterface.h"

#include <webrtc/base/thread.h>

namespace spreedme {

class TalkBaseThreadWrapper : public MessageQueueInterface {
	
public:
	
	TalkBaseThreadWrapper(rtc::Thread *thread) : thread_(thread) {};
	virtual ~TalkBaseThreadWrapper() {};
	
	
	virtual void Post(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL)
	{
		thread_->Post(phandler, id, pdata);
	};
	
	virtual void Send(rtc::MessageHandler *phandler, uint32 id, rtc::MessageData *pdata = NULL)
	{
		thread_->Send(phandler, id, pdata);
	};
	
	virtual void PostDelayed(int cmsDelay, // milliseconds
							 rtc::MessageHandler *phandler,
							 uint32 id,
							 rtc::MessageData *pdata = NULL)
	{
		thread_->PostDelayed(cmsDelay, phandler, id, pdata);
	};
	
	
	virtual void Clear(rtc::MessageHandler *phandler,
					   uint32 id = rtc::MQID_ANY,
					   rtc::MessageList* removed = NULL)
	{
		thread_->Clear(phandler, id, removed);
	};
	
	
private:
	
	rtc::Thread *thread_; // we do not own it!
	
	TalkBaseThreadWrapper();
	
};

} //namespace spreedme
	

#endif /* defined(__SpreedME__TalkBaseThreadWrapper__) */
