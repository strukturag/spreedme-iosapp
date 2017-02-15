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

#import "BuddyCollectionViewCell.h"

#import "WaveBackgroundAnimationView.h"


static NSString * kConnectedStateString		= nil;
static NSString * kConnectingStateString	= nil;
static NSString * kIncomingCallStateString	= nil;
static NSString * kOutgoingCallStateString	= nil;
static NSString * kDisconnectedStateString	= nil;
static NSString * kFailedStateString		= nil;

@implementation BuddyVisual
@end


@interface BuddyCollectionViewCell ()
{
	BOOL _isBlinking;
}
@property (nonatomic, strong) UIView<ActivityIndicatorViewProtocol> *waveAnimationView;

@end

@implementation BuddyCollectionViewCell

+ (void)initialize
{
	if (self == [BuddyCollectionViewCell class]) {
		kConnectedStateString = NSLocalizedStringWithDefaultValue(@"callview_label-arg1_user-is-connected",
																  nil, [NSBundle mainBundle],
																  @"%@",
																  @"Part of the text to present when user is in the call(empty_string username). Probably should be zero length string for any language. You can move '%@' but make sure not to delete it.");
		
		kConnectingStateString = NSLocalizedStringWithDefaultValue(@"callview_label-arg1_user-is-connecting",
																   nil, [NSBundle mainBundle],
																   @"Calling %@",
																   @"Part of the text to present when user is connecting to the current call(Calling username). This can happen when user was in call an due to temporary problems with internet call is interrupted. You can move '%@' but make sure not to delete it.");
		
		kIncomingCallStateString = NSLocalizedStringWithDefaultValue(@"callview_label-arg1_user-is-receiving-incoming-call",
																	 nil, [NSBundle mainBundle],
																	 @"Incoming call from %@",
																	 @"Part of the text to present when app user is receiving incoming call from another user(Incoming call from username). You can move '%@' but make sure not to delete it.");
		
		kOutgoingCallStateString = NSLocalizedStringWithDefaultValue(@"callview_label-arg1_user-is-calling-to-other-user",
																	 nil, [NSBundle mainBundle],
																	 @"Calling %@",
																	 @"Part of the text to present when app user is calling to another user(Calling username). You can move '%@' but make sure not to delete it.");
		
		kDisconnectedStateString = NSLocalizedStringWithDefaultValue(@"callview_label_user-is-disconnected",
																	 nil, [NSBundle mainBundle],
																	 @"Disconnected",
																	 @"Text to present when app user is disconnected due to network problems or due to other reasons.");
		
		kFailedStateString = NSLocalizedStringWithDefaultValue(@"callview_label_connection-failed",
															   nil, [NSBundle mainBundle],
															   @"Connection failed",
															   @"Text to present when app user is disconnected and connection failed beyond repairment.");
	}
}


+ (BuddyCollectionViewCell *)cellFromNibNamed:(NSString *)nibName {
    
    NSArray *nibContents = [[NSBundle mainBundle] loadNibNamed:nibName owner:self options:NULL];
    NSEnumerator *nibEnumerator = [nibContents objectEnumerator];
    BuddyCollectionViewCell *xibBasedCell = nil;
    NSObject* nibItem = nil;
    
    while ((nibItem = [nibEnumerator nextObject]) != nil) {
        if ([nibItem isKindOfClass:[BuddyCollectionViewCell class]]) {
            xibBasedCell = (BuddyCollectionViewCell *)nibItem;
            break; // we have a winner
        }
    }
    
    return xibBasedCell;
}


- (void)awakeFromNib
{
	self.contentView.frame = self.bounds;
	self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	self.disconnectedActivityView = [[SMCallDisconnectedUserActivityView alloc] init];
	[self.imageView.superview addSubview:self.disconnectedActivityView];
	
	self.disconnectedActivityView.hidden = YES;

	self.imageView.layer.cornerRadius = kViewCornerRadius;
	self.imageView.layer.masksToBounds = YES;
	
	self.waveAnimationView = [[WaveBackgroundAnimationView alloc] initWithWithForegroundView:self.imageView
																				numberOfWaves:5
																				   waveWidths:@[@(10.0f), @(11.0f), @(12.0f), @(13.0f), @(14.0f)]];
	[self.imageView.superview insertSubview:self.waveAnimationView belowSubview:self.imageView];
	self.waveAnimationView.hidden = YES;
}


