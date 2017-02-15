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

#include "PeerConnectionWrapper.h"

#include <assert.h>
#include <stdio.h>
#include <stdexcept>

#include <modules/audio_device/audio_device_impl.h>
#include <talk/app/webrtc/mediastream.h>
#include <talk/app/webrtc/mediastreaminterface.h>
#include <talk/app/webrtc/mediaconstraintsinterface.h>
#include <talk/app/webrtc/notifier.h>
#include <talk/app/webrtc/videosource.h>
#include <webrtc/base/json.h>
#include <webrtc/base/physicalsocketserver.h>
#include <webrtc/base/refcount.h>
#include <webrtc/base/ssladapter.h>
#include <webrtc/base/thread.h>
#include <talk/session/media/mediasession.h>
#include <talk/session/media/srtpfilter.h>

#include "cpp_utils.h"
#include "MediaConstraints.h"
#include "VideoRendererFactory.h"

using namespace spreedme;

namespace spreedme {
	
const char kDefaultDataChannelLabel[] = "default";
	
} // namespace spreedme



enum {
	MSG_PCW_PCO_ON_ERROR = 0,
	MSG_PCW_PCO_ON_SIGNALING_CHANGE,
	MSG_PCW_PCO_ON_STATE_CHANGE,
	MSG_PCW_PCO_ON_ADD_STREAM,
	MSG_PCW_PCO_ON_REMOVE_STREAM,
	MSG_PCW_PCO_ON_DATA_CHANNEL,
	MSG_PCW_PCO_ON_RENEGOTIATION_NEEDED,
	MSG_PCW_PCO_ON_ICE_CONNECTION_CHANGE,
	MSG_PCW_PCO_ON_ICE_GATHERING_CHANGE,
	MSG_PCW_PCO_ON_ICE_CANDIDATE,

    MSG_PCW_CSDO_ON_SUCCESS,
	MSG_PCW_CSDO_ON_FAILURE,
	
	MSG_PCW_SSDO_ON_SUCCESS,
	MSG_PCW_SSDO_ON_FAILURE,
	
	MSG_PCW_DCO_ON_DATA_CHANNEL_STATE_CHANGE,
	MSG_PCW_DCO_ON_DATA_CHANNEL_MESSAGE,
	
	MSG_PCW_SO_ON_COMPLETE,
};


#pragma mark - SPCSessioDescriptionMessageData
#pragma mark -

struct SPCSessioDescriptionMessageData : public rtc::MessageData {
	explicit SPCSessioDescriptionMessageData(webrtc::SessionDescriptionInterface *desc, std::string *recepientId)
	: recepientId(recepientId), description(desc) {
	}
	
	rtc::scoped_ptr<std::string> recepientId;
	rtc::scoped_ptr<webrtc::SessionDescriptionInterface> description;
};

struct SPCReceivedChannelingMessageData : public rtc::MessageData {
	explicit SPCReceivedChannelingMessageData(std::string *message)
	: message(message) {
	}
	
	rtc::scoped_ptr<std::string> message;
};


#pragma mark - PeerConnectionWrapper

#pragma mark - Object lifecycle

PeerConnectionWrapper::~PeerConnectionWrapper()
{
	this->Shutdown();
	delete &_critSect;
}


PeerConnectionWrapper::PeerConnectionWrapper(const std::string &factoryId,
											 PeerConnectionWrapperDelegateInterface *delegate) :
	_critSect(*webrtc::CriticalSectionWrapper::CreateCriticalSection()),
	_descriptionWasCreated(false),
	internalState_(kPCWIStateReady),
	negotiationState_(kPCWNStateIdle),
	iceConnectionState_(webrtc::PeerConnectionInterface::kIceConnectionNew),
	customIdentifier_(std::string()),
	factoryId_(factoryId),
	videoMuted_(false),
	delegate_(delegate)
{
	workerThread_ = rtc::Thread::Current();
}


#pragma mark - Setters

void PeerConnectionWrapper::SetPeerConnectionBridge(PeerConnectionWrapperDelegateInterface *pcBridge)
{
	if (pcBridge) {
        delegate_ = pcBridge;
    } else {
        delegate_ = NULL;
    }
}


void PeerConnectionWrapper::SetPeerConnection(rtc::scoped_refptr<webrtc::PeerConnectionInterface> peerConnection)
{
	peer_connection_ = peerConnection;
}


#pragma mark - Connection constraints

MediaConstraints* PeerConnectionWrapper::connectionConstraintsRef()
{
	return &connectionConstraints_;
}


void PeerConnectionWrapper::SetConnectionConstraints(const MediaConstraints &constraints)
{
	connectionConstraints_ = constraints;
}


MediaConstraints* PeerConnectionWrapper::sessionDescriptionConstraintsRef()
{
	return  &sessionDescriptionConstraints_;
}


void PeerConnectionWrapper::SetSessionDescriptionConstraints(const MediaConstraints &constraints)
{
	sessionDescriptionConstraints_ = constraints;
}


#pragma mark - Close / Shutdown

void PeerConnectionWrapper::Close()
{
	std::map<std::string, VideoRenderer*>::iterator it = renderersMap_.begin();
	while (it != renderersMap_.end()) {
		this->DeleteVideoRenderer(it->second->streamLabel(), it->second->videoTrackId(), it->second->name());
		it = renderersMap_.begin();
	}
	renderersMap_.clear();
	
	
	while (!_pendingCandidates.empty()) {
        webrtc::IceCandidateInterface *candidate = _pendingCandidates.front();
        _pendingCandidates.pop_front();
        delete candidate;
    }
	
	for (DataChannelsMap::iterator it = data_channels_.begin(); it != data_channels_.end(); ++it) {
		it->second->UnregisterObserver();
		it->second->Close();
	}
	
	if (peer_connection_.get() == NULL) {
		return;
	}
	
	if (peer_connection_->signaling_state() == webrtc::PeerConnectionInterface::kClosed) {
		return;
	}
	
	peer_connection_->Close();
}


void PeerConnectionWrapper::Shutdown()
{
	this->Close();
	
	if (delegate_) {
		delegate_ = NULL;
	}
	
	for (std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.begin(); it != local_active_streams_.end(); ++it) {
		peer_connection_->RemoveStream(it->second);
	}
	local_active_streams_.clear();
	
	data_channels_.clear();
	
	for (std::set<DataChannelObserver *>::iterator it = dataChannelObesrvers_.begin();
		 it != dataChannelObesrvers_.end();
		 ++it) {
		DataChannelObserver *obs = *it;
		obs->Release();
	}
	dataChannelObesrvers_.clear();
	
	peer_connection_ = NULL;
}


