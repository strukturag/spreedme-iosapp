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

#import "STChatGeneralTableViewCell.h"

#import <QuartzCore/QuartzCore.h>

#import "DateFormatterManager.h"


const CGFloat kSTChatCellAvatarImageHeight				= 30.0f;
const CGFloat kSTChatCellAvatarImageWidth				= kSTChatCellAvatarImageHeight;
const CGFloat kSTChatCellVerticalEdge					= 5.0f;
const CGFloat kSTChatCellVerticalGap					= 2.0f;
const CGFloat kSTChatCellHorisontalEdge					= 5.0f;
const CGFloat kSTChatCellHorisontalGap					= 2.0f;

const CGFloat kSTChatCellDeliveryStatusContainerViewHeight		= 12.0f;
const CGFloat kSTChatCellDeliveryStatusContainerViewWidth		= kSTChatCellDeliveryStatusContainerViewHeight;

const CGFloat kSTChatCellTimeStampLabelHeight			= kSTChatCellDeliveryStatusContainerViewHeight;

const CGFloat kSTChatCellBottomEmptySpaceHeight			= 10.0f;

const CGFloat kSTChatCellWholeHorizontalEdge			= 20.0f;


@interface STChatGeneralTableViewCellBackgroundView : UIView
@end

@implementation STChatGeneralTableViewCellBackgroundView

+ (Class)layerClass
{
	return [CAShapeLayer class];
}

@end


@implementation STChatGeneralTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		
		self.backgroundTintColor = [UIColor lightGrayColor];
		self.backgroundView = [[STChatGeneralTableViewCellBackgroundView alloc] initWithFrame:self.bounds];
		
		self.avatarImageView = [[UIImageView alloc] initWithFrame:CGRectMake(kSTChatCellHorisontalEdge,
																			 kSTChatCellVerticalEdge,
																			 kSTChatCellAvatarImageHeight,
																			 kSTChatCellAvatarImageWidth)];
		
		self.deliveryStatusContainerView = [[UIView alloc] initWithFrame:CGRectMake(self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap,
																					 kSTChatCellVerticalEdge,
																					 kSTChatCellDeliveryStatusContainerViewWidth,
																					 kSTChatCellDeliveryStatusContainerViewHeight)];
        
        self.deliveryStatusImageView = [[UIImageView alloc] initWithFrame:self.deliveryStatusContainerView.bounds];
        self.deliveryStatusLabel = [[UILabel alloc] initWithFrame:self.deliveryStatusContainerView.bounds];
        self.deliveryStatusLabel.backgroundColor = [UIColor clearColor];
		
		self.timestampLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
																		kSTChatCellVerticalEdge,
																		self.contentView.bounds.size.width - (self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap),
																		kSTChatCellTimeStampLabelHeight)];
		self.timestampLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.timestampLabel.backgroundColor = [UIColor clearColor];
		self.timestampLabel.text = @"2432/11/12 13.45"; //dummy value
		self.timestampLabel.font = [UIFont systemFontOfSize:10];
		
		self.userNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.deliveryStatusContainerView.frame.origin.x,
																	   self.deliveryStatusContainerView.frame.origin.y + self.deliveryStatusContainerView.frame.size.height + kSTChatCellVerticalGap,
																	   self.contentView.bounds.size.width - (self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap),
																	   self.avatarImageView.frame.size.height - self.deliveryStatusContainerView.frame.size.height - kSTChatCellVerticalGap)];
		self.userNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.userNameLabel.backgroundColor = [UIColor clearColor];
		self.userNameLabel.font = [UIFont boldSystemFontOfSize:12];
		self.userNameLabel.text = @"Anonymous"; //dummy value
		
		[self.contentView addSubview:self.avatarImageView];
		[self.contentView addSubview:self.deliveryStatusContainerView];
		[self.contentView addSubview:self.timestampLabel];
		[self.contentView addSubview:self.userNameLabel];
        [self.deliveryStatusContainerView addSubview:self.deliveryStatusImageView];
        [self.deliveryStatusContainerView addSubview:self.deliveryStatusLabel];
		self.backgroundColor = [UIColor whiteColor];

    }
    return self;
}


