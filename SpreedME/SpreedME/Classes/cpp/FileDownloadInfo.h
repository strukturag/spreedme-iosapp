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

#ifndef __SpreedME__FileDownloadInfo__
#define __SpreedME__FileDownloadInfo__

#include <iostream>

#include <webrtc/base/basictypes.h>

#include "CommonCppTypes.h"
#include "FileTransfererBase.h"

namespace spreedme {

#define MAX_POSSIBLE_SIMULTANEOUS_DOWNLOADS		16
#define MAX_CHUNKS_QUANTITY_PER_PAGE			UINT16_MAX
#define CHUNKS_TO_DOWNLOAD_QUEUE_MAX_SIZE		32

typedef std::pair<std::string, std::string> UniqueDownloadDataChannelId; // pair < wrapperFactoryId, dataChannelName>

struct DownloadStatusPair
{
	DownloadStatusPair() : isCurrentlyDownloading(false), chunkNumber(UINT32_MAX) {};
	
	bool isCurrentlyDownloading;
	uint32 chunkNumber;
};

typedef std::map<UniqueDownloadDataChannelId, DownloadStatusPair> FreeDownloadersMap; // boolean value means true->downloader is downloading; false->downloader is free

typedef enum ChunkDownloadStatus {
	kChunkIsNotDownloaded = 0,
	kChunkDownloaded = 1,
	kChunkIsBeingDownloaded = 2,
	kChunkStatusUndefined = 7
} ChunkDownloadStatus;

class DownloadFileInfo
{
public:
	DownloadFileInfo(const FileInfo &fileInfo);
	virtual ~DownloadFileInfo() {delete chunksMap_;};
	
	void SetChunkStatus(int chunkNumber, ChunkDownloadStatus status); // We assume here that if chunk was already downloaded it can't be set to kChunkIsNotDownloaded status again.
	ChunkDownloadStatus ChunkStatus(int chunkNumber);
	
	uint32 GetNextChunkNumberToDownload();
	bool HasChunksToDownload();
	bool AreAllDownloadersFree();
	
	uint32 downloadedChunksCount() {return downloadedChunksCount_;};
	
	void AddDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId, const DownloadStatusPair &pair); // If pair exist changes its contents to given argument, if not inserts new
	void SetDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId, const DownloadStatusPair &pair); // if pair doesn't exist does nothing
	DownloadStatusPair GetDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId);
	
	FreeDownloadersMap freeDownloaders_;
	
private:
	DownloadFileInfo();
	
	uint8 *chunksMap_;
	std::queue<uint32> chunksToDownload_;
	FileInfo fileInfo_;
	uint32 lastRequestedChunkNumber_;
	uint32 downloadedChunksCount_;
	
	uint64_t timeoutStart_;
};


}; // namespace spreedme

#endif /* defined(__SpreedME__FileDownloadInfo__) */
