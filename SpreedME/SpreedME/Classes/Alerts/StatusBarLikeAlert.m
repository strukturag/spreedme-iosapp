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

#import "StatusBarLikeAlert.h"


@interface StatusBarLikeAlert ()
{
	NSAttributedString *_message;

	void (^_tapBlock)(void);
	
	UILabel *_messageLabel;
	
	UIView *_redAlertView;
	
	NSTimer *_animationTimer;
	BOOL _outAnimation;
}

@end


@implementation StatusBarLikeAlert

#pragma mark - Lifecycle

- (instancetype)initWithAttributedMessage:(NSAttributedString *)message actionBlock:(void (^)(void))actionBlock
{
	self = [super init];
	if (self) {
		_message = [message copy];
		
		[self createView];
		
		if (actionBlock) {
			_tapBlock = [actionBlock copy];
		}
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarFrameOrOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarFrameOrOrientationChanged:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
	}
	return self;
}


- (instancetype)initWithMessage:(NSString *)message actionBlock:(void (^)(void))actionBlock
{
	return [self initWithAttributedMessage:[[NSAttributedString alloc] initWithString:message] actionBlock:actionBlock];
}


- (instancetype)init
{
	return [self initWithAttributedMessage:nil actionBlock:nil];
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -

- (void)createView
{
	const CGFloat kViewWidth = 200.0f;
	const CGFloat kViewHeight = 44.0f;
	
    _alertView = [[RetainingView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kViewWidth, kViewHeight)];
    _alertView.objectToRetain = self;
    _alertView.backgroundColor = [UIColor clearColor];
	
	_redAlertView = [[UIView alloc] initWithFrame:_alertView.bounds];
	_redAlertView.backgroundColor = [UIColor redColor];
	_redAlertView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_redAlertView.userInteractionEnabled = NO;
	[_alertView addSubview:_redAlertView];
    
    _messageLabel = [[UILabel alloc] initWithFrame:_redAlertView.bounds];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.numberOfLines = 1;
    _messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
	_messageLabel.textAlignment = NSTextAlignmentCenter;
    [_redAlertView addSubview:_messageLabel];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewWasTapped:)];
    [_alertView addGestureRecognizer:tapGesture];
}


#pragma mark -

- (void)show
{
	if (!_animationTimer) {
		UIWindow *window = [UIApplication sharedApplication].delegate.window;
		
		[self rotateOnlyAccordingToStatusBarOrientationAndSupportedOrientations];
		[self centerViewForAnyOrientation];
		[self prepareViewForBeginningShowAnimation];
		
		_messageLabel.attributedText = _message;
		
		[window addSubview:_alertView];
		
		_animationTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(animateWithTimer:) userInfo:nil repeats:YES];
		
		[self prepareViewForShowAnimation];
	}
}


- (void)dismiss
{
	[self stopAnimating];
	
	[_alertView removeFromSuperview];
	_alertView = nil;
}


#pragma mark -

- (void)animateWithTimer:(NSTimer *)theTimer
{
	NSTimeInterval interval = theTimer.timeInterval;
	
	if (_outAnimation) {
		[UIView animateWithDuration:interval animations:^{
			_redAlertView.alpha = 0.5;
		} completion:^(BOOL finished) {}];
	} else {
		[UIView animateWithDuration:interval animations:^{
			_redAlertView.alpha = 0.0;
		} completion:^(BOOL finished) {}];
	}
	_outAnimation = !_outAnimation;
}

- (void)stopAnimating
{
	[_animationTimer invalidate];
	_animationTimer = nil;
}


#pragma mark - Tap

- (void)viewWasTapped:(id)sender
{
	if (_tapBlock) {
		_tapBlock();
		_tapBlock = nil;
	}
	
	[self dismiss];
}


@end
