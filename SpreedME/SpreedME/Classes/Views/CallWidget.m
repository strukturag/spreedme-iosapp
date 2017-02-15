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

#import "CallWidget.h"

const CGFloat blinkingBgSize = 75.0f;

@interface CallWidget ()
{
	UIView *_containerView;
	CallWidgetActionBlock _actionBlock;
	
	BOOL _isShown;
    BOOL _isBlinking;
	
    UIView *_blinkingBackground;
}

@end


@implementation CallWidget

+ (CGSize)size
{
	return CGSizeMake(60.0f, 60.0f);
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)dealloc
{
    [self stopBlinkingBackground];
}


- (instancetype)initWithIconView:(UIView *)iconView text:(NSString *)text
{
	CGSize viewSize = [[self class] size];
	self = [self initWithFrame:CGRectMake(0.0f, 0.0f, viewSize.width, viewSize.height)];
	if (self) {
        
        _blinkingBackground = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, blinkingBgSize, blinkingBgSize)];
        _blinkingBackground.backgroundColor = kSpreedMeBlueColorAlpha06
        _blinkingBackground.layer.cornerRadius = blinkingBgSize / 2;
        _blinkingBackground.layer.masksToBounds = YES;
        _blinkingBackground.center = self.center;
        
        [self addSubview:_blinkingBackground];
        
        iconView.frame = self.bounds;
        iconView.layer.cornerRadius = viewSize.height / 2;
        iconView.layer.masksToBounds = YES;
        
		[self addSubview:iconView];
        
        [self startBlinkingBackground];
	}
	
	return self;
}


- (void)showInView:(UIView *)view
				at:(CGPoint)centerCoordinates
	 addPanGesture:(BOOL)shouldAddPanGesture
	   actionBlock:(CallWidgetActionBlock)block
{
	if (!_isShown && view) {
		_isShown = YES;
		
		_containerView = view;
		self.center = centerCoordinates;
		[_containerView addSubview:self];
		
		if (shouldAddPanGesture) {
			UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panLocalVideoRenderView:)];
			panGesture.maximumNumberOfTouches = 1;
			panGesture.minimumNumberOfTouches = 1;
			
			[self addGestureRecognizer:panGesture];
		}
		
		UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(widgetWasTapped:)];
		[self addGestureRecognizer:tapGesture];
		
		_actionBlock = [block copy];
	}
}


- (void)dismiss
{
	[self removeFromSuperview];
    [self stopBlinkingBackground];
}


- (void)panLocalVideoRenderView:(UIPanGestureRecognizer *)sender
{
	CGPoint location = [sender locationInView:_containerView];
	
	self.center = location;
}


- (void)widgetWasTapped:(id)sender
{
	if (_actionBlock) {
		_actionBlock();
	}
}


- (void)startBlinkingBackground
{
    if (_isBlinking) {
		return;
	}
    _isBlinking = YES;
    _blinkingBackground.alpha = 0.6f;
    [UIView animateWithDuration:0.8
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
     UIViewAnimationOptionRepeat |
     UIViewAnimationOptionAutoreverse |
     UIViewAnimationOptionAllowUserInteraction
                     animations:^{
                         _blinkingBackground.alpha = 0.0f;
                     }
                     completion:^(BOOL finished){
                         // Do nothing
                     }];
}


- (void)stopBlinkingBackground
{
    if (!_isBlinking) {
		return;
	}
    _isBlinking = NO;
    [UIView animateWithDuration:0.8
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
     UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         _blinkingBackground.alpha = 1.0f;
                     }
                     completion:^(BOOL finished){
                         // Do nothing
                     }];
}


@end