#pragma mark - Datachannels methods

bool PeerConnectionWrapper::InsertNewDataChannelWithName(rtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel, const std::string &name)
{
	std::pair<DataChannelsMap::iterator , bool> ret = data_channels_.insert(DataChannelPair(name, dataChannel));
	return ret.second;
}


/* ================================= Data channels ================================= */
void PeerConnectionWrapper::CreateDefaultDataChannel()
{
	rtc::scoped_refptr<webrtc::DataChannelInterface> data_channel = this->CreateDataChannel(kDefaultDataChannelLabel, NULL);
}


rtc::scoped_refptr<webrtc::DataChannelInterface> PeerConnectionWrapper::CreateDataChannel(const std::string &label, webrtc::DataChannelInit *config)
{
	webrtc::DataChannelInit new_config = config ? (*config) : webrtc::DataChannelInit();
	rtc::scoped_refptr<webrtc::DataChannelInterface> data_channel = peer_connection_->CreateDataChannel(label, &new_config);
	
	// Fake onDataChannelEvent
	this->OnDataChannel_w(data_channel.get());
	
	return data_channel;
}


void PeerConnectionWrapper::SendData(const std::string &msg)
{
	this->SendData(msg, kDefaultDataChannelLabel);
}


void PeerConnectionWrapper::SendData(const void *data, size_t size)
{
	this->SendData(data, size, kDefaultDataChannelLabel);
}


void PeerConnectionWrapper::SendData(const std::string &msg, const std::string &dataChannelName)
{
	ScopedRefPtrDataChannelInteface data_channel = this->DataChannelForName(dataChannelName);
	if (data_channel && data_channel->state() == webrtc::DataChannelInterface::kOpen) {
		
		webrtc::DataBuffer buffer(msg);
		bool succes = data_channel->Send(buffer);
		spreed_me_log("DataChannel send message succes=%s", succes ? "YES" : "NO");
	} else {
		spreed_me_log("No data channel or data channel is not ready while trying to send data %s", __FUNCTION__);
	}
}


void PeerConnectionWrapper::SendData(const void *data, size_t size, const std::string &dataChannelName)
{
	ScopedRefPtrDataChannelInteface data_channel = this->DataChannelForName(dataChannelName);
	if (data_channel && data_channel->state() == webrtc::DataChannelInterface::kOpen) {
		
		webrtc::DataBuffer buffer(rtc::Buffer(data, size), true);
		data_channel->Send(buffer);
		
	} else {
		spreed_me_log("No data channel or data channel is not ready while trying to send data %s", __FUNCTION__);
	}
}


bool PeerConnectionWrapper::HasOpenedDataChannel()
{
	for (DataChannelsMap::iterator it = data_channels_.begin(); it != data_channels_.end(); ++it) {
		if (it->second->state() == webrtc::DataChannelInterface::kOpen) {
			return true;
		}
	}
	return false;
}


std::string PeerConnectionWrapper::FirstOpenedDataChannelName()
{
	for (DataChannelsMap::iterator it = data_channels_.begin(); it != data_channels_.end(); ++it) {
		if (it->second->state() == webrtc::DataChannelInterface::kOpen) {
			return it->first;
		}
	}
	return std::string();
}


rtc::scoped_refptr<webrtc::DataChannelInterface> PeerConnectionWrapper::DataChannelForName(const std::string &name)
{
	DataChannelsMap::iterator it = data_channels_.find(name);
	
	if (it != data_channels_.end()) {
		rtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel = it->second;
		return dataChannel;
	}
	
	return NULL;
}


std::set<std::string> PeerConnectionWrapper::DataChannelNames()
{
	std::set<std::string> keys;
	for (DataChannelsMap::iterator it = data_channels_.begin(); it != data_channels_.end(); ++it) {
		keys.insert(it->first);
	}
	return keys;
}


void PeerConnectionWrapper::OnDataChannelStateChange(webrtc::DataChannelInterface *data_channel,
													 webrtc::DataChannelInterface::DataState state)
{
	DataChannelStateMessageData *msgData = new DataChannelStateMessageData(data_channel, state);
	workerThread_->Post(this, MSG_PCW_DCO_ON_DATA_CHANNEL_STATE_CHANGE, msgData);
}


void PeerConnectionWrapper::OnDataChannelStateChange_w(webrtc::DataChannelInterface *data_channel,
													   webrtc::DataChannelInterface::DataState state)
{
	switch (state) {
		case webrtc::DataChannelInterface::kConnecting:
			spreed_me_log("Datachannel %p state %s", data_channel, "kConnecting");
			break;
		case webrtc::DataChannelInterface::kOpen:
			spreed_me_log("Datachannel %p state %s", data_channel, "kOpen");
			break;
		case webrtc::DataChannelInterface::kClosing:
			spreed_me_log("Datachannel %p state %s", data_channel, "kClosing");
			break;
		case webrtc::DataChannelInterface::kClosed:
			spreed_me_log("Datachannel %p state %s", data_channel, "kClosed");
			data_channel->UnregisterObserver();
			break;
		default:
			break;
	}
	
	if (delegate_) {
		delegate_->DataChannelStateChanged(state, data_channel, this);
	}
}


void PeerConnectionWrapper::OnDataChannelMessage(webrtc::DataChannelInterface *data_channel, webrtc::DataBuffer *buffer)
{
	DataChannelDataMessageData *msgData = new DataChannelDataMessageData(data_channel, buffer);
	workerThread_->Post(this, MSG_PCW_DCO_ON_DATA_CHANNEL_MESSAGE, msgData);
}


void PeerConnectionWrapper::OnDataChannelMessage_w(webrtc::DataChannelInterface *data_channel, webrtc::DataBuffer *buffer)
{
	rtc::Buffer data = buffer->data;
	std::string message;
	if (!buffer->binary) {
		message = std::string(data.data(), data.length());
		spreed_me_log("Datachannel %p message:%s", data_channel, message.c_str());
	} else {
		spreed_me_log("Datachannel %p state %s", data_channel, "received binary buffer");
	}
	
	if (delegate_) {
		delegate_->ReceivedDataChannelData(buffer, data_channel, this);
	} else {
		delete buffer; // we have to delete buffer if no one is interested in it
	}
}


#pragma mark - Streams

