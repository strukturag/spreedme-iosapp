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

#import "SoftAlert.h"

#import "AnimationView.h"

static const NSTimeInterval kDismissInterval = 1.5;

@interface SoftAlert ()
{
	UIImage *_image;
	NSString *_title;
	NSString *_message;
	
	SEL _selector;
	id _target;
    id _selectorArgument1;
	id _selectorArgument2;
	
	void (^_tapBlock)(void);
	
	UIImageView *_imageView;
	UILabel *_titleLabel;
	UILabel *_messageLabel;
	
	NSTimer *_dismissTimer;
	
	NSMutableArray *_animations;
}


@end


@implementation SoftAlert

#pragma mark - Public Methods

// Designated initializer
- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image target:(id)target selector:(SEL)selector
{
	self = [super init];
	if (self) {
		_title = [title copy];
		_message = [message copy];
		_image = image;
		if (target && selector) {
			_target = target;
			_selector = selector;
		}
		
		[self createView];
		[self prepareDissolveAnimations];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarFrameOrOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarFrameOrOrientationChanged:) name:UIApplicationDidChangeStatusBarFrameNotification object:nil];
	}
	
	return self;
}


- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image target:(id)target selector:(SEL)selector selectorArgument:(id)selectorArgument
{
	self = [self initWithTitle:title message:message image:image target:target selector:selector];
	if (self) {
		_selectorArgument1 = selectorArgument;
	}
	
	return self;
}


- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image target:(id)target selector:(SEL)selector selectorArgument:(id)selectorArgument1 selectorArgument:(id)selectorArgument2
{
	self = [self initWithTitle:title message:message image:image target:target selector:selector];
	if (self) {
		_selectorArgument1 = selectorArgument1;
		_selectorArgument2 = selectorArgument2;
	}
	
	return self;
}


- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message image:(UIImage *)image actionBlock:(void (^)(void))actionBlock
{
	self = [self initWithTitle:title message:message image:image target:nil selector:nil];
	if (self) {
		_tapBlock = [actionBlock copy];
	}
	
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -

- (void)show
{
	UIWindow *window = [UIApplication sharedApplication].delegate.window;
	
	[self rotateOnlyAccordingToStatusBarOrientationAndSupportedOrientations];
	[self centerViewForAnyOrientation];
	[self prepareViewForBeginningShowAnimation];
	
	_imageView.image = _image;
	_titleLabel.text = _title;
	_messageLabel.text = _message;
	
	[UIView animateWithDuration:0.5 animations:^{
		[window addSubview:_alertView];
		[self prepareViewForShowAnimation];
	} completion:^(BOOL finished) {
		_dismissTimer = [NSTimer scheduledTimerWithTimeInterval:kDismissInterval target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
	}];
}


#pragma mark -

- (CGFloat)neededWidthForLabel:(UILabel *)label withText:(NSString *)text
{
    UILabel *neededLabel = [[UILabel alloc] init];
    neededLabel.font = label.font;
    neededLabel.text = text;
    neededLabel.numberOfLines = 1;
    neededLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    
    CGSize maximumLabelSize = label.frame.size;
    CGSize expectSize = [neededLabel sizeThatFits:maximumLabelSize];
    CGFloat neededWidth = (expectSize.width > label.frame.size.width) ? label.frame.size.width : expectSize.width;
    
    return neededWidth;
}


#pragma mark -

- (void)createView
{
	const CGFloat kMaxViewWidth = 300.0f;
    const CGFloat kMaxViewWidthiPad = 500.0f;
	const CGFloat kViewHeight = 60.0f;
	
	const CGFloat kPadding = 5.0f;
	
	const CGFloat kHorisontalEdgeOffset = 5.0f;
	const CGFloat kVerticalEdgeOffset = 5.0f;
	
	const CGFloat kImageWidth = 50.0f;
	
	const CGFloat kTitleLabelHeight = 22.0f;
	
    UIColor *backgroundColor = kSoftAlertBackgroundColor;
    
    CGFloat labelMaxWidth = kMaxViewWidth - (2 * kHorisontalEdgeOffset) - kPadding - kImageWidth;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        labelMaxWidth = kMaxViewWidthiPad - (2 * kHorisontalEdgeOffset) - kPadding - kImageWidth;
    }
    
    _alertView = [[RetainingView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, kMaxViewWidth, kViewHeight)];
    _alertView.objectToRetain = self;
    _alertView.backgroundColor = backgroundColor;
    
    // border radius
    [_alertView.layer setCornerRadius:kSoftAlertCornerRadius];
    
    // border
    [_alertView.layer setBorderColor:[UIColor lightGrayColor].CGColor];
    [_alertView.layer setBorderWidth:1.0f];
    
    // drop shadow
    [_alertView.layer setShadowColor:[UIColor darkGrayColor].CGColor];
    [_alertView.layer setShadowOpacity:0.8];
    [_alertView.layer setShadowRadius:3.0];
    [_alertView.layer setShadowOffset:CGSizeMake(2.0, 2.0)];
		
    _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(kHorisontalEdgeOffset, kVerticalEdgeOffset, kImageWidth, kImageWidth)];
    _imageView.backgroundColor = [UIColor clearColor];
    _imageView.contentMode = UIViewContentModeScaleAspectFit;
    _imageView.userInteractionEnabled = NO;
    [_alertView addSubview:_imageView];
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(kHorisontalEdgeOffset + kImageWidth + kPadding, kVerticalEdgeOffset,
                                                            labelMaxWidth, kTitleLabelHeight)];
    _titleLabel.backgroundColor = [UIColor clearColor];
    _titleLabel.numberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    
    
    CGFloat titleLabelWidth = [self neededWidthForLabel:_titleLabel withText:_title];
    _titleLabel.frame = CGRectMake(_titleLabel.frame.origin.x, _titleLabel.frame.origin.y,
                                   titleLabelWidth,_titleLabel.frame.size.height);
    
    [_alertView addSubview:_titleLabel];
    
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(_titleLabel.frame.origin.x,
                                                              _alertView.bounds.size.height - _titleLabel.frame.origin.y - _titleLabel.frame.size.height - kPadding,
                                                              labelMaxWidth,
                                                              _alertView.bounds.size.height - _titleLabel.frame.size.height - kVerticalEdgeOffset * 2 - kPadding)];
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.numberOfLines = 1;
    _messageLabel.adjustsFontSizeToFitWidth = YES;
    _messageLabel.minimumScaleFactor = 0.8;
    _messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _messageLabel.font = [UIFont systemFontOfSize:16.0f];
    
    CGFloat messageLabelWidth = [self neededWidthForLabel:_messageLabel withText:_message];
    _messageLabel.frame = CGRectMake(_messageLabel.frame.origin.x, _messageLabel.frame.origin.y,
                                     messageLabelWidth,_messageLabel.frame.size.height);
    
    [_alertView addSubview:_messageLabel];
    
    CGFloat alertViewWidth = (titleLabelWidth > messageLabelWidth) ? titleLabelWidth : messageLabelWidth;
    alertViewWidth = alertViewWidth + (2 * kHorisontalEdgeOffset) + kPadding + kImageWidth;
    
    _alertView.frame = CGRectMake(_alertView.frame.origin.x, _alertView.frame.origin.y,
                                  alertViewWidth, _alertView.frame.size.height);
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewWasTapped:)];
    [_alertView addGestureRecognizer:tapGesture];
}