- (void)prepareForReuse
{
	self.nameLabel.text = nil;
	self.statusLabel.text = nil;
	self.imageView.image = nil;
	self.disconnectedActivityView.hidden = YES;
	for (UIView *view in self.renderViewContainer.subviews) {
		[view removeFromSuperview];
	}
}


- (void)updateUI
{
	self.nameLabel.outlineColor = [UIColor darkGrayColor];
    self.statusLabel.outlineColor = [UIColor darkGrayColor];
	
	if (fabs(self.buddyVisual.videoRenderViewAspectRatio) < 0.05) {
		self.buddyVisual.videoRenderViewAspectRatio = 1.0f;
	}
	
	self.imageView.image = self.buddyVisual.buddy.iconImage;
	self.nameLabel.text = self.buddyVisual.buddy.displayName;
	self.statusLabel.text = [self stringForVisualState:self.buddyVisual.visualState];
    
    self.nameLabel.numberOfLines = 1;
    self.nameLabel.adjustsFontSizeToFitWidth = YES;
    
    self.statusLabel.numberOfLines = 1;
    self.statusLabel.adjustsFontSizeToFitWidth = YES;
    
    self.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
    self.renderViewContainer.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.2];
    
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFit;
	
	for (UIView *view in self.renderViewContainer.subviews) {
		[view removeFromSuperview];
	}
    	
	switch (self.buddyVisual.visualState) {
		case kUCVSConnected:
			[self stopAnimatingDisconnectedState];
			[self stopAnimatingUserIcon];
            
            if (self.buddyVisual.videoRenderView) {
                [self configureVideoRenderView];
            } else {
                [self configureStatusUI];
            }
		break;
		
		case kUCVSDisconnected:
		case kUCVSConnecting:
			[self startAnimatingDisconnectedState];
			[self stopAnimatingUserIcon];
            
            if (self.buddyVisual.videoRenderView) {
                [self configureVideoRenderView];
            } else {
                [self configureStatusUI];
            }
		break;
		
		case kUCVSFailed:
			[self stopAnimatingUserIcon];
		break;
			
		case kUCVSIncomingCall:
		case kUCVSOutgoingCall:
			[self stopAnimatingDisconnectedState];
			[self animateUserIcon];
            [self configureStatusUI];
		break;
			
		default:
		break;
	}
}


- (void)configureStatusUI
{
    const CGFloat imageViewDefaultSize = 80;
    
    CGRect videoRenderViewFrame = self.renderViewContainer.bounds;
    CGRect statusLabelFrame = self.statusLabel.frame;
    CGRect imageViewFrame = self.imageView.frame;
    
    CGFloat labelImageGap = 20;
    
    self.logoImageView.hidden = YES;
    self.nameLabel.hidden = YES;
    self.imageView.hidden = NO;
    self.statusLabel.hidden = NO;
    
    if ((videoRenderViewFrame.size.height / 2) < ((imageViewFrame.size.height / 2) + statusLabelFrame.size.height + labelImageGap)) {
        CGFloat statusLabelHeight = (videoRenderViewFrame.size.height / 2) / 3;
        labelImageGap = statusLabelHeight;
        imageViewFrame = CGRectMake(imageViewFrame.origin.x, imageViewFrame.origin.y, statusLabelHeight, statusLabelHeight);
        self.imageView.frame = imageViewFrame;
        
    } else {
        imageViewFrame = CGRectMake(imageViewFrame.origin.x, imageViewFrame.origin.y, imageViewDefaultSize, imageViewDefaultSize);
        self.imageView.frame = imageViewFrame;
    }
    
    self.imageView.center = self.renderViewContainer.center;
	self.waveAnimationView.center = self.imageView.center;
    
    CGFloat statusLabelY = self.imageView.frame.origin.y - (statusLabelFrame.size.height + labelImageGap);
    statusLabelFrame = CGRectMake(statusLabelFrame.origin.x, statusLabelY, statusLabelFrame.size.width, statusLabelFrame.size.height);
    self.statusLabel.frame = statusLabelFrame;
	
	self.disconnectedActivityView.center = self.renderViewContainer.center;
}