void PeerConnectionWrapper::AddLocalStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream, const webrtc::MediaConstraintsInterface* constraints)
{
	if (stream) {
		if (local_active_streams_.find(stream->label()) != local_active_streams_.end()) {
			spreed_me_log("This stream is already added!\n");
			return;  // Already added.
		}
			
		
		if (!peer_connection_->AddStream(stream)) {
			spreed_me_log("Adding stream to PeerConnection failed\n");
		}
		typedef std::pair< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> > MediaStreamPair;
		local_active_streams_.insert(MediaStreamPair(stream->label(), stream));
		
		if (delegate_) {
			delegate_->LocalStreamHasBeenAdded(stream.get(), this);
		}
	}
}


void PeerConnectionWrapper::RemoveLocalStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream)
{
	if (stream) {
		if (local_active_streams_.find(stream->label()) != local_active_streams_.end())
			return;  // There is no such stream.
		
		peer_connection_->RemoveStream(stream);
		std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.find(stream->label());
		
		if (it != local_active_streams_.end()) {
			local_active_streams_.erase(it);
		}
		
		if (delegate_) {
			delegate_->LocalStreamHasBeenRemoved(stream.get(), this); // We should be fine with this call since 'stream' should keep reference to MediaStreamInterface until the end of this method scope
		}
	}
}


#pragma mark - Audio/Video

void PeerConnectionWrapper::SetMuteAudio(bool mute)
{
	for (std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.begin(); it != local_active_streams_.end(); ++it) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = it->second;
		webrtc::AudioTrackVector audiotrackvector = stream->GetAudioTracks();
		
		webrtc::AudioTrackVector::iterator it_audioTracks;
		for(it_audioTracks = audiotrackvector.begin(); it_audioTracks != audiotrackvector.end(); it_audioTracks++)
		{
			it_audioTracks->get()->set_enabled(!mute); // we need to invert 'mute' by semantics
		}
	}
}


void PeerConnectionWrapper::SetMuteVideo(bool mute)
{
	videoMuted_ = mute;
	for (std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.begin(); it != local_active_streams_.end(); ++it) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = it->second;
		webrtc::VideoTrackVector videotrackvector = stream->GetVideoTracks();
		
		webrtc::VideoTrackVector::iterator it_videoTracks;
		for(it_videoTracks = videotrackvector.begin(); it_videoTracks != videotrackvector.end(); it_videoTracks++)
		{
			it_videoTracks->get()->set_enabled(!mute); // we need to invert 'mute' by semantics
		}
	}
}


void PeerConnectionWrapper::DisableAllVideo()
{
	for (std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.begin(); it != local_active_streams_.end(); ++it) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = it->second;
		webrtc::VideoTrackVector videotrackvector = stream->GetVideoTracks();
		
		webrtc::VideoTrackVector::iterator it_videoTracks;
		for(it_videoTracks = videotrackvector.begin(); it_videoTracks != videotrackvector.end(); it_videoTracks++)
		{
			it_videoTracks->get()->set_enabled(false);
		}
	}
	
	for (size_t i = 0; i < peer_connection_->remote_streams()->count(); ++i) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peer_connection_->remote_streams()->at(i);
		webrtc::VideoTrackVector videotrackvector = stream->GetVideoTracks();
		
		webrtc::VideoTrackVector::iterator it_videoTracks;
		for(it_videoTracks = videotrackvector.begin(); it_videoTracks != videotrackvector.end(); it_videoTracks++)
		{
			it_videoTracks->get()->set_enabled(false);
		}
	}
}


void PeerConnectionWrapper::EnableAllVideo()
{
	for (std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> >::iterator it = local_active_streams_.begin(); it != local_active_streams_.end(); ++it) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = it->second;
		webrtc::VideoTrackVector videotrackvector = stream->GetVideoTracks();
		
		webrtc::VideoTrackVector::iterator it_videoTracks;
		for(it_videoTracks = videotrackvector.begin(); it_videoTracks != videotrackvector.end(); it_videoTracks++)
		{
			it_videoTracks->get()->set_enabled(!videoMuted_);
		}
	}
	
	for (size_t i = 0; i < peer_connection_->remote_streams()->count(); ++i) {
		rtc::scoped_refptr<webrtc::MediaStreamInterface> stream = peer_connection_->remote_streams()->at(i);
		webrtc::VideoTrackVector videotrackvector = stream->GetVideoTracks();
		
		webrtc::VideoTrackVector::iterator it_videoTracks;
		for(it_videoTracks = videotrackvector.begin(); it_videoTracks != videotrackvector.end(); it_videoTracks++)
		{
			it_videoTracks->get()->set_enabled(true);
		}
	}
}


bool PeerConnectionWrapper::IsVideoPermittedByConstraints()
{
	// This uses webrtc::FindConstraint and we check for mandatory constraints only.  
	bool answer = false;
	bool noVideoConstraintValue = false;
	size_t numberOfFoundConstraints = 0;
	
	webrtc::FindConstraint(this->sessionDescriptionConstraintsRef(), webrtc::MediaConstraintsInterface::kOfferToReceiveVideo, &noVideoConstraintValue, &numberOfFoundConstraints);
	
	if (numberOfFoundConstraints > 0) {
		answer = noVideoConstraintValue;
	} else {
		answer = true;
	}
	
	return answer;
}


#pragma mark - Video renderers

void PeerConnectionWrapper::SetupVideoRenderer(const std::string &streamLabel,
											   const std::string &videoTrackId,
											   const std::string &rendererName)
{
	webrtc::VideoTrackInterface *videoTrack = NULL;
	
	rtc::scoped_refptr<webrtc::StreamCollectionInterface> localStreams = peer_connection_->local_streams();
	
	//check local streams
	webrtc::MediaStreamInterface *stream = localStreams->find(streamLabel);
	if (stream && stream->GetVideoTracks().size()) {
		if (videoTrackId.empty()) {
			videoTrack = stream->GetVideoTracks()[0];
		} else {
			videoTrack = stream->FindVideoTrack(videoTrackId);
		}
	}
	
	// if we didn't find track in local streams look in remote streams
	if (!videoTrack) {
		rtc::scoped_refptr<webrtc::StreamCollectionInterface> remoteStreams = peer_connection_->remote_streams();
		
		webrtc::MediaStreamInterface *stream = remoteStreams->find(streamLabel);
		if (stream && stream->GetVideoTracks().size()) {
			if (videoTrackId.empty()) {
				videoTrack = stream->GetVideoTracks()[0];
			} else {
				videoTrack = stream->FindVideoTrack(videoTrackId);
			}
		}
	}
	
	VideoRendererInfo rendererInfo;
	rendererInfo.userSessionId = userId_;
	rendererInfo.videoTrackId = videoTrackId;
	rendererInfo.streamLabel = streamLabel;
	rendererInfo.rendererName = rendererName;
	
	if (videoTrack) {
		VideoRenderer *renderer = VideoRendererFactory::CreateVideoRenderer(this, rendererName, videoTrackId, streamLabel);
		
		
		
		std::pair<std::map<std::string, VideoRenderer*>::iterator, bool> pair = renderersMap_.insert(std::pair<std::string, VideoRenderer*>(rendererName, renderer));
		if (pair.second != true) {
			// old renderer is found
			
			delete renderer;
			
			if (delegate_) {
				delegate_->FailedToSetupVideoRenderer(this,
													  rendererInfo,
													  kVRMERendererAlreadyExists);
			}
			
			return;
		}
		
		videoTrack->AddRenderer(renderer);
		
		rendererInfo.videoView = renderer->videoView();
		
		if (delegate_) {
			delegate_->VideoRendererWasSetup(this, rendererInfo);
		}
		
	} else {
		spreed_me_log("We couldn't find videoTrack to setup VideoRenderer!");
		if (delegate_) {
			delegate_->FailedToSetupVideoRenderer(this,
												  rendererInfo,
												  kVRMECouldNotFindVideoTrack);
		}
	}
}