- (void)viewWasTapped:(id)sender
{
	if (_target) {
		
		NSMethodSignature *msig = [_target methodSignatureForSelector:_selector];
		if (msig != nil) {
			NSUInteger nargs = [msig numberOfArguments];
			if (nargs == 2) { // 0 non-hidden arguments
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				// We assume that selector returns nothing (void) so there shouldn't be any problem or leak.
				[_target performSelector:_selector];
#pragma clang diagnostic pop
				_target = nil;
			}
			else if (nargs == 3) { // 1 non-hidden argument
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				// We assume that selector returns nothing (void) so there shouldn't be any problem or leak.
				[_target performSelector:_selector withObject:_selectorArgument1];
#pragma clang diagnostic pop
				_target = nil;
			}
			else if (nargs == 4) { // 1 non-hidden argument
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				// We assume that selector returns nothing (void) so there shouldn't be any problem or leak.
				[_target performSelector:_selector withObject:_selectorArgument1 withObject:_selectorArgument2];
#pragma clang diagnostic pop
				_target = nil;
			} else {
				NSAssert(NO, @"Wrong parameter number in selector. We support only 0, 1 or 2 parameters!");
			}
		}
	} else if (_tapBlock) {
		_tapBlock();
		_tapBlock = nil;
	}
	
	[self dismiss];
}


- (void)dismiss
{
	[_dismissTimer invalidate];
	_dismissTimer = nil;
	
	[self animateSequence];
}


- (void)animateSequence
{
	if ([_animations count] > 0) {
        ViewAnimation *animation = [_animations objectAtIndex:0];
        [UIView animateWithDuration:animation.animationDuration
                         animations:animation.animationBlock
						 completion:^(BOOL finished){
							 
							 if (_animations.count > 0) {
								 [_animations removeObjectAtIndex:0];
							 }
							 
							 if (animation.completionBlock) {
								 animation.completionBlock(finished);
							 }
							 
							 [self animateSequence];
                         }];
    }
}


- (void)prepareDissolveAnimations
{
	if (!_animations) {
		_animations = [[NSMutableArray alloc] init];
	} else {
		[_animations removeAllObjects];
	}
	
	ViewAnimation *animation = [[ViewAnimation alloc] init];
	animation.animationDuration = 0.3;
	animation.animationBlock = ^{_alertView.alpha = 0.0f;};
	animation.completionBlock = ^(BOOL finished) {
		[_alertView removeFromSuperview];
		_alertView = nil;
	};
	
	[_animations addObject:animation];
}


- (void)prepareShakeAnimations
{
	if (!_animations) {
		_animations = [[NSMutableArray alloc] init];
	} else {
		[_animations removeAllObjects];
	}
	
	int animationQuanity = 10;
	
	for (int i = 0; i < animationQuanity; i++) {
		ViewAnimation *animation = [[ViewAnimation alloc] init];
		animation.animationDuration = 0.03;
		animation.animationBlock = ^{
			int randNumX = 0;
			int randNumY = 0;
			
			int module = i % 4;
			switch (module) {
				case 0: randNumX = -5; randNumY = 5; break;
				case 1: randNumX = 5; randNumY = -5; break;
				case 2: randNumX = 5; randNumY = 5; break;
				case 3: randNumX = -5; randNumY = -5; break;
				default: break;
			}
			
			_alertView.center = CGPointMake(_alertView.center.x + randNumX, _alertView.center.y + randNumY);
		};
		
		if (i == animationQuanity - 1) {
			animation.animationDuration = 0.1;
			animation.animationBlock = ^{
				_alertView.alpha = 0.0;
			};
			animation.completionBlock = ^(BOOL finished) {
				[_alertView removeFromSuperview];
				_alertView = nil;
			};
		}
		
		[_animations addObject:animation];
	}
}


@end
