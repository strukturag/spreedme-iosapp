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

#ifndef __SpreedME__SpreedPeerConnection__
#define __SpreedME__SpreedPeerConnection__

#include <deque>
#include <map>
#include <regex>

#include <modules/audio_device/include/audio_device.h>
#include <system_wrappers/interface/critical_section_wrapper.h>
#include <talk/app/webrtc/mediastreaminterface.h>
#include <talk/app/webrtc/peerconnectioninterface.h>
#include <webrtc/base/messagehandler.h>
#include <webrtc/base/messagequeue.h>
#include <third_party/jsoncpp/source/include/json/json.h>

#include "Error.h"
#include "MediaConstraints.h"
#include "MessageQueueInterface.h"
#include "utils.h"
#include "VideoRenderer.h"
#include "VideoRendererInfo.h"
#include "WebrtcCommonDefinitions.h"

namespace spreedme {

extern const char kDefaultDataChannelLabel[];


typedef enum PeerConnectionWrapperInternalState
{
	kPCWIStateReady,
	kPCWIStateCreatingDescriptionForOffer,
	kPCWIStateCreatingDescriptionForAnswer
}
PeerConnectionWrapperInternalState;


typedef enum PeerConnectionWrapperNegotiationState
{
	kPCWNStateIdle,
	kPCWNStateWaitingForLocalOfferToBeSet,
	kPCWNStateWaitingForRemoteOfferToBeSet,
	kPCWNStateWaitingForLocalAnswerToBeSet,
	kPCWNStateWaitingForRemoteAnswerToBeSet,
}
PeerConnectionWrapperNegotiationState;
	
	
class PeerConnectionWrapper;
class DataChannelObserver;

class PeerConnectionWrapperDelegateInterface {
	
public:
	virtual void IceConnectionStateChanged(webrtc::PeerConnectionInterface::IceConnectionState new_state, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void SignallingStateChanged(webrtc::PeerConnectionInterface::SignalingState new_state, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void PeerConnectionObjectHasBeenCreated(PeerConnectionWrapper *peerConnectionWrapper) = 0;
	
	virtual void AnswerIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void OfferIsReadyToBeSent(const std::string &sdType, const std::string &sdp, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	virtual void CandidateIsReadyToBeSent(IceCandidateStringRepresentation *candidateStringRep, PeerConnectionWrapper *peerConnectionWrapper) = 0;
	
	virtual void DataChannelStateChanged(webrtc::DataChannelInterface::DataState state, webrtc::DataChannelInterface *data_channel, PeerConnectionWrapper *wrapper) = 0;
	
	virtual void ReceivedDataChannelData(webrtc::DataBuffer *buffer,
										 webrtc::DataChannelInterface *data_channel,
										 PeerConnectionWrapper *wrapper) = 0;
	
	// These methods are not pure virtual because we can consider them as optional
	virtual void PeerConnectionWrapperHasReceivedStats(PeerConnectionWrapper *peerConnectionWrapper, const webrtc::StatsReports &reports) {};
	virtual void PeerConnectionWrapperHasFailedToReceiveStats(PeerConnectionWrapper *peerConnectionWrapper) {};
	
	virtual void VideoRendererWasSetup(PeerConnectionWrapper *peerConnectionWrapper,
									   const VideoRendererInfo &info) {};
	virtual void VideoRendererHasChangedFrameSize(PeerConnectionWrapper *peerConnectionWrapper,
												  const VideoRendererInfo &info) {};
	virtual void VideoRendererWasDeleted(PeerConnectionWrapper *peerConnectionWrapper,
										 const VideoRendererInfo &info) {};
	virtual void FailedToSetupVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
											const VideoRendererInfo &info,
											VideoRendererManagementError error) {};
	virtual void FailedToDeleteVideoRenderer(PeerConnectionWrapper *peerConnectionWrapper,
											 const VideoRendererInfo &info,
											 VideoRendererManagementError error) {};
	
	virtual void LocalStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void LocalStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void RemoteStreamHasBeenAdded(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper) {};
	virtual void RemoteStreamHasBeenRemoved(webrtc::MediaStreamInterface *stream, PeerConnectionWrapper *peerConnectionWrapper) {};
	
	virtual void PeerConnectionWrapperHasEncounteredError(PeerConnectionWrapper *peerConnectionWrapper, const Error &error) {};
	
	virtual ~PeerConnectionWrapperDelegateInterface() {};
};



typedef std::map <std::string, rtc::scoped_refptr<webrtc::DataChannelInterface> > DataChannelsMap;
typedef std::pair<std::string, rtc::scoped_refptr<webrtc::DataChannelInterface> > DataChannelPair;
	

typedef rtc::scoped_refptr<webrtc::DataChannelInterface> ScopedRefPtrDataChannelInteface;

class SpreedSetSessionDescriptionObserver;

	
// PeerConnectionWrapper is NOT thread safe!
// PeerConnectionWrapper grabs the thread in which it was created
// and uses it to redirect all calls from underlying 'peer_connection_' observers
// in order to work in single thread.
class PeerConnectionWrapper : public webrtc::PeerConnectionObserver,
							  public webrtc::CreateSessionDescriptionObserver,
							  public rtc::MessageHandler,
							  public VideoRendererDelegateInterface
{
public:
	
	PeerConnectionWrapper(const std::string &factoryId,
						  PeerConnectionWrapperDelegateInterface *delegate);
	
	virtual void Close();
	virtual void Shutdown();
	
	// Communication
	virtual void CreateOffer(const std::string recepientId);
	
	virtual void SetupRemoteAnswer(const std::string &sdp);
	virtual void SetupRemoteOffer(const std::string &sdp);
	virtual void SetupRemoteCandidate(const std::string &sdp_mid, int sdp_mline_index, const std::string &sdp);
	
	virtual void SetupLocalAnswer(webrtc::SessionDescriptionInterface* desc);
	virtual void SetupLocalOffer(webrtc::SessionDescriptionInterface* desc);
	virtual void SetupLocalCandidate(const std::string &sdp_mid, int sdp_mline_index, const std::string &sdp);
	
	// proxy SetRemoteDescriptionObserver implementation
	virtual void DescriptionIsSet(bool isLocalDesc, const std::string &sdType, const std::string &sdp);
	virtual void DescriptionSetFailed(bool isLocalDesc, const std::string &sdType, const std::string &sdp);
	
	// Data channels
	virtual rtc::scoped_refptr<webrtc::DataChannelInterface> CreateDataChannel(const std::string &label, webrtc::DataChannelInit *config);
	virtual void SendData(const std::string &msg); //sends data through the default channel
	virtual void SendData(const void *data, size_t size); //sends data through the default channel
	virtual void SendData(const std::string &msg, const std::string &dataChannelName); // tries to send data through data channel with given name
	virtual void SendData(const void *data, size_t size, const std::string &dataChannelName); // tries to send data through data channel with given name
	
	virtual bool HasOpenedDataChannel();
	virtual std::string FirstOpenedDataChannelName();
	virtual rtc::scoped_refptr<webrtc::DataChannelInterface> DataChannelForName(const std::string &name);
	virtual std::set<std::string> DataChannelNames();
	
	// proxy DataChannelObserver implementation
	virtual void OnDataChannelStateChange(webrtc::DataChannelInterface *data_channel,
										  webrtc::DataChannelInterface::DataState state);
	virtual void OnDataChannelMessage(webrtc::DataChannelInterface *data_channel, webrtc::DataBuffer *buffer);
	
	
	// Getting statistics reports
	virtual void RequestStatisticsReportsForAllStreams();
	virtual void ReceivedStatistics(webrtc::MediaStreamTrackInterface *track, webrtc::StatsReports reports);
	
	//applied to all audio channels
	virtual void SetMuteAudio(bool mute);
	//applied to all video channels
	virtual void SetMuteVideo(bool mute);
	
	virtual void DisableAllVideo();
	virtual void EnableAllVideo();
	
	virtual bool IsVideoPermittedByConstraints();
	
	// RendererNames are expected to be unique for the peer connection wrapper.
	// If you try to setup renderers with the same name for different streams/videoTracks
	// you will receive FailedToSetupVideoRenderer callback with error 'kVRMERendererAlreadyExists'.
	virtual void SetupVideoRenderer(const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName);
	virtual void DeleteVideoRenderer(const std::string &streamLabel, const std::string &videoTrackId, const std::string &rendererName);
	
//	virtual void SetSpeakerPhone(bool yes);
	
	//States of peer connection
	virtual webrtc::PeerConnectionInterface::SignalingState signalingState() {return signalingState_;};
	virtual webrtc::PeerConnectionInterface::IceConnectionState iceConnectionState() {return iceConnectionState_;};
	
	virtual MediaConstraints* connectionConstraintsRef();
	virtual void SetConnectionConstraints(const MediaConstraints &constraints);
	virtual MediaConstraints* sessionDescriptionConstraintsRef();
	virtual void SetSessionDescriptionConstraints(const MediaConstraints &constraints);
	
	// This method should be used before any interaction with peerConnection otherwise behavior is undefined
	virtual void SetPeerConnection(rtc::scoped_refptr<webrtc::PeerConnectionInterface> peerConnection);
	
	virtual void SetPeerConnectionBridge(PeerConnectionWrapperDelegateInterface *pcBridge);
	
	virtual void AddLocalStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream, const webrtc::MediaConstraintsInterface* constraints);
	virtual void RemoveLocalStream(rtc::scoped_refptr<webrtc::MediaStreamInterface> stream);// Please keep in mind that this might require session renegotiation
	virtual rtc::scoped_refptr<webrtc::StreamCollectionInterface> remote_streams() { return peer_connection_->remote_streams(); };
	virtual rtc::scoped_refptr<webrtc::StreamCollectionInterface> local_streams() { return peer_connection_->local_streams(); };
	
	virtual void SetCustomIdentifier(const std::string &customIdentifier) {customIdentifier_ = customIdentifier;};
	virtual std::string customIdentifier() {return customIdentifier_;};
	
	virtual void SetUserId(const std::string &userId) {userId_ = std::string(userId);};
	virtual std::string userId() {return userId_;};
	
	virtual std::string factoryId() {return factoryId_;};
	
protected:
    
    //
    // PeerConnectionObserver implementation.
    //
	virtual void OnSignalingChange(webrtc::PeerConnectionInterface::SignalingState new_state);
    virtual void OnError();
    virtual void OnStateChange(webrtc::PeerConnectionObserver::StateType state_changed);
    virtual void OnAddStream(webrtc::MediaStreamInterface* stream);
    virtual void OnRemoveStream(webrtc::MediaStreamInterface* stream);
	virtual void OnRenegotiationNeeded();
    virtual void OnIceCandidate(const webrtc::IceCandidateInterface* candidate);
	virtual void OnDataChannel(webrtc::DataChannelInterface* data_channel);
	virtual void OnIceConnectionChange(webrtc::PeerConnectionInterface::IceConnectionState new_state);
	virtual void OnSignalingChange_w(webrtc::PeerConnectionInterface::SignalingState new_state);
	virtual void OnError_w();
	virtual void OnStateChange_w(webrtc::PeerConnectionObserver::StateType state_changed);
	virtual void OnAddStream_w(webrtc::MediaStreamInterface* stream);
	virtual void OnRemoveStream_w(webrtc::MediaStreamInterface* stream);
	virtual void OnRenegotiationNeeded_w();
	virtual void OnIceCandidate_w(IceCandidateStringRepresentation* candidate);
	virtual void OnDataChannel_w(ScopedRefPtrDataChannelInteface scopedDataCchannel);
	virtual void OnIceConnectionChange_w(webrtc::PeerConnectionInterface::IceConnectionState new_state);
	
	
	// Data channels
	void CreateDefaultDataChannel();
	
    // CreateSessionDescriptionObserver implementation.
    virtual void OnSuccess(webrtc::SessionDescriptionInterface* desc);
    virtual void OnFailure(const std::string& error);
	virtual void OnSuccess_w(webrtc::SessionDescriptionInterface* desc);
	virtual void OnFailure_w(const std::string& error);
	
	// proxy SetRemoteDescriptionObserver implementation
	virtual void DescriptionIsSet_w(bool isLocalDesc, const std::string &sdType, const std::string &sdp);
	virtual void DescriptionSetFailed_w(bool isLocalDesc, const std::string &sdType, const std::string &sdp);
	
	// proxy DataChannelObserver implementation
	virtual void OnDataChannelStateChange_w(webrtc::DataChannelInterface *data_channel,
										  webrtc::DataChannelInterface::DataState state);
	virtual void OnDataChannelMessage_w(webrtc::DataChannelInterface *data_channel, webrtc::DataBuffer *buffer);
	
	// Renderer delegate
	virtual void FrameSizeHasBeenSet(VideoRenderer *renderer, int width, int height);
	
	// Statistics
	virtual void ReceivedStatistics_w(webrtc::MediaStreamTrackInterface *track, webrtc::StatsReports reports);
	
	// MessageHandler
	virtual void OnMessage(rtc::Message* msg);
	
	virtual ~PeerConnectionWrapper();
	
private:
	//Utilities
	bool InsertNewDataChannelWithName(rtc::scoped_refptr<webrtc::DataChannelInterface> dataChannel, const std::string &name);
    void replaceStringFromSdp(std::string& str, const std::string& from, const std::string& to);
    void replaceRegexFromSdp(std::string& str, std::regex& regex, const std::string& replace_with);
	
// Variables
    webrtc::CriticalSectionWrapper & _critSect;
    rtc::scoped_refptr<webrtc::PeerConnectionInterface> peer_connection_;
	rtc::Thread *workerThread_;
    std::map< std::string, rtc::scoped_refptr<webrtc::MediaStreamInterface> > local_active_streams_;
	std::map<std::string, VideoRenderer*> renderersMap_;
	
	bool _descriptionWasCreated;
	
	PeerConnectionWrapperInternalState internalState_;
	PeerConnectionWrapperNegotiationState negotiationState_;
	webrtc::PeerConnectionInterface::IceConnectionState iceConnectionState_;
	webrtc::PeerConnectionInterface::SignalingState signalingState_;
	
	DataChannelsMap data_channels_;
	std::set<DataChannelObserver *> dataChannelObesrvers_;
	
	MediaConstraints connectionConstraints_;
	MediaConstraints sessionDescriptionConstraints_;
	
	std::deque<webrtc::IceCandidateInterface *> _pendingCandidates;
	
	std::string customIdentifier_;
	std::string userId_;
	std::string factoryId_;
	
	bool videoMuted_;

	PeerConnectionWrapperDelegateInterface *delegate_;

public:
	
	template<typename T>
	struct PointerMessageData : public rtc::MessageData {
		PointerMessageData(T* data) : data(data) {};
		PointerMessageData(const T* cData) {
			data = const_cast<T*>(cData);
		};
		
		T *data;
	};
	
	template<typename T>
	struct PlainMessageData : public rtc::MessageData  {
		PlainMessageData(T data) : data(data) {};
		
		T data;
	};
	
	struct SettingSessionDescriptionMessageData : public rtc::MessageData {
		SettingSessionDescriptionMessageData(bool isLocalDesc, const std::string &sdType, const std::string &sdp) :
			isLocalDesc(isLocalDesc), sdType(sdType), sdp(sdp) {};
		
		bool isLocalDesc;
		std::string sdType;
		std::string sdp;
	};
	
	
	struct DataChannelStateMessageData : public rtc::MessageData {
		DataChannelStateMessageData(webrtc::DataChannelInterface *dataChannel,
									webrtc::DataChannelInterface::DataState state):
		dataChannel(dataChannel), state(state) {};
		
		webrtc::DataChannelInterface *dataChannel;
		webrtc::DataChannelInterface::DataState state;
	};
	
	struct DataChannelDataMessageData : public rtc::MessageData {
		
		DataChannelDataMessageData(webrtc::DataChannelInterface *dataChannel,
								   webrtc::DataBuffer *buffer) :
		dataChannel(dataChannel), buffer(buffer) {};
		
		webrtc::DataChannelInterface *dataChannel;
		webrtc::DataBuffer *buffer;
	};
	
	struct StatisticsReportMessageData : public rtc::MessageData {
		
		StatisticsReportMessageData(webrtc::MediaStreamTrackInterface *track,
								   webrtc::StatsReports reports) :
		track(track), reports(reports) {};
		
		webrtc::MediaStreamTrackInterface *track;
		webrtc::StatsReports reports;
	};
};


class SpreedSetSessionDescriptionObserver : public webrtc::SetSessionDescriptionObserver
{
	
public:
	