void PeerConnectionWrapper::DeleteVideoRenderer(const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName)
{
	webrtc::VideoTrackInterface *videoTrack = NULL;
	
	rtc::scoped_refptr<webrtc::StreamCollectionInterface> localStreams = peer_connection_->local_streams();
	
	//check local streams
	webrtc::MediaStreamInterface *stream = localStreams->find(streamLabel);
	if (stream && stream->GetVideoTracks().size()) {
		if (videoTrackId.empty()) {
			videoTrack = stream->GetVideoTracks()[0];
		} else {
			videoTrack = stream->FindVideoTrack(videoTrackId);
		}
	}
	
	// if we didn't find track in local streams look in remote streams
	if (!videoTrack) {
		rtc::scoped_refptr<webrtc::StreamCollectionInterface> remoteStreams = peer_connection_->remote_streams();
		
		webrtc::MediaStreamInterface *stream = remoteStreams->find(streamLabel);
		if (stream && stream->GetVideoTracks().size()) {
			if (videoTrackId.empty()) {
				videoTrack = stream->GetVideoTracks()[0];
			} else {
				videoTrack = stream->FindVideoTrack(videoTrackId);
			}
		}
	}
	
	VideoRendererInfo rendererInfo;
	rendererInfo.userSessionId = userId_;
	rendererInfo.videoTrackId = videoTrackId;
	rendererInfo.streamLabel = streamLabel;
	rendererInfo.rendererName = rendererName;
	
	if (videoTrack) {
		std::map<std::string, VideoRenderer*>::iterator it = renderersMap_.find(rendererName);
		if (it != renderersMap_.end()) {
			videoTrack->RemoveRenderer(it->second);
			it->second->Shutdown(); // Shutdown renderer since they can have some timers or other stuff to render buffers
									// which might not be there anymore. In case of VideoRendererIOS it tries to render
									// Obj-C i420 frame which has shallow copy of frame buffer that is already released. 
			
			if (delegate_) {
				delegate_->VideoRendererWasDeleted(this, rendererInfo);
			}
			
			delete it->second;
			renderersMap_.erase(it);
			
		} else {
			if (delegate_) {
				delegate_->FailedToDeleteVideoRenderer(this,
													   rendererInfo,
													   kVRMECouldNotFindRenderer);
			}
		}
		
	} else {
		spreed_me_log("We couldn't find videoTrack to remove VideoRenderer!");
		if (delegate_) {
			delegate_->FailedToDeleteVideoRenderer(this,
												   rendererInfo,
												   kVRMECouldNotFindVideoTrack);
		}
	}
}


void PeerConnectionWrapper::FrameSizeHasBeenSet(VideoRenderer *renderer, int width, int height)
{
	if (delegate_) {
		
		VideoRendererInfo rendererInfo;
		rendererInfo.userSessionId = userId_;
		rendererInfo.videoTrackId = renderer->videoTrackId();
		rendererInfo.streamLabel = renderer->streamLabel();
		rendererInfo.rendererName = renderer->name();
		rendererInfo.frameWidth = width;
		rendererInfo.frameHeight = height;
		
		delegate_->VideoRendererHasChangedFrameSize(this,
													rendererInfo);
	}
}


#pragma mark - Statistics

void PeerConnectionWrapper::RequestStatisticsReportsForAllStreams()
{
	rtc::scoped_refptr<StatisticsObserver>
		obs(new rtc::RefCountedObject<StatisticsObserver>(this, (webrtc::MediaStreamTrackInterface *)NULL));
	
	bool success = peer_connection_->GetStats(obs,
											  NULL,
											  webrtc::PeerConnectionInterface::kStatsOutputLevelStandard);
	
	if (!success) {
		if (delegate_) {
			delegate_->PeerConnectionWrapperHasFailedToReceiveStats(this);
		}
	}
}


void PeerConnectionWrapper::ReceivedStatistics(webrtc::MediaStreamTrackInterface *track, webrtc::StatsReports reports)
{
	StatisticsReportMessageData *msgData = new StatisticsReportMessageData(track, reports);
	workerThread_->Post(this, MSG_PCW_SO_ON_COMPLETE, msgData);
}


void PeerConnectionWrapper::ReceivedStatistics_w(webrtc::MediaStreamTrackInterface *track, webrtc::StatsReports reports)
{
	if (delegate_) {
		delegate_->PeerConnectionWrapperHasReceivedStats(this, reports);
	}
}


#pragma mark - PeerConnection delegate/observer

void PeerConnectionWrapper::OnSignalingChange(webrtc::PeerConnectionInterface::SignalingState new_state)
{
	PlainMessageData<webrtc::PeerConnectionInterface::SignalingState> *msgData =
		new PlainMessageData<webrtc::PeerConnectionInterface::SignalingState>(new_state);
	workerThread_->Post(this, MSG_PCW_PCO_ON_SIGNALING_CHANGE, msgData);
}

void PeerConnectionWrapper::OnSignalingChange_w(webrtc::PeerConnectionInterface::SignalingState new_state)
{
	signalingState_ = new_state;
	switch (new_state) {
		case webrtc::PeerConnectionInterface::kStable:
			spreed_me_log("OnSignalingChange to kStable\n");
			break;
		case webrtc::PeerConnectionInterface::kHaveLocalOffer:
			spreed_me_log("OnSignalingChange to kHaveLocalOffer\n");
			break;
		case webrtc::PeerConnectionInterface::kHaveLocalPrAnswer:
			spreed_me_log("OnSignalingChange to kHaveLocalPrAnswer\n");
			break;
		case webrtc::PeerConnectionInterface::kHaveRemoteOffer:
			spreed_me_log("OnSignalingChange to kHaveRemoteOffer\n");
			break;
		case webrtc::PeerConnectionInterface::kHaveRemotePrAnswer:
			spreed_me_log("OnSignalingChange to kHaveRemotePrAnswer\n");
			break;
		case webrtc::PeerConnectionInterface::kClosed:
			spreed_me_log("OnSignalingChange to kClosed\n");
			break;
			
		default:
			break;
	}
}