- (void)setupCellWithMessage:(id<STChatMessage>)message
{
	if (message) {
	
		_message = message;
		
		self.isLeftAligned = ![_message isSentByLocalUser];
		if (self.isLeftAligned) {
			if ([_message respondsToSelector:@selector(remoteUserAvatar)]) {
				self.avatarImageView.image = [_message remoteUserAvatar];
			}
            self.backgroundTintColor = kSTChatGeneralTVCLeftTintColor;
		} else {
			if ([_message respondsToSelector:@selector(localUserAvatar)]) {
				self.avatarImageView.image = [_message localUserAvatar];
			}
			self.backgroundTintColor = kSTChatGeneralTVCRightTintColor;
		}

		if ([message respondsToSelector:@selector(deliveryStatusIcon)]) {
            self.deliveryStatusLabel.hidden = YES;
            self.deliveryStatusImageView.image = [message deliveryStatusIcon];
        } else {
            self.deliveryStatusImageView.hidden = YES;
            self.deliveryStatusLabel.attributedText = [message deliveryStatusText];
        }
		NSDateFormatter *dateFormatter = [[DateFormatterManager sharedInstance] defaultLocalizedShortDateTimeStyleFormatter];
		self.timestampLabel.text = [dateFormatter stringFromDate:[_message date]];
		
		self.userNameLabel.text = [_message userName];
		
		[self setNeedsLayout];
	}
}


- (void)layoutSubviews
{
    [super layoutSubviews];
	
	self.top = [_message isStartOfGroup];
	self.bottom = [_message isEndOfGroup];
	self.isLeftAligned = ![_message isSentByLocalUser];
	
	self.backgroundView.frame = CGRectMake(self.isLeftAligned ? 0.0f : kSTChatCellWholeHorizontalEdge, 0, self.frame.size.width - kSTChatCellWholeHorizontalEdge, self.frame.size.height);
	
	self.contentView.frame = CGRectMake(self.isLeftAligned ? kSTChatCellHorisontalEdge : (kSTChatCellHorisontalEdge + kSTChatCellWholeHorizontalEdge),
										0,
										self.frame.size.width - 2.0f * kSTChatCellHorisontalEdge - kSTChatCellWholeHorizontalEdge,
										self.bottom ? self.frame.size.height - kSTChatCellBottomEmptySpaceHeight : self.frame.size.height);
	
	
	CGFloat corner = kViewCornerRadius;
	CAShapeLayer *shapeLayer = (CAShapeLayer *)self.backgroundView.layer;
	shapeLayer.fillColor = self.backgroundTintColor.CGColor;
	shapeLayer.strokeColor = [UIColor lightGrayColor].CGColor;
	shapeLayer.lineWidth = 0.5f;
	
    if(self.top && self.bottom)
    {
		CGRect shapeRect = self.backgroundView.bounds;
		shapeRect.origin = CGPointMake(self.isLeftAligned ? 0.0f : 2.0f * shapeLayer.lineWidth, shapeLayer.lineWidth);
		shapeRect.size.width -= 2.0f * shapeLayer.lineWidth;
		shapeRect.size.height = shapeRect.size.height - kSTChatCellBottomEmptySpaceHeight - 2.0f * shapeLayer.lineWidth;
		
        shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:shapeRect
												byRoundingCorners:self.isLeftAligned ? UIRectCornerTopRight | UIRectCornerBottomRight : UIRectCornerTopLeft | UIRectCornerBottomLeft
													  cornerRadii:CGSizeMake(corner, corner)].CGPath;
        self.backgroundView.layer.masksToBounds = YES;
//		NSLog(@"Set background as TOP and BOTTOM");
		
    } else if (self.top) {
		CGRect shapeRect = self.backgroundView.bounds;
		shapeRect.origin = CGPointMake(self.isLeftAligned ? 0.0f : 2.0f * shapeLayer.lineWidth, shapeLayer.lineWidth);
		shapeRect.size.width -= 2.0f * shapeLayer.lineWidth;
		shapeRect.size.height -= shapeLayer.lineWidth;
        shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:shapeRect
												byRoundingCorners:self.isLeftAligned ? UIRectCornerTopRight : UIRectCornerTopLeft
													  cornerRadii:CGSizeMake(corner, corner)].CGPath;
        self.backgroundView.layer.masksToBounds = YES;
