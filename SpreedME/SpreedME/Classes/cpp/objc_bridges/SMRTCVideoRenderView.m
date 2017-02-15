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

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "SMRTCVideoRenderView.h"

#import <GLKit/GLKit.h>

#import <talk/app/webrtc/objc/public/RTCOpenGLVideoRenderer.h>


// RTCDisplayLinkTimer wraps a CADisplayLink and is set to fire every two screen
// refreshes, which should be 30fps. We wrap the display link in order to avoid
// a retain cycle since CADisplayLink takes a strong reference onto its target.
// The timer is paused by default.
@interface SMRTCDisplayLinkTimer : NSObject

@property(nonatomic) BOOL isPaused;

- (instancetype)initWithTimerHandler:(void (^)(void))timerHandler;
- (void)invalidate;

@end

@implementation SMRTCDisplayLinkTimer
{
	CADisplayLink* _displayLink;
	void (^_timerHandler)(void);
}


- (instancetype)initWithTimerHandler:(void (^)(void))timerHandler
{
	NSParameterAssert(timerHandler);
	if (self = [super init]) {
		_timerHandler = timerHandler;
		_displayLink =
        [CADisplayLink displayLinkWithTarget:self
                                    selector:@selector(displayLinkDidFire:)];
		_displayLink.paused = YES;
		// Set to half of screen refresh, which should be 30fps.
		[_displayLink setFrameInterval:2];
		[_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
						   forMode:NSRunLoopCommonModes];
	}
	return self;
}


- (void)dealloc
{
	[self invalidate];
}


- (BOOL)isPaused
{
	return _displayLink.paused;
}


- (void)setIsPaused:(BOOL)isPaused
{
	_displayLink.paused = isPaused;
}


- (void)invalidate
{
	[_displayLink invalidate];
}


- (void)displayLinkDidFire:(CADisplayLink*)displayLink
{
	_timerHandler();
}


@end




@interface SMRTCVideoRenderView () <GLKViewDelegate>
{
	SMRTCDisplayLinkTimer* _timer;
	GLKView* _glkView;
	RTCOpenGLVideoRenderer* _glRenderer;
}

@property(nonatomic, readonly) GLKView* glkView;
@property(nonatomic, readonly) RTCOpenGLVideoRenderer* glRenderer;
@end


@implementation SMRTCVideoRenderView

- (instancetype)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		EAGLContext* glContext =
        [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		_glRenderer = [[RTCOpenGLVideoRenderer alloc] initWithContext:glContext];
		
		// GLKView manages a framebuffer for us.
		_glkView = [[GLKView alloc] initWithFrame:CGRectZero
										  context:glContext];
		_glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
		_glkView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
		_glkView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
		_glkView.drawableMultisample = GLKViewDrawableMultisampleNone;
		_glkView.delegate = self;
		_glkView.layer.masksToBounds = YES;
		_glkView.transform = CGAffineTransformMakeScale(1, -1);
		[self addSubview:_glkView];
		
		// Listen to application state in order to clean up OpenGL before app goes
		// away.
		NSNotificationCenter* notificationCenter =
        [NSNotificationCenter defaultCenter];
		[notificationCenter addObserver:self
							   selector:@selector(willResignActive)
								   name:UIApplicationWillResignActiveNotification
								 object:nil];
		[notificationCenter addObserver:self
							   selector:@selector(didBecomeActive)
								   name:UIApplicationDidBecomeActiveNotification
								 object:nil];
		
		// Frames are received on a separate thread, so we poll for current frame
		// using a refresh rate proportional to screen refresh frequency. This
		// occurs on the main thread.
		__weak SMRTCVideoRenderView *weakSelf = self;
		_timer = [[SMRTCDisplayLinkTimer alloc] initWithTimerHandler:^{
			if (weakSelf.glRenderer.lastDrawnFrame == weakSelf.i420Frame) {
				return;
			}
			// This tells the GLKView that it's dirty, which will then call the
			// GLKViewDelegate method implemented below.
			[weakSelf.glkView setNeedsDisplay];
		}];
		[self setupGL];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	UIApplicationState appState = [UIApplication sharedApplication].applicationState;
	_glkView.delegate = nil;
	if (appState == UIApplicationStateActive) {
		[self teardownGL];
	}
	[_timer invalidate];
}


#pragma mark - UIView

- (void)layoutSubviews
{
	[super layoutSubviews];
	_glkView.frame = self.bounds;
}


#pragma mark - GLKViewDelegate

// This method is called when the GLKView's content is dirty and needs to be
// redrawn. This occurs on main thread.
- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect
{
	if (self.i420Frame) {
		// The renderer will draw the frame to the framebuffer corresponding to the
		// one used by |view|.
		[_glRenderer drawFrame:self.i420Frame];
	}
}


#pragma mark - Private

- (void)setupGL
{
	[_glRenderer setupGL];
	_timer.isPaused = NO;
}


- (void)teardownGL
{
	_timer.isPaused = YES;
	[_glkView deleteDrawable];
	[_glRenderer teardownGL];
}


- (void)didBecomeActive
{
	[self setupGL];
}


- (void)willResignActive
{
	[self teardownGL];
}


@end