void PeerConnectionWrapper::OnError()
{
	workerThread_->Post(this, MSG_PCW_PCO_ON_ERROR);
}


void PeerConnectionWrapper::OnError_w()
{
	spreed_me_log("Some error! (OnError()) \n");
	if (delegate_) {
		delegate_->PeerConnectionWrapperHasEncounteredError(this, Error(kErrorDomainPeerConnectionWrapper, "Unknown error reported by webrtc", kUnknownErrorErrorCode));
	}
}


void PeerConnectionWrapper::OnStateChange(webrtc::PeerConnectionObserver::StateType state_changed)
{
	PlainMessageData<webrtc::PeerConnectionObserver::StateType> *msgData =
		new PlainMessageData<webrtc::PeerConnectionObserver::StateType>(state_changed);
	workerThread_->Post(this, MSG_PCW_PCO_ON_STATE_CHANGE, msgData);
}


void PeerConnectionWrapper::OnStateChange_w(webrtc::PeerConnectionObserver::StateType state_changed)
{
	switch (state_changed) {
		case webrtc::PeerConnectionObserver::kIceState:
			spreed_me_log("State changed: kIceState %d\n", (int) state_changed);
		break;
		case webrtc::PeerConnectionObserver::kSignalingState:
			spreed_me_log("State changed: kSignalingState %d\n", (int) state_changed);
		break;
		default:
			spreed_me_log("State changed: UNKNOWN! %d\n", (int) state_changed);
		break;
	}
}


void PeerConnectionWrapper::OnAddStream(webrtc::MediaStreamInterface* stream)
{
	PointerMessageData<webrtc::MediaStreamInterface> *msgData = new PointerMessageData<webrtc::MediaStreamInterface>(stream);
	workerThread_->Post(this, MSG_PCW_PCO_ON_ADD_STREAM, msgData);
}


void PeerConnectionWrapper::OnAddStream_w(webrtc::MediaStreamInterface* stream)
{
	if (delegate_) {
		delegate_->RemoteStreamHasBeenAdded(stream, this);
	}
	spreed_me_log("Add stream: %p %s\n", stream, stream->label().c_str());
}


void PeerConnectionWrapper::OnRemoveStream(webrtc::MediaStreamInterface* stream)
{
	PointerMessageData<webrtc::MediaStreamInterface> *msgData = new PointerMessageData<webrtc::MediaStreamInterface>(stream);
	workerThread_->Post(this, MSG_PCW_PCO_ON_REMOVE_STREAM, msgData);
}


void PeerConnectionWrapper::OnRemoveStream_w(webrtc::MediaStreamInterface* stream)
{
	if (delegate_) {
		delegate_->RemoteStreamHasBeenRemoved(stream, this);
	}
    spreed_me_log("Remove stream: %p %s\n", stream, stream->label().c_str());
}


void PeerConnectionWrapper::OnDataChannel(webrtc::DataChannelInterface *data_channel)
{
	ScopedRefPtrDataChannelInteface scopedRefDataChannel(data_channel);
	
	PlainMessageData<ScopedRefPtrDataChannelInteface> *msgData =
		new PlainMessageData<ScopedRefPtrDataChannelInteface>(scopedRefDataChannel);
	workerThread_->Post(this, MSG_PCW_PCO_ON_DATA_CHANNEL, msgData);
}


void PeerConnectionWrapper::OnDataChannel_w(ScopedRefPtrDataChannelInteface dataChannelScoped)
{
	spreed_me_log("Got new DataChannel %p", dataChannelScoped.get());
	
	ScopedRefPtrDataChannelInteface dataChannel = this->DataChannelForName(dataChannelScoped->label());
	
	if (dataChannel) {
		spreed_me_log("Duplicate data_channel in OnDataChannel event");
	} else {
		ScopedRefPtrDataChannelInteface newDataChannel = ScopedRefPtrDataChannelInteface(dataChannelScoped);
		//TODO: Fix leaked observer
		DataChannelObserver *obs = DataChannelObserver::Create(this, dataChannelScoped);
		dataChannelObesrvers_.insert(obs);
		newDataChannel->RegisterObserver(obs);
		bool success = this->InsertNewDataChannelWithName(newDataChannel, dataChannelScoped->label());
		spreed_me_log("Insert new data channel %p succes=%s", dataChannelScoped.get(), success ? "YES" : "NO");
	}
}


void PeerConnectionWrapper::OnIceCandidate(const webrtc::IceCandidateInterface* candidate)
{
	std::string candidateString = std::string();
	bool success = candidate->ToString(&candidateString);
	if (success) {
	
		IceCandidateStringRepresentation *candidateStringRep =
			new IceCandidateStringRepresentation(candidate->sdp_mid(), candidate->sdp_mline_index(), candidateString);
		
		PointerMessageData<IceCandidateStringRepresentation> *msgData = new PointerMessageData<IceCandidateStringRepresentation>(candidateStringRep);
		workerThread_->Post(this, MSG_PCW_PCO_ON_ICE_CANDIDATE, msgData);
	} else {
		spreed_me_log("Broken candidate!");
	}
}


void PeerConnectionWrapper::OnIceCandidate_w(IceCandidateStringRepresentation* candidate)
{
//    spreed_me_log("%s: %d %s\n", __FUNCTION__, candidate->sdp_mline_index(), candidate->sdp_mid().c_str());
    
	if (delegate_) {
		delegate_->CandidateIsReadyToBeSent(candidate, this);
	}
}


void PeerConnectionWrapper::OnRenegotiationNeeded()
{
	workerThread_->Post(this, MSG_PCW_PCO_ON_RENEGOTIATION_NEEDED);
}


void PeerConnectionWrapper::OnRenegotiationNeeded_w()
{
	spreed_me_log("Renegotiation needed!");
}


void PeerConnectionWrapper::OnIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState new_state)
{
	PlainMessageData<webrtc::PeerConnectionInterface::IceConnectionState> *msgData =
	new PlainMessageData<webrtc::PeerConnectionInterface::IceConnectionState>(new_state);
	workerThread_->Post(this, MSG_PCW_PCO_ON_ICE_CONNECTION_CHANGE, msgData);
}