	static SpreedSetSessionDescriptionObserver* Create(PeerConnectionWrapper *connectionHandler, bool isLocalDesc, const std::string &sdType, const std::string &sdp) {
        return
		new rtc::RefCountedObject<SpreedSetSessionDescriptionObserver>(connectionHandler, isLocalDesc, sdType, sdp);
    }
	
	virtual void OnSuccess()
	{
		if (peerConnectionWrapper_ != NULL) {
			peerConnectionWrapper_->DescriptionIsSet(isLocalDesc_, sdType_, sdp_);
		}
		return;
	};
	
	virtual void OnFailure(const std::string& error) {
		spreed_me_log("%s \n", error.c_str());
		if (peerConnectionWrapper_ != NULL) {
			peerConnectionWrapper_->DescriptionSetFailed(isLocalDesc_, sdType_, sdp_);
		}
		return;
	};
	
protected:
	
	SpreedSetSessionDescriptionObserver(PeerConnectionWrapper *connectionWrapper, bool isLocalDesc, const std::string &sdType, const std::string &sdp) :
	peerConnectionWrapper_(connectionWrapper),
	isLocalDesc_(isLocalDesc),
	sdType_(sdType),
	sdp_(sdp)
	{
	};
	
	~SpreedSetSessionDescriptionObserver() {};
	
