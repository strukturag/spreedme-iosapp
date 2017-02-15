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

#import "FlyOverAlert.h"

@implementation RetainingView
@end


@implementation FlyOverAlert


- (void)createView
{}

- (void)show
{}

- (void)dismiss
{}

- (void)viewWasTapped:(id)sender
{}

#pragma mark - Rotation

- (void)prepareViewForBeginningShowAnimation
{
	CGPoint viewCenter = _alertView.center;
    CGPoint offset = CGPointMake(viewCenter.x,
                                 viewCenter.y - _alertView.frame.size.height - [[self class] getStatusBarHeight]);
    
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        switch ([UIApplication sharedApplication].statusBarOrientation)
        {
            case UIInterfaceOrientationPortraitUpsideDown:
                offset = CGPointMake(viewCenter.x,
                                     viewCenter.y + _alertView.frame.size.height + [[self class] getStatusBarHeight]);
                break;
            case UIInterfaceOrientationLandscapeLeft: // we have already applied transform here so we need to use width instead of height
                offset = CGPointMake(viewCenter.x - _alertView.frame.size.width - [[self class] getStatusBarHeight],
                                     viewCenter.y);
                break;
            case UIInterfaceOrientationLandscapeRight: // we have already applied transform here so we need to use width instead of height
                offset = CGPointMake(viewCenter.x + _alertView.frame.size.width + [[self class] getStatusBarHeight],
                                     viewCenter.y);
                break;
            default:
                break;
        }
    }
	
	_alertView.center = offset;
}


- (void)prepareViewForShowAnimation
{
	CGPoint viewCenter = _alertView.center;
    CGPoint offset = CGPointMake(viewCenter.x,
                                 viewCenter.y + _alertView.frame.size.height + [[self class] getStatusBarHeight]);
    
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        switch ([UIApplication sharedApplication].statusBarOrientation)
        {
            case UIInterfaceOrientationPortraitUpsideDown:
                offset = CGPointMake(viewCenter.x,
                                     viewCenter.y - _alertView.frame.size.height - [[self class] getStatusBarHeight]);
                break;
            case UIInterfaceOrientationLandscapeLeft: // we have already applied transform here so we need to use width instead of height
                offset = CGPointMake(viewCenter.x + _alertView.frame.size.width + [[self class] getStatusBarHeight],
                                     viewCenter.y);
                break;
            case UIInterfaceOrientationLandscapeRight: // we have already applied transform here so we need to use width instead of height
                offset = CGPointMake(viewCenter.x - _alertView.frame.size.width - [[self class] getStatusBarHeight],
                                     viewCenter.y);
                break;
            default:
                break;
        }
    }
	
	_alertView.center = offset;
}


- (void)statusBarFrameOrOrientationChanged:(NSNotification *)notification
{
    /*
     This notification is most likely triggered inside an animation block,
     therefore no animation is needed to perform this nice transition.
     */
    [self rotateOnlyAccordingToStatusBarOrientationAndSupportedOrientations];
	[self centerViewForAnyOrientation];
}


- (void)rotateOnlyAccordingToStatusBarOrientationAndSupportedOrientations
{
    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
    CGFloat angle = UIInterfaceOrientationAngleOfOrientation(statusBarOrientation);
	CGAffineTransform transform = CGAffineTransformMakeRotation(angle);
	[self setIfNotEqualTransform:transform];
}


- (void)setIfNotEqualTransform:(CGAffineTransform)transform
{
	if(!CGAffineTransformEqualToTransform(_alertView.transform, transform))
    {
        _alertView.transform = transform;
    }
}


+ (CGFloat)getStatusBarHeight
{
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if(UIInterfaceOrientationIsLandscape(orientation)) {
            return [UIApplication sharedApplication].statusBarFrame.size.width;
        }
    }
    
    return [UIApplication sharedApplication].statusBarFrame.size.height;
}


// This method assumes that view has been already rotated
- (CGPoint)centerViewForAnyOrientation
{
	UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
	CGSize windowSize = [[UIApplication sharedApplication] keyWindow].bounds.size;
	
	CGSize viewSize = _alertView.frame.size;
	
    CGPoint center = CGPointMake(windowSize.width / 2,
                                 [[self class] getStatusBarHeight] + viewSize.height / 2.0f);;
    
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        switch (statusBarOrientation)
        {
            case UIInterfaceOrientationPortraitUpsideDown:
                center = CGPointMake(windowSize.width / 2,
                                     windowSize.height - viewSize.height / 2.0f - [[self class] getStatusBarHeight]);
                break;
            case UIInterfaceOrientationLandscapeLeft:
                center = CGPointMake([[self class] getStatusBarHeight] + viewSize.width / 2.0f,
                                     windowSize.height / 2.0f);
                break;
            case UIInterfaceOrientationLandscapeRight:
                center = CGPointMake(windowSize.width - viewSize.width / 2.0f - [[self class] getStatusBarHeight],
                                     windowSize.height / 2.0f);
                break;
            default:
                break;
        }
    }
	
	_alertView.center = center;
	
	return center;
}


CGFloat UIInterfaceOrientationAngleOfOrientation(UIInterfaceOrientation orientation)
{
    CGFloat angle = 0.0;
    
    if (!SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        switch (orientation)
        {
            case UIInterfaceOrientationPortraitUpsideDown:
                angle = M_PI;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                angle = -M_PI_2;
                break;
            case UIInterfaceOrientationLandscapeRight:
                angle = M_PI_2;
                break;
            default:
                break;
        }
    }
	
    return angle;
}


@end