void PeerConnectionWrapper::OnIceConnectionChange_w(webrtc::PeerConnectionInterface::IceConnectionState new_state)
{
	iceConnectionState_ = new_state;
	switch (new_state) {
		case webrtc::PeerConnectionInterface::kIceConnectionNew:
			spreed_me_log("OnIceConnectionChange to kIceConnectionNew\n");
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionChecking:
			spreed_me_log("OnIceConnectionChange to kIceConnectionChecking\n");
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionConnected:
			spreed_me_log("OnIceConnectionChange to kIceConnectionConnected\n");
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionCompleted:
			spreed_me_log("OnIceConnectionChange to kIceConnectionCompleted\n");
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionFailed:
			spreed_me_log("OnIceConnectionChange to kIceConnectionFailed\n");
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionDisconnected:
			spreed_me_log("OnIceConnectionChange to kIceConnectionDisconnected\n");
			//			this->peer_connection_->Close();
			break;
		case webrtc::PeerConnectionInterface::kIceConnectionClosed:
			spreed_me_log("OnIceConnectionChange to kIceConnectionClosed\n");
			break;
			
		default:
			break;
	}
	if (delegate_) {
		delegate_->IceConnectionStateChanged(new_state, this);
	}
}


#pragma mark - Create Session Description observer implementation

void PeerConnectionWrapper::OnSuccess(webrtc::SessionDescriptionInterface* desc)
{
	PointerMessageData<webrtc::SessionDescriptionInterface> *msgData =
		new PointerMessageData<webrtc::SessionDescriptionInterface>(desc);
	workerThread_->Post(this, MSG_PCW_CSDO_ON_SUCCESS, msgData);
}


void PeerConnectionWrapper::OnSuccess_w(webrtc::SessionDescriptionInterface* desc)
{
	switch (internalState_) {
		case kPCWIStateCreatingDescriptionForOffer:
			internalState_ = kPCWIStateReady;
			this->SetupLocalOffer(desc);
		break;
			
		case kPCWIStateCreatingDescriptionForAnswer:
			internalState_ = kPCWIStateReady;
			this->SetupLocalAnswer(desc);
		break;
			
		case kPCWIStateReady:
		default:
			spreed_me_log("!!! Should not happen. \n");
		break;
	}
		
	_descriptionWasCreated = true;
}


void PeerConnectionWrapper::OnFailure(const std::string& error)
{
	PlainMessageData<std::string> *msgData = new PlainMessageData<std::string>(error);
	workerThread_->Post(this, MSG_PCW_CSDO_ON_FAILURE, msgData);
}


void PeerConnectionWrapper::OnFailure_w(const std::string& error)
{
    spreed_me_log("Failed to create session description: %s\n", error.c_str());
}


#pragma mark - SetSessionDescriptionObserver Implementation

void PeerConnectionWrapper::DescriptionIsSet(bool isLocalDesc, const std::string &sdType, const std::string &sdp)
{
	SettingSessionDescriptionMessageData *msgData = new SettingSessionDescriptionMessageData(isLocalDesc, sdType, sdp);
	workerThread_->Post(this, MSG_PCW_SSDO_ON_SUCCESS, msgData);
}


void PeerConnectionWrapper::DescriptionIsSet_w(bool isLocalDesc, const std::string &sdType, const std::string &sdp)
{
	spreed_me_log("Success. %s description was set.\n", isLocalDesc ? "Local" : "Remote");
	
	switch (negotiationState_) {
		
		case kPCWNStateWaitingForLocalOfferToBeSet:
			if (isLocalDesc) {
				negotiationState_ = kPCWNStateIdle;
				if (delegate_) {
					delegate_->OfferIsReadyToBeSent(sdType, sdp, this);
				}
			} else {
				spreed_me_log("This shouldn't not happen. We wait for local offer to be set but instead we get remote offer/answer set");
				if (delegate_) {
					delegate_->PeerConnectionWrapperHasEncounteredError(this, Error(kErrorDomainPeerConnectionWrapper,
																					"We wait for local offer to be set but instead we get remote offer/answer set",
																					kUnknownErrorErrorCode));
				}
			}
		break;
		
		case kPCWNStateWaitingForRemoteOfferToBeSet:
			if (sdType == webrtc::SessionDescriptionInterface::kOffer && !isLocalDesc)
			{
				if (!isLocalDesc) {
					if (!_pendingCandidates.empty()) {
						spreed_me_log("Setting pending candidates");
					}
					
					while (!_pendingCandidates.empty()) {
						webrtc::IceCandidateInterface *candidate = _pendingCandidates.front();
						_pendingCandidates.pop_front();
						peer_connection_->AddIceCandidate(candidate);
						delete candidate;
					}
				}
				
				
				negotiationState_ = kPCWNStateIdle;
				if (internalState_ == kPCWIStateReady) {
					internalState_ = kPCWIStateCreatingDescriptionForAnswer;
					peer_connection_->CreateAnswer(this, this->sessionDescriptionConstraintsRef());
				} else {
					spreed_me_log("Internal state of peerConnection is not 'Ready', can't start creating local answer.");
				}
			} else {
				spreed_me_log("DescriptionIsSet: This shouldn't happen! internalState_==kPCWIStateWaitingForRemoteOfferToBeSet but sdType is %s or description is local instead of remote", sdType.c_str());
				if (delegate_) {
					delegate_->PeerConnectionWrapperHasEncounteredError(this, Error(kErrorDomainPeerConnectionWrapper,
																					"internalState_==kPCWIStateWaitingForRemoteOfferToBeSet but sdType is different",
																					kUnknownErrorErrorCode));
				}
			}
		break;
		
		case kPCWNStateWaitingForLocalAnswerToBeSet:
			negotiationState_ = kPCWNStateIdle;
			if (delegate_) {
				delegate_->AnswerIsReadyToBeSent(sdType, sdp, this);
			}
		break;
			
		case kPCWNStateWaitingForRemoteAnswerToBeSet:
			negotiationState_ = kPCWNStateIdle;
			spreed_me_log("Remote answer has been set");
			// we don't need to do anything
		break;
			
		case kPCWNStateIdle:
		default:
			spreed_me_log("DescriptionIsSet This shouldn't happen! negotiationState_ %d, description is local %d", negotiationState_, isLocalDesc);
			if (delegate_) {
				delegate_->PeerConnectionWrapperHasEncounteredError(this, Error(kErrorDomainPeerConnectionWrapper,
																				"DescriptionIsSet but peer connection wrapper state is kPCWNStateIdle",
																				kUnknownErrorErrorCode));
			}
		break;
	}
}