//		NSLog(@"Set background as TOP");
		
    } else if (self.bottom) {
		CGRect shapeRect = self.backgroundView.bounds;
		shapeRect.origin = CGPointMake(self.isLeftAligned ? 0.0f : 2.0f * shapeLayer.lineWidth, 0.0f);
		shapeRect.size.width -= 2.0f * shapeLayer.lineWidth;
		shapeRect.size.height = shapeRect.size.height - kSTChatCellBottomEmptySpaceHeight - shapeLayer.lineWidth;
		
        shapeLayer.path = [UIBezierPath bezierPathWithRoundedRect:shapeRect
												byRoundingCorners:self.isLeftAligned ? UIRectCornerBottomRight : UIRectCornerBottomLeft
													  cornerRadii:CGSizeMake(corner, corner)].CGPath;
        self.backgroundView.layer.masksToBounds = YES;
//		NSLog(@"Set background as BOTTOM");
		
    } else {
		CGRect shapeRect = self.backgroundView.bounds;
		shapeRect.origin = CGPointMake(self.isLeftAligned ? 0.0f : 2.0f * shapeLayer.lineWidth, 0);
		shapeRect.size.width -= 2.0f * shapeLayer.lineWidth;
		shapeLayer.path = [UIBezierPath bezierPathWithRect:shapeRect].CGPath;
		self.backgroundView.layer.masksToBounds = YES;
//		NSLog(@"Set background clear");
	}
	[self.backgroundView setNeedsLayout];
	
	
	if (self.isLeftAligned) {
		self.avatarImageView.frame = CGRectMake(kSTChatCellHorisontalEdge,
												kSTChatCellVerticalEdge,
												kSTChatCellAvatarImageWidth,
												kSTChatCellAvatarImageHeight);
		
		self.timestampLabel.textAlignment = NSTextAlignmentLeft;
		self.timestampLabel.frame = CGRectMake(self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap,
											   kSTChatCellVerticalEdge,
											   self.contentView.bounds.size.width - (self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap),
											   kSTChatCellTimeStampLabelHeight);
		
		self.userNameLabel.textAlignment = NSTextAlignmentLeft;
		self.userNameLabel.frame = CGRectMake(self.timestampLabel.frame.origin.x,
											  self.timestampLabel.frame.origin.y + self.timestampLabel.frame.size.height + kSTChatCellVerticalGap,
											  self.contentView.bounds.size.width - (self.avatarImageView.frame.origin.x + self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap),
											  self.avatarImageView.frame.size.height - self.timestampLabel.frame.size.height - kSTChatCellVerticalGap);
		
	} else {
		self.avatarImageView.frame = CGRectMake(self.contentView.frame.size.width - kSTChatCellHorisontalEdge - kSTChatCellAvatarImageWidth,
												kSTChatCellVerticalEdge,
												kSTChatCellAvatarImageHeight,
												kSTChatCellAvatarImageHeight);
		
		self.timestampLabel.textAlignment = NSTextAlignmentRight;
		self.timestampLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
											   kSTChatCellVerticalEdge,
											   self.contentView.frame.size.width - kSTChatCellHorisontalGap - kSTChatCellHorisontalEdge * 2.0f - self.avatarImageView.frame.size.width,
											   kSTChatCellTimeStampLabelHeight);
		
		self.userNameLabel.textAlignment = NSTextAlignmentRight;
		self.userNameLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
											  self.timestampLabel.frame.origin.y + self.timestampLabel.frame.size.height + kSTChatCellVerticalGap,
											  self.contentView.bounds.size.width - (self.avatarImageView.frame.size.width + kSTChatCellHorisontalGap + 2.0f * kSTChatCellHorisontalEdge),
											  self.avatarImageView.frame.size.height - self.timestampLabel.frame.size.height - kSTChatCellVerticalGap);
	}
}


@end
