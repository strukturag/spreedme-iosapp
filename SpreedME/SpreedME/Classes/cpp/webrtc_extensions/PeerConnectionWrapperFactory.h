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

#ifndef __SpreedME__PeerConnectionWrapperFactory__
#define __SpreedME__PeerConnectionWrapperFactory__

#include <iostream>
#include <deque>
#include <map>

#include <system_wrappers/interface/critical_section_wrapper.h>
#include <talk/app/webrtc/mediastreaminterface.h>
#include <webrtc/base/thread.h>
#include <talk/media/devices/devicemanager.h>
#include <modules/video_capture/include/video_capture_defines.h>
#include <modules/video_capture/video_capture_impl.h>

#include "CommonCppTypes.h"
#include "PeerConnectionWrapper.h"
#include "MediaConstraints.h"

namespace spreedme {

class PeerConnectionWrapper;

class PeerConnectionWrapperFactory {
public:
	PeerConnectionWrapperFactory();
	virtual ~PeerConnectionWrapperFactory();
	
	rtc::scoped_refptr<PeerConnectionWrapper> CreateSpreedPeerConnection(const std::string &userId,
																			   PeerConnectionWrapperDelegateInterface *pcDelegate = NULL);

	/*
	 These methods allow application to query avaliable video devices and their capabilities.
	 */
	STDStringVector videoDeviceUniqueIDs();
	std::vector<webrtc::VideoCaptureCapability> GetVideoDeviceCaptureCapabilities(const std::string &videoDeviceUniqueId);
	std::string GetLocalizedNameOfVideoDevice(const std::string &videoDeviceUniqueId);

	/*
	 Since we can set constraints only per source and on mobile devices for different reasons
	 it is hard to change or maintain many active devices at the same time we will set constraints per source.
	 This source should be used for one particular call and can't be changed during call. We shouldn't add more than one video/audio source per call.
	 We can change video/audio sources if client implements renegotiation mechanisms. This means that current sources will be closed and disposed of
	 and new sources with new constraints will be created.
	 */
	void SetVideoDeviceId(const std::string &videoDeviceId); // Sets video device ID to be used for videoSource creation
	
	// Sets new constraints and recreates audio source. Disposes of video source if it exists. Video source will be created on next call to CreateLocalStream.
	// PeerConnectionWrapperFactory takes ownership of the constraints
	void SetAudioVideoConstrains(MediaConstraints *audioSourceConstraints, MediaConstraints *videoSourceConstraints);
	void DisposeOfVideoSource(); // stops capturing and disposes of video source
	
	void StopVideoCapturing();
	void StartVideoCapturing();
	
	/* 
	 This method creates local stream(audio/video) for spreedPeerConnection with exactly one audio and one or zero video tracks.
	 This method uses constraints which were set by 'SetAudioVideoConstrains()' method.
	 This method will return NULL if 'SetAudioVideoConstrains()' wasn't called at least once, e.g. no constraints has been set. 
	 You can set no constraints by calling SetAudioVideoConstrains(NULL, NULL).
	 */
	rtc::scoped_refptr<webrtc::MediaStreamInterface> CreateLocalStream(bool withAudio = false, bool withVideo = false);	
	
	void SetMuteAudio(bool mute);
	void SetSpeakerPhone(bool yesNo);
	void AudioInterruptionStarted();
	void AudioInterruptionStopped();
		
	void SetIceServers(webrtc::PeerConnectionInterface::IceServers servers) {iceServers_ = servers;};
		
	rtc::Thread *signaling_thread() {return signaling_thread_;};
	rtc::Thread *worker_thread() {return worker_thread_;};
	
private:
	// Initialization
	bool InitializePeerConnectionFactory();
	void InternalInitializeThreads(); //This method creates and starts signalling and worker threads
	
	std::string GetNewSpreedPeerConnectionId();

// Variables
    webrtc::CriticalSectionWrapper & _critSect;
    rtc::scoped_refptr<webrtc::PeerConnectionFactoryInterface> peer_connection_factory_;
	
	rtc::Thread *worker_thread_;
	rtc::Thread *signaling_thread_;
	
	std::string videoDeviceId_;
	
	rtc::scoped_refptr<webrtc::AudioDeviceModule> adm_;
	rtc::scoped_refptr<webrtc::AudioSourceInterface> audioSource_;
	rtc::scoped_ptr<cricket::DeviceManagerInterface> deviceManager_;
	rtc::scoped_refptr<webrtc::VideoSourceInterface> videoSource_;
	
	webrtc::videocapturemodule::VideoCaptureImpl::DeviceInfo *videoDeviceInfo_;
	
	MediaConstraints *audioConstraints_;
	MediaConstraints *videoConstraints_;
	
	unsigned long long identifierBase_;
	
	webrtc::PeerConnectionInterface::IceServers iceServers_;
	
	cricket::VideoFormat currentCaptureFormat_;
};

} // namespace spreedme

#endif /* defined(__SpreedME__PeerConnectionWrapperFactory__) */