- (void)configureVideoRenderView
{
    // Setup videoRenderView frame
    CGRect videoRenderViewFrame = self.renderViewContainer.bounds;
    CGSize containerSize = self.renderViewContainer.bounds.size;
    CGFloat aspectRatio = self.buddyVisual.videoRenderViewAspectRatio;
    
    CGFloat upscaleThreshold = 0.8;
    
    self.logoImageView.hidden = NO;
    self.nameLabel.hidden = NO;
    self.imageView.hidden = YES;
    self.statusLabel.hidden = YES;
    
    if (aspectRatio > 1.0f) {
        // 0. height > width - portrait video
        // 1. Set to video view correct aspect ratio
        videoRenderViewFrame.size.width = videoRenderViewFrame.size.height / aspectRatio;
        
        
        
        if (videoRenderViewFrame.size.width > containerSize.width) {
            
            /* 2. Height of video view is the same as the video container view but width of the video view is bigger than the width of video container,
             so we have already upscaled video view, check if we can keep it like that and it doesn't exceed the upscale threshold,
             otherwise downscale to appropriate size.
             */
            
            CGFloat scale = videoRenderViewFrame.size.width / containerSize.width;
            // 3. Check proportions of video to video container
            
            CGFloat upscale = 1.0f;
            if (scale <= 1.0f + upscaleThreshold) { // we can leave it like it is
                
            } else { // the video view is overupscaled, downscale it to threshold
                upscale = 1.0f + upscaleThreshold;
                CGFloat modifier = upscale / scale;
                videoRenderViewFrame.size.height *= modifier;
                videoRenderViewFrame.size.width *= modifier;
            }
        } else {
            // 2. We have space in width, try to fill as much as possible but upscale video to no more than 'upscaleThreshold * 100%'
            
            CGFloat scale = videoRenderViewFrame.size.width / containerSize.width;
            // 3. Check proportions of video to video container
            
            CGFloat upscale = 1.0f;
            if (scale > 1.0f - upscaleThreshold) { // we can fill the whole width and not exceed the threshold
                upscale = 1.0f - scale;
            } else { // we can't fill whole width without exceeding the threshold so set upscale to threshold
                upscale = upscaleThreshold;
            }
            upscale = 1 + upscale;
            
            videoRenderViewFrame.size.height *= upscale;
            videoRenderViewFrame.size.width *= upscale;
        }
        
    } else {
        // 0. width > height - landscape video
        // 1. Give to video view correct aspect ratio
        videoRenderViewFrame.size.height = videoRenderViewFrame.size.width * aspectRatio;
        
        if (videoRenderViewFrame.size.height > containerSize.height) {
            /* 2. Width of video view is the same as the video container view but height of the video view is bigger than the height of video container,
             so we have already upscaled video view, check if we can keep it like that and it doesn't exceed the upscale threshold,
             otherwise downscale to appropriate size.
             */
            
            CGFloat scale = videoRenderViewFrame.size.height / containerSize.height;
            // 3. Check proportions of video to video container
            
            CGFloat upscale = 1.0f;
            if (scale <= 1.0f + upscaleThreshold) { // we can leave it like it is
                
            } else { // the video view is overupscaled, downscale it to threshold
                upscale = 1.0f + upscaleThreshold;
                CGFloat modifier = upscale / scale;
                videoRenderViewFrame.size.height *= modifier;
                videoRenderViewFrame.size.width *= modifier;
            }
        } else {
            // 2. We have space in height, try to fill as much as possible but upscale video to no more than 'upscaleThreshold * 100%'
            
            CGFloat scale = videoRenderViewFrame.size.height / containerSize.height;
            // 3. Check proportions of video to video container
            
            CGFloat upscale = 1.0f;
            if (scale > 1.0f - upscaleThreshold) { // we can fill the whole height and not exceed the threshold
                upscale = 1.0f - scale;
            } else { // we can't fill whole height no passing the threshold so set upscale to threshold
                upscale = upscaleThreshold;
            }
            upscale = 1 + upscale;
            
            videoRenderViewFrame.size.height *= upscale;
            videoRenderViewFrame.size.width *= upscale;
        }
    }
    
    videoRenderViewFrame.size.height = floorf(videoRenderViewFrame.size.height);
    videoRenderViewFrame.size.width = floorf(videoRenderViewFrame.size.width);
    
    self.buddyVisual.videoRenderView.frame = videoRenderViewFrame;
    
    [self.renderViewContainer addSubview:self.buddyVisual.videoRenderView];
    
    self.buddyVisual.videoRenderView.center = self.renderViewContainer.center;
    
    CGRect videoRenderRect = CGRectIntersection(self.renderViewContainer.bounds, self.buddyVisual.videoRenderView.frame);
    CGFloat logoTopPadding = videoRenderRect.size.height * 0.05;
    CGFloat logoRightPadding = videoRenderRect.size.width * 0.05;
    CGFloat logoWidth = (videoRenderRect.size.height > videoRenderRect.size.width) ? videoRenderRect.size.height / 5 : videoRenderRect.size.width / 5;
    logoWidth = (logoWidth > 40) ? 40 : logoWidth; //Set a maximun width. Maybe we will have to change it for iPad.
    
    self.logoImageView.frame = CGRectMake((videoRenderRect.origin.x + videoRenderRect.size.width) - (logoWidth + logoRightPadding),
                                          videoRenderRect.origin.y + logoTopPadding,
                                          logoWidth, logoWidth);
    
    self.nameLabel.frame = CGRectMake(videoRenderRect.origin.x + logoRightPadding,
                                      (videoRenderRect.origin.y + videoRenderRect.size.height) - (self.nameLabel.frame.size.height + logoTopPadding),
                                      videoRenderRect.size.width - (2 * logoRightPadding), self.nameLabel.frame.size.height);
	
	self.disconnectedActivityView.center = self.renderViewContainer.center;
}


