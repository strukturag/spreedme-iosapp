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

#ifndef __SpreedME__FileTransfererBase__
#define __SpreedME__FileTransfererBase__

#include <iostream>
#include <fstream>

#include "TokenBasedConnectionsHandler.h"

namespace spreedme {
	
struct FileInfo
{
	// Given fields
	uint32 chunks;
	std::string token;
	std::string fileName;
	std::string fileType;
	unsigned long long fileSize;
	
	// calculated fields
	uint32 chunkSize;
};
	

class FileTransfererBase : public TokenBasedConnectionsHandler
{
public:
	
	FileTransfererBase(PeerConnectionWrapperFactory *peerConnectionWrapperFactory,
					   SignallingHandler *signallingHandler,
					   MessageQueueInterface *workerQueue,
					   MessageQueueInterface *callbacksMessageQueue);
	
	FileInfo fileInfo() {critSect_->Enter(); FileInfo fileInfo = fileInfo_; critSect_->Leave(); return fileInfo;};
	
	virtual void StopFileTransfer() = 0;
	virtual void PauseFileTransfer() = 0;
	virtual void ResumeFileTransfer() = 0;
	
protected:
	FileTransfererBase();
	virtual ~FileTransfererBase();
	
	virtual void ReceivedCandidate_s(const Json::Value &candidateJson, const std::string &from);
	
	
	virtual bool InsertWrapperForUserIdAndWrapperId(const std::string &userId, const std::string &wrapperId, rtc::scoped_refptr<PeerConnectionWrapper> wrapper);
	virtual rtc::scoped_refptr<PeerConnectionWrapper> WrapperForUserIdTokenId(const std::string &userId, const std::string &id);
	virtual rtc::scoped_refptr<PeerConnectionWrapper> WrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId);
	virtual void DeleteWrapperForUserIdWrapperId(const std::string &userId, const std::string &wrapperId);
	virtual void EraseAllWrappers();
	
	// Instance variables ----------------------------------------------------------------------
	WrapperIdToWrapperMap activeConnections_;
	std::set<std::string> userIds_;
	
	FileInfo fileInfo_;
	std::string filePath_;
	
	std::fstream fileHandle_;
	
private:
	
};

} // namespace spreedme


#endif /* defined(__SpreedME__FileTransfererBase__) */