void PeerConnectionWrapper::DescriptionSetFailed(bool isLocalDesc, const std::string &sdType, const std::string &sdp)
{
	SettingSessionDescriptionMessageData *msgData = new SettingSessionDescriptionMessageData(isLocalDesc, sdType, sdp);
	workerThread_->Post(this, MSG_PCW_SSDO_ON_FAILURE, msgData);
}


void PeerConnectionWrapper::DescriptionSetFailed_w(bool isLocalDesc, const std::string &sdType, const std::string &sdp)
{
	spreed_me_log("Failed. %s description was not set.\n", isLocalDesc ? "Local" : "Remote");
	switch (negotiationState_) {
			
		case kPCWNStateWaitingForLocalOfferToBeSet:
			break;
		case kPCWNStateWaitingForRemoteOfferToBeSet:
			break;
			
		case kPCWNStateWaitingForLocalAnswerToBeSet:
		case kPCWNStateWaitingForRemoteAnswerToBeSet:
		case kPCWNStateIdle:
		default:
			spreed_me_log("DescriptionSetFailed: This shouldn't happen! negotiationState_ %d", negotiationState_);
			
			break;
	}
	
	if (delegate_) {
		delegate_->PeerConnectionWrapperHasEncounteredError(this, Error(kErrorDomainPeerConnectionWrapper,
																		"Failed to set description",
																		kUnknownErrorErrorCode));
	}
}


#pragma mark - SDP methods

void PeerConnectionWrapper::CreateOffer(const std::string recepientId)
{
	if (internalState_ == kPCWIStateReady) {
		if (peer_connection_ != NULL) {
			internalState_ = kPCWIStateCreatingDescriptionForOffer;
			this->CreateDefaultDataChannel();
			peer_connection_->CreateOffer(this, this->sessionDescriptionConstraintsRef());
		}
	} else {
		spreed_me_log("We received offer and want to create answer. Please wait till we create answer to avoid ambiguous description handling.\n");
	}
}


void PeerConnectionWrapper::replaceStringFromSdp(std::string& str, const std::string& from, const std::string& to)
{
    if(from.empty())
        return;
    size_t start_pos = 0;
    while((start_pos = str.find(from, start_pos)) != std::string::npos) {
        str.replace(start_pos, from.length(), to);
        start_pos += to.length(); // In case 'to' contains 'from', like replacing 'x' with 'yx'
    }
}


void PeerConnectionWrapper::replaceRegexFromSdp(std::string& str, std::regex& regex, const std::string& replace_with)
{
    std::smatch m;
    std::string out;
    while (std::regex_search(str, m, regex))
    {
        out += m.prefix();
        out += std::regex_replace(m[0].str(), regex, replace_with);
        str = m.suffix();
    }
    out += str;
    str = out;
}



void PeerConnectionWrapper::SetupRemoteOffer(const std::string &sdp)
{
	if (internalState_ == kPCWIStateReady) {
		std::string type("offer");
        std::string sdpString = sdp;
        replaceStringFromSdp(sdpString, "UDP/TLS/RTP/SAVPF", "RTP/SAVPF");
		std::string fixedSdp = trim_sdp(sdpString);
		webrtc::SessionDescriptionInterface* session_description(
																 webrtc::CreateSessionDescription(type, fixedSdp));
//		spreed_me_log("Remoter offer SDP \n%s", sdp.c_str());
		if (!session_description) {
			spreed_me_log("Can't parse received session description message.\n");
			return;
		}
		
		std::string sdType = session_description->type();
		
		if (negotiationState_ == kPCWNStateIdle) {
			negotiationState_ = kPCWNStateWaitingForRemoteOfferToBeSet;
			peer_connection_->SetRemoteDescription(SpreedSetSessionDescriptionObserver::Create(this, false, sdType, ""), session_description);
		} else {
			spreed_me_log("This shouldn't happen. Trying to set remote offer when negotiationState_(%d) != kPCWNStateIdle", negotiationState_);
		}
		
	} else {
		spreed_me_log("We are in the process of creating offer. Ignore other offers\n");
	}
}


void PeerConnectionWrapper::SetupRemoteAnswer(const std::string &sdp)
{
	std::string type("answer");
	
	std::string fixedSdp = trim_sdp(sdp);
	webrtc::SessionDescriptionInterface* session_description(
															 webrtc::CreateSessionDescription(type, fixedSdp));
	
	
	if (session_description) {
	
		cricket::SessionDescription *desc = session_description->description();
		if (desc != NULL) {
			cricket::MediaContentDescription *content = static_cast<cricket::MediaContentDescription *>(desc->GetContentDescriptionByName("audio"));
			if (content != NULL && content->type() == cricket::MEDIA_TYPE_AUDIO) {
				cricket::AudioContentDescription *audio_desc = static_cast<cricket::AudioContentDescription *>(content);
				for (std::vector<cricket::AudioCodec>::const_iterator it =
					 audio_desc->codecs().begin();
					 it != audio_desc->codecs().end(); ++it) {
					cricket::AudioCodec *codec = (cricket::AudioCodec *) &(*it);
					if (codec->name == cricket::kOpusCodecName) {
						codec->SetParam(cricket::kCodecParamStereo, cricket::kParamValueTrue);
					}
				}
			}
		}
		
		std::string sdp;
		session_description->ToString(&sdp);
		std::string sdType = session_description->type();
		
		spreed_me_log("Received answer. Setting remote description. \n");
		if (negotiationState_ == kPCWNStateIdle) {
			negotiationState_ = kPCWNStateWaitingForRemoteAnswerToBeSet;
			peer_connection_->SetRemoteDescription(SpreedSetSessionDescriptionObserver::Create(this, false, sdType, sdp), session_description);
		} else {
			spreed_me_log("This shouldn't happen. Trying to set remote answer when negotiationState_(%d) != kPCWNStateIdle", negotiationState_);
		}
	} else {
		spreed_me_log("Couldn't create session description from sdp string!");
	}
}


void PeerConnectionWrapper::SetupRemoteCandidate(const std::string &sdp_mid, int sdp_mline_index, const std::string &sdp)
{
	webrtc::IceCandidateInterface* iceCandidate(webrtc::CreateIceCandidate(sdp_mid, sdp_mline_index, sdp));
//	spreed_me_log("cand:===>  %s, %d, %s", sdp_mid.c_str(), sdp_mline_index, sdp.c_str());
	
	if (!_descriptionWasCreated) {
		_pendingCandidates.push_back(iceCandidate);
		return;
	}
	
	peer_connection_->AddIceCandidate(iceCandidate);
	delete iceCandidate;
}