	PeerConnectionWrapper *peerConnectionWrapper_;
	bool isLocalDesc_;
	std::string sdType_;
	std::string sdp_;
};


class DataChannelObserver : public webrtc::DataChannelObserver,
							public rtc::RefCountInterface
{
public:
	
	static DataChannelObserver* Create(PeerConnectionWrapper *connectionHandler,
											 webrtc::DataChannelInterface *data_channel) {
        return new rtc::RefCountedObject<DataChannelObserver>(connectionHandler, data_channel);
    }
	
	// DatachannelObserver implementation
	virtual void OnStateChange() {
		if (peerConnectionWrapper_ != NULL) {
			peerConnectionWrapper_->OnDataChannelStateChange(data_channel_, data_channel_->state());
		}
	}
	
	virtual void OnMessage(const webrtc::DataBuffer& buffer) {
		if (peerConnectionWrapper_ != NULL) {
			peerConnectionWrapper_->OnDataChannelMessage(data_channel_, new webrtc::DataBuffer(buffer));
		}
	}

protected:
	DataChannelObserver(PeerConnectionWrapper *connectionWrapper, webrtc::DataChannelInterface *data_channel) :
		peerConnectionWrapper_(connectionWrapper),
	data_channel_(data_channel) {};
	
	DataChannelObserver() {};
	
	~DataChannelObserver() {
		spreed_me_log("Deleting datachannel observer");
	};
	
	PeerConnectionWrapper *peerConnectionWrapper_;
	webrtc::DataChannelInterface *data_channel_;
};

	
class StatisticsObserver : public webrtc::StatsObserver
{
public:
	
    virtual void OnComplete(const webrtc::StatsReports& reports) {
		peerConnectionWrapper_->ReceivedStatistics(track_, reports);
	};
	
protected:
	StatisticsObserver(PeerConnectionWrapper *connectionWrapper, webrtc::MediaStreamTrackInterface *track) :
		peerConnectionWrapper_(connectionWrapper),
		track_(track) {};
	
	StatisticsObserver() {};
	
	PeerConnectionWrapper *peerConnectionWrapper_;
	webrtc::MediaStreamTrackInterface *track_;
};
	
	
} // namespace spreedme

#endif /* defined(__SpreedME__SpreedPeerConnection__) */
