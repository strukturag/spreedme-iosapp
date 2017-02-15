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

#include "FileDownloadInfo.h"

#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

using namespace spreedme;

DownloadFileInfo::DownloadFileInfo(const FileInfo &fileInfo) :
	fileInfo_(fileInfo),
	lastRequestedChunkNumber_(0),
	downloadedChunksCount_(0),
	timeoutStart_(0)
{
	uint32 mapArraySize = fileInfo_.chunks;
	if (mapArraySize == UINT32_MAX) {
		spreed_me_log("Chunk number is equal to UINT32_MAX. This is bad!");
		assert(false);
	}
	
	chunksMap_ = new uint8[mapArraySize];
	if (chunksMap_) {
		memset(chunksMap_, 0, mapArraySize);
	}
	
	chunksToDownload_.push(lastRequestedChunkNumber_); // put the first chunk into queue
	for (int i = 0; i < CHUNKS_TO_DOWNLOAD_QUEUE_MAX_SIZE && i < fileInfo.chunks - 1; ++i) {
		++lastRequestedChunkNumber_;
		chunksToDownload_.push(lastRequestedChunkNumber_);
	}
};


// We assume here that if chunk was already downloaded it can't be set to kChunkIsNotDownloaded status again.
void DownloadFileInfo::SetChunkStatus(int chunkNumber, ChunkDownloadStatus status)
{
	if (chunkNumber >= 0 && chunkNumber < fileInfo_.chunks && (ChunkDownloadStatus)chunksMap_[chunkNumber] != status) {
		chunksMap_[chunkNumber] = status;
		
		switch (status) {
			case kChunkIsBeingDownloaded:
				break;
				
			case kChunkDownloaded:
				++downloadedChunksCount_;
				break;
			case kChunkStatusUndefined:
			case kChunkIsNotDownloaded:
			default:
				break;
		}
	}
};


ChunkDownloadStatus DownloadFileInfo::ChunkStatus(int chunkNumber)
{
	if (chunkNumber >= 0 && chunkNumber < fileInfo_.chunks) {
		return (ChunkDownloadStatus)chunksMap_[chunkNumber];
	} else {
		spreed_me_log("Chunk number is not inside array bounds");
	}
	return kChunkStatusUndefined;
}


uint32 DownloadFileInfo::GetNextChunkNumberToDownload()
{
	uint32 chunkNumber = UINT32_MAX;
	
	if (lastRequestedChunkNumber_ < fileInfo_.chunks - 1) {
		if (chunksToDownload_.size() < CHUNKS_TO_DOWNLOAD_QUEUE_MAX_SIZE) {
			++lastRequestedChunkNumber_;
			chunksToDownload_.push(lastRequestedChunkNumber_);
		}
	}
	
	if (chunksToDownload_.size()) {
		
		// We assume here that we don't use kChunkIsBeingDownloaded.
		// If we start using it we should change this code accordingly.
		do {
			chunkNumber = chunksToDownload_.front();
			spreed_me_log("poped chunk number %lu", chunkNumber);
			chunksToDownload_.pop();
		} while (this->ChunkStatus(chunkNumber) == kChunkDownloaded);
		
		spreed_me_log("request chunk number %lu", chunksToDownload_.front());
		spreed_me_log("next chunk number %lu", chunksToDownload_.front());
		
	} else {

		if (!this->AreAllDownloadersFree()) {
			
			uint64_t        start;
			uint64_t        end;
			uint64_t        elapsed;
			uint64_t        elapsedNano;
			uint64_t		elapsedSeconds;
			static mach_timebase_info_data_t    sTimebaseInfo;
			
			start = mach_absolute_time();
			if (timeoutStart_ == 0) {
				timeoutStart_ = start;
			}
			
			end = start;
			if (timeoutStart_ != 0) {
				elapsed = end - timeoutStart_;
								
				if ( sTimebaseInfo.denom == 0 ) {
					(void) mach_timebase_info(&sTimebaseInfo);
				}
				
				elapsedNano = elapsed * sTimebaseInfo.numer / sTimebaseInfo.denom;
				elapsedSeconds = elapsedNano / 1000000000;
				
			} else {
				elapsedSeconds = 0;
			}
			
			if (elapsedSeconds > 30) {
				spreed_me_log("We still have some downloading chunks. We can assume that these chunks failed to be downloaded and we can retry.");
				for (FreeDownloadersMap::iterator it = freeDownloaders_.begin(); it != freeDownloaders_.end(); ++it) {
					if (it->second.isCurrentlyDownloading == true) {
						it->second.isCurrentlyDownloading = false;
						chunksToDownload_.push(it->second.chunkNumber);
					}
				}
				
				chunkNumber = chunksToDownload_.front();
				spreed_me_log("poped chunk number %lu", chunkNumber);
				chunksToDownload_.pop();
				spreed_me_log("next chunk number %lu", chunksToDownload_.front());

				timeoutStart_ = 0; // Strat timeout over again
			}
		} else {
			spreed_me_log("Not all downloaders are free now. Wait.");
		}
	}
	
	spreed_me_log("Next chunk to download %lu", chunkNumber);
	
	return chunkNumber;
};


bool DownloadFileInfo::HasChunksToDownload()
{
	bool answer = downloadedChunksCount_ < fileInfo_.chunks;
	return answer;
};


bool DownloadFileInfo::AreAllDownloadersFree()
{
	for (FreeDownloadersMap::iterator it = freeDownloaders_.begin(); it != freeDownloaders_.end(); ++it) {
		if (it->second.isCurrentlyDownloading == true) {
			return false;
		}
	}
	return true;
};


void DownloadFileInfo::AddDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId, const DownloadStatusPair &pair)
{
	FreeDownloadersMap::iterator it = freeDownloaders_.find(dataChannelId);
	if (it != freeDownloaders_.end()) {
		it->second.isCurrentlyDownloading = pair.isCurrentlyDownloading;
		it->second.chunkNumber = pair.chunkNumber;
	} else {
		std::pair<UniqueDownloadDataChannelId, DownloadStatusPair> newPair = std::pair<UniqueDownloadDataChannelId, DownloadStatusPair>(dataChannelId, pair);
		freeDownloaders_.insert(newPair);
	}
};


void DownloadFileInfo::SetDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId, const DownloadStatusPair &pair)
{
	FreeDownloadersMap::iterator it = freeDownloaders_.find(dataChannelId);
	if (it != freeDownloaders_.end()) {
		it->second.isCurrentlyDownloading = pair.isCurrentlyDownloading;
		it->second.chunkNumber = pair.chunkNumber;
	}
};


DownloadStatusPair DownloadFileInfo::GetDownloadStatusPair(const UniqueDownloadDataChannelId &dataChannelId)
{
	DownloadStatusPair returnPair;
	FreeDownloadersMap::iterator it = freeDownloaders_.find(dataChannelId);
	if (it != freeDownloaders_.end()) {
		returnPair.isCurrentlyDownloading = it->second.isCurrentlyDownloading;
		returnPair.chunkNumber = it->second.chunkNumber;
	}
	
	return returnPair;
}
