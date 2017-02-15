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

#import "AudioManager.h"

#import "PeerConnectionController.h"

NSString * const kIncomingMessageInChatSoundFileName			= @"question1.wav";
NSString * const kIncomingMessageSoundFileName					= @"message1.wav";
NSString * const kIncomingCallSoundFileName						= @"whistle1.wav";
NSString * const kOutgoingCallSoundFileName						= @"ringtone1.wav";
NSString * const kRemoteUserHungUpCallSoundFileName				= @"end1.wav";
NSString * const kLocalUserHungUpSoundFileName					= @"end1.wav";
NSString * const kRemoteUserRejectedSoundFileName				= @"";

const NSTimeInterval kIntevalBetweenSoundForOutgoingCall = 2.0;
const NSTimeInterval kIntevalBetweenSoundForIncomingCall = 4.0;

@interface AudioManager ()
{
	AVAudioPlayer *_audioPlayer;
    NSTimer *_soundLoopTimer;
}

@end

@implementation AudioManager

+ (AudioManager *)defaultManager
{
	static dispatch_once_t once;
    static AudioManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


#pragma mark Audio


- (AVAudioPlayer *)audioPlayerWithSoundName:(NSString *)soundName
{
	NSError *error;
	NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], soundName]];
	AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
	
	return audioPlayer;
}


- (void)stopPlaying
{
	[_audioPlayer stop];
	[_soundLoopTimer invalidate];
	_soundLoopTimer = nil;
    
    if (![PeerConnectionController sharedInstance].inCall) {
        //TODO: Check if we can freely do that. There is the situation when we interfere with audio from call!
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        NSError *errorSession = nil;
        BOOL success = NO;
        success = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&errorSession];
        if (!success) {
            spreed_me_log("Error overriding sound route to none! error %s", [errorSession cDescription]);
        }
    }
}


- (void)playSoundForOutgoingCallWithVideo:(BOOL)video
{
	[_audioPlayer stop];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    NSError *errorSession = nil;
    BOOL success = NO;
    
    if (!video) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&errorSession];
        success = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&errorSession];
        if (!success) {
            spreed_me_log("Error overriding sound route to none! error %s", [errorSession cDescription]);
        }
    }
	
	_audioPlayer = [self audioPlayerWithSoundName:kOutgoingCallSoundFileName];
	_audioPlayer.numberOfLoops = 0;
	
	[_soundLoopTimer invalidate];
	[_audioPlayer play];
	_soundLoopTimer = [NSTimer scheduledTimerWithTimeInterval:kIntevalBetweenSoundForOutgoingCall + _audioPlayer.duration
													   target:_audioPlayer
													 selector:@selector(play) userInfo:nil repeats:YES];
}


- (void)playSoundForIncomingCall
{
	[_audioPlayer stop];
	
	// We assume here that audio_device_ios.cc in webrtc has already setup session to be PlayAndRecord
	AVAudioSession *audioSession = [AVAudioSession sharedInstance];
	NSError *errorSession = nil;
	BOOL success = NO;
	success = [audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&errorSession];
	if (!success) {
		spreed_me_log("Error overriding sound route to speaker! error %s", [errorSession cDescription]);
	}
	
	_audioPlayer = [self audioPlayerWithSoundName:kIncomingCallSoundFileName];
	_audioPlayer.numberOfLoops = 0;
	
	[_soundLoopTimer invalidate];
	[_audioPlayer play];
	_soundLoopTimer = [NSTimer scheduledTimerWithTimeInterval:kIntevalBetweenSoundForIncomingCall + _audioPlayer.duration
													   target:_audioPlayer
													 selector:@selector(play) userInfo:nil repeats:YES];
}


- (void)playSoundOnCallIsFinished
{
	[self stopPlaying];
    
    NSError *errorSession = nil;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategorySoloAmbient error:&errorSession];
    
    if (!_audioPlayer) {
		NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], kLocalUserHungUpSoundFileName]];
		
		NSError *error;
		_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
	}
    
	[_audioPlayer stop];
	
	_audioPlayer = [self audioPlayerWithSoundName:kRemoteUserHungUpCallSoundFileName];
	_audioPlayer.numberOfLoops = 0;
	
	[_audioPlayer play];
}


- (void)playSoundForRemoteUserRejected
{
	[self stopPlaying];
}


- (void)playSoundForIncomingMessageInChat
{
    if (!_audioPlayer) {
		NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], kIncomingMessageInChatSoundFileName]];
		
		NSError *error;
		_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
	}
    
	[_audioPlayer stop];
	
	_audioPlayer = [self audioPlayerWithSoundName:kIncomingMessageInChatSoundFileName];
	_audioPlayer.numberOfLoops = 0;
	
    if (![PeerConnectionController sharedInstance].inCall) {
        [_audioPlayer play];
    }
}


- (void)playSoundForIncomingMessage
{
    if (!_audioPlayer) {
		NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], kIncomingMessageSoundFileName]];
		
		NSError *error;
		_audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
	}
    
	[_audioPlayer stop];
	
	_audioPlayer = [self audioPlayerWithSoundName:kIncomingMessageSoundFileName];
	_audioPlayer.numberOfLoops = 0;
	
	if (![PeerConnectionController sharedInstance].inCall) {
        [_audioPlayer play];
    }
}

@end