- (NSString *)stringForVisualState:(UserCallVisualState)state
{
	NSString *string = nil;
	switch (state) {
		case kUCVSConnected:
			string = [NSString stringWithFormat:kConnectedStateString, self.buddyVisual.buddy.displayName];
		break;
		
		case kUCVSConnecting:
			string = [NSString stringWithFormat:kConnectingStateString, self.buddyVisual.buddy.displayName];
		break;
            
        case kUCVSIncomingCall:
            string = [NSString stringWithFormat:kIncomingCallStateString, self.buddyVisual.buddy.displayName];
        break;
        
        case kUCVSOutgoingCall:
            string = [NSString stringWithFormat:kOutgoingCallStateString, self.buddyVisual.buddy.displayName];
        break;
		
		case kUCVSDisconnected:
			string = kDisconnectedStateString;
		break;
			
		case kUCVSFailed:
			string = kFailedStateString;
		break;
		
		default:
		break;
	}
	
	return string;
}


- (void)animateUserIcon
{
	self.waveAnimationView.hidden = NO;
	[self.waveAnimationView startAnimating];
}


- (void)stopAnimatingUserIcon
{
	self.waveAnimationView.hidden = YES;
}


- (void)startAnimatingDisconnectedState
{
	self.disconnectedActivityView.hidden = NO;
	[self.disconnectedActivityView startAnimating];
}


- (void)stopAnimatingDisconnectedState
{
	self.disconnectedActivityView.hidden = YES;
	[self.disconnectedActivityView stopAnimating];
}


@end