void PeerConnectionWrapper::SetupLocalAnswer(webrtc::SessionDescriptionInterface* desc)
{
	std::string sdp;
	desc->ToString(&sdp);
	std::string sdType = desc->type();
    // Remove all rtx support from locally generated sdp. Chrome
    // does create this sometimes wrong.
    // See https://code.google.com/p/webrtc/issues/detail?id=3962
    std::regex rex("a=rtpmap:(.*) rtx/(.*)\r\na=fmtp:(.*) apt=(.*)\r\n");
    replaceRegexFromSdp(sdp, rex, "");
    desc = webrtc::CreateSessionDescription(sdType, sdp);
	if (negotiationState_ == kPCWNStateIdle) {
		negotiationState_ = kPCWNStateWaitingForLocalAnswerToBeSet;
		peer_connection_->SetLocalDescription(SpreedSetSessionDescriptionObserver::Create(this, true, sdType, sdp), desc);
	} else {
		spreed_me_log("This shouldn't happen. Trying to set local answer when negotiationState_(%d) != kPCWNStateIdle", negotiationState_);
	}
}


void PeerConnectionWrapper::SetupLocalOffer(webrtc::SessionDescriptionInterface* desc)
{
	if (negotiationState_ == kPCWNStateIdle) {
		negotiationState_ = kPCWNStateWaitingForLocalOfferToBeSet;
		std::string sdp;
		desc->ToString(&sdp);
		std::string sdType = desc->type();
		peer_connection_->SetLocalDescription(SpreedSetSessionDescriptionObserver::Create(this, true, sdType, sdp), desc);
	} else {
		spreed_me_log("This shouldn't happen. Trying to set local offer when negotiationState_(%d) != kPCWNStateIdle", negotiationState_);
	}
}


void PeerConnectionWrapper::SetupLocalCandidate(const std::string &sdp_mid, int sdp_mline_index, const std::string &sdp)
{
	
}


#pragma mark - MessageHandler

void PeerConnectionWrapper::OnMessage(rtc::Message* msg)
{
	switch (msg->message_id) {
		case MSG_PCW_PCO_ON_ERROR:
			this->OnError_w();
			break;
			
		case MSG_PCW_PCO_ON_SIGNALING_CHANGE: {
			PlainMessageData<webrtc::PeerConnectionInterface::SignalingState> *param =
				static_cast<PlainMessageData<webrtc::PeerConnectionInterface::SignalingState>*>(msg->pdata);
			this->OnSignalingChange_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_PCO_ON_STATE_CHANGE: {
			PlainMessageData<webrtc::PeerConnectionObserver::StateType> *param =
				static_cast<PlainMessageData<webrtc::PeerConnectionObserver::StateType>*>(msg->pdata);
			this->OnStateChange_w(param->data);
			delete param;
		}
			break;
		
		case MSG_PCW_PCO_ON_ADD_STREAM: {
			PointerMessageData<webrtc::MediaStreamInterface> *param =
				static_cast<PointerMessageData<webrtc::MediaStreamInterface>*>(msg->pdata);
			this->OnAddStream_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_PCO_ON_REMOVE_STREAM: {
			PointerMessageData<webrtc::MediaStreamInterface> *param =
				static_cast<PointerMessageData<webrtc::MediaStreamInterface>*>(msg->pdata);
			this->OnRemoveStream_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_PCO_ON_DATA_CHANNEL: {
			PlainMessageData<ScopedRefPtrDataChannelInteface> *param =
				static_cast<PlainMessageData<ScopedRefPtrDataChannelInteface>*>(msg->pdata);
			this->OnDataChannel_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_PCO_ON_RENEGOTIATION_NEEDED: {
			this->OnRenegotiationNeeded_w();
		}
			break;
			
		case MSG_PCW_PCO_ON_ICE_CONNECTION_CHANGE: {
			PlainMessageData<webrtc::PeerConnectionInterface::IceConnectionState> *param =
				static_cast<PlainMessageData<webrtc::PeerConnectionInterface::IceConnectionState>*>(msg->pdata);
			this->OnIceConnectionChange_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_PCO_ON_ICE_GATHERING_CHANGE: {
			
		}
			break;
			
		case MSG_PCW_PCO_ON_ICE_CANDIDATE: {
			PointerMessageData<IceCandidateStringRepresentation> *param =
				static_cast<PointerMessageData<IceCandidateStringRepresentation>*>(msg->pdata);
			this->OnIceCandidate_w(param->data);
			delete param;
		}
			break;
			
			
		
		case MSG_PCW_CSDO_ON_SUCCESS: {
			PointerMessageData<webrtc::SessionDescriptionInterface> *param =
				static_cast<PointerMessageData<webrtc::SessionDescriptionInterface>*>(msg->pdata);
			this->OnSuccess_w(param->data);
			delete param;
		}
			break;
			
		case MSG_PCW_CSDO_ON_FAILURE: {
			PlainMessageData<std::string> *param = static_cast<PlainMessageData<std::string>*>(msg->pdata);
			this->OnFailure_w(param->data);
			delete param;
		}
			break;
			
		
		case MSG_PCW_SSDO_ON_SUCCESS: {
			SettingSessionDescriptionMessageData *param = static_cast<SettingSessionDescriptionMessageData*>(msg->pdata);
			this->DescriptionIsSet_w(param->isLocalDesc, param->sdType, param->sdp);
			delete param;
		}
			break;
			
		case MSG_PCW_SSDO_ON_FAILURE: {
			SettingSessionDescriptionMessageData *param = static_cast<SettingSessionDescriptionMessageData*>(msg->pdata);
			this->DescriptionSetFailed_w(param->isLocalDesc, param->sdType, param->sdp);
			delete param;
		}
			break;
			
		
		case MSG_PCW_DCO_ON_DATA_CHANNEL_STATE_CHANGE: {
			DataChannelStateMessageData *param = static_cast<DataChannelStateMessageData*>(msg->pdata);
			this->OnDataChannelStateChange_w(param->dataChannel, param->state);
			delete param;
		}
			break;
			
		case MSG_PCW_DCO_ON_DATA_CHANNEL_MESSAGE: {
			DataChannelDataMessageData *param = static_cast<DataChannelDataMessageData*>(msg->pdata);
			this->OnDataChannelMessage_w(param->dataChannel, param->buffer);
			delete param;
		}
			break;
			
		case MSG_PCW_SO_ON_COMPLETE: {
			StatisticsReportMessageData *param = static_cast<StatisticsReportMessageData*>(msg->pdata);
			this->ReceivedStatistics_w(param->track, param->reports);
			delete param;
		}
			break;
			
		default:
			break;
	}
}

