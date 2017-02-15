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

#import "STChatGeolocationViewCell.h"

const CGFloat kSTChatLocationLabelHeight				= 24.0f;

const CGFloat kSTChatShowLocationButtonHeight			= 44.0f;
const CGFloat kSTChatShowLocationButtonWidth			= kSTChatShowLocationButtonHeight;

const CGFloat kSTChatShowLocationWellViewHeight			= 54.0f;



@interface STChatGeolocationViewCell ()
{
	id<STChatGeolocationViewCellDelegate> _delegate;
	NSInteger _cellIndex;
}

@property (nonatomic, strong) UITextView *sharingExplanationTextView;
@property (nonatomic, strong) UILabel *geolocationLabel;
@property (nonatomic, strong) UIView *wellView;

@property (nonatomic, strong) STFontAwesomeRoundedButton *showLocationButton;

@end



@implementation STChatGeolocationViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		
		_cellIndex = -1;
        
        self.wellView = [[UIView alloc] initWithFrame:CGRectZero];
		self.wellView.layer.cornerRadius = kViewCornerRadius;
		self.wellView.layer.borderColor = [UIColor blackColor].CGColor;
		self.wellView.layer.borderWidth = 0.5f;
		
		self.sharingExplanationTextView = [[UITextView alloc] initWithFrame:CGRectZero];
		self.sharingExplanationTextView.backgroundColor = [UIColor clearColor];
		self.sharingExplanationTextView.font = [UIFont systemFontOfSize:14.0f];
        self.sharingExplanationTextView.scrollEnabled = NO;
        self.sharingExplanationTextView.editable = NO;
        
        //Workaround to align text with delivery status
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            self.sharingExplanationTextView.contentInset = UIEdgeInsetsMake(-4, 0, 0, 0);
        } else {
            self.sharingExplanationTextView.contentInset = UIEdgeInsetsMake(-6, 0, 0, 0);
        }
		
		self.geolocationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.geolocationLabel.backgroundColor = [UIColor clearColor];
		self.geolocationLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.geolocationLabel.numberOfLines = 0;
		self.geolocationLabel.font = [UIFont systemFontOfSize:16.0f];
		self.geolocationLabel.textAlignment = NSTextAlignmentCenter;
		
		self.showLocationButton = [STFontAwesomeRoundedButton buttonWithType:UIButtonTypeCustom];
		[self.showLocationButton setTitleWithIcon:FALocationArrow forState:UIControlStateNormal];
		[self.showLocationButton setBackgroundColor:kSTChatGeolocationTVCBlueButtonColor forState:UIControlStateNormal];
        [self.showLocationButton setBackgroundColor:kSTChatGeolocationTVCBlueButtonSelectedColor forState:UIControlStateSelected];
		[self.showLocationButton setCornerRadius:kViewCornerRadius];
        [self.showLocationButton addTarget:self action:@selector(showLocationButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
		[self.wellView addSubview:self.geolocationLabel];
		[self.wellView addSubview:self.showLocationButton];
        
        [self.contentView addSubview:self.wellView];
        [self.contentView addSubview:self.sharingExplanationTextView];
        
		self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)setupCellWithMessage:(id<STGeolocationChatMessage>)geolocationMessage
{
	[super setupCellWithMessage:geolocationMessage];
	
    CGFloat accuracy = [geolocationMessage accuracy];
    CGFloat latitude = [geolocationMessage latitude];
    CGFloat longitude = [geolocationMessage longitude];
    
	if ([geolocationMessage isSentByLocalUser]) {
        self.sharingExplanationTextView.text = NSLocalizedStringWithDefaultValue(@"label_you-have-shared-location",
																				 nil, [NSBundle mainBundle],
																				 @"You shared your location:",
																				 @"I beleive colon should be preserved.");
	} else {
		self.sharingExplanationTextView.text = NSLocalizedStringWithDefaultValue(@"label_you-have-received-location",
																				 nil, [NSBundle mainBundle],
																				 @"Location received:",
																				 @"I beleive colon should be preserved.");
    }
	
	//TODO: Check if we want to localize distance values
    self.geolocationLabel.text = [NSString stringWithFormat:@"%f° %f° ±%dm", latitude, longitude, (int) roundf(accuracy)];
    [self setNeedsLayout];
}


- (void)layoutSubviews
{
	[super layoutSubviews];
    
	id<STGeolocationChatMessage> geolocationMessage = (id<STGeolocationChatMessage>)_message;
		
	if (self.top) {
		self.avatarImageView.hidden = NO;
		self.userNameLabel.hidden = NO;
		
		self.sharingExplanationTextView.frame = CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
                                                           self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + kSTChatCellVerticalGap,
                                                           self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f - self.deliveryStatusContainerView.frame.size.width - kSTChatCellHorisontalGap,
                                                           kSTChatLocationLabelHeight);
		
		self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
															self.sharingExplanationTextView.frame.origin.y + (self.sharingExplanationTextView.frame.size.height / 2) - (self.deliveryStatusContainerView.frame.size.height / 2),
															self.deliveryStatusContainerView.frame.size.width,
															self.deliveryStatusContainerView.frame.size.height);
		
		
	} else {
		self.avatarImageView.hidden = YES;
		self.userNameLabel.hidden = YES;
        
		self.sharingExplanationTextView.frame = CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
														self.timestampLabel.frame.origin.y + self.timestampLabel.frame.size.height + kSTChatCellVerticalGap,
														self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f - self.deliveryStatusContainerView.frame.size.width - kSTChatCellHorisontalGap,
														kSTChatLocationLabelHeight);
		// Hide it??
        self.timestampLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                               self.timestampLabel.frame.origin.y,
                                               self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f,
                                               self.timestampLabel.frame.size.height);
        
        self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                            self.sharingExplanationTextView.frame.origin.y + (self.sharingExplanationTextView.frame.size.height / 2) - (self.deliveryStatusContainerView.frame.size.height / 2),
                                                            self.deliveryStatusContainerView.frame.size.width,
                                                            self.deliveryStatusContainerView.frame.size.height);
	}
	
	self.wellView.frame = CGRectMake(kSTChatCellHorisontalEdge,
									 self.sharingExplanationTextView.frame.origin.y + self.sharingExplanationTextView.frame.size.height + kSTChatCellVerticalGap,
									 self.contentView.bounds.size.width - kSTChatCellHorisontalEdge * 2.0f,
									 kSTChatShowLocationWellViewHeight);
    
    // All next views live in self.wellView
    
    if ([geolocationMessage isSentByLocalUser]) {
        
		self.showLocationButton.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                   self.wellView.bounds.size.height / 2.0f - kSTChatShowLocationButtonHeight / 2.0f, // y center of wellView
                                                   kSTChatShowLocationButtonWidth,
                                                   kSTChatShowLocationButtonHeight);
		
		self.geolocationLabel.frame = CGRectMake(self.showLocationButton.frame.origin.x + self.showLocationButton.frame.size.width + kSTChatCellHorisontalGap,
                                                 kSTChatCellVerticalEdge,
                                                 self.wellView.frame.size.width - self.showLocationButton.frame.origin.x - self.showLocationButton.frame.size.width - kSTChatCellHorisontalGap - kSTChatCellHorisontalEdge,
                                                 kSTChatShowLocationButtonWidth);

	} else {
        
		self.showLocationButton.frame = CGRectMake(self.wellView.bounds.size.width - kSTChatCellHorisontalGap - kSTChatCellHorisontalEdge - kSTChatShowLocationButtonWidth,
                                                   self.wellView.bounds.size.height / 2.0f - kSTChatShowLocationButtonHeight / 2.0f, // y center of wellView
                                                   kSTChatShowLocationButtonWidth,
                                                   kSTChatShowLocationButtonHeight);
        
		self.geolocationLabel.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                 kSTChatCellVerticalEdge,
                                                 self.wellView.frame.size.width - self.showLocationButton.frame.size.width - kSTChatCellHorisontalGap * 2.0f - kSTChatCellHorisontalEdge * 2.0f,
                                                 kSTChatShowLocationButtonHeight);
    }
}


- (void)prepareForReuse
{
	[super prepareForReuse];
}


- (void)showLocationButtonPressed:(id)sender
{
	if (_delegate && _cellIndex > -1 && [_delegate respondsToSelector:@selector(geolocationTableViewCell:showLocationButtonWasPressedAtIndex:)]) {
		[_delegate geolocationTableViewCell:self showLocationButtonWasPressedAtIndex:_cellIndex];
	}
}


#pragma mark - Height calculation

+ (CGFloat)neededHeightForCellWithGeolocationChatMessage:(id<STGeolocationChatMessage>)message
                                              topMessage:(BOOL)isTopMessage
                                           bottomMessage:(BOOL)isBottomMessage
                                       restrictedToWidth:(CGFloat)restrictedToWidth
{
	CGFloat height = 44.0f;
	
	if (isTopMessage) {
		height = kSTChatCellVerticalEdge * 2.0f +
		kSTChatCellAvatarImageHeight + kSTChatCellVerticalGap + // avatar
		kSTChatLocationLabelHeight + kSTChatCellVerticalGap + // sharing explanation
		kSTChatShowLocationWellViewHeight; // well view with contents
	} else {
		height = kSTChatCellVerticalEdge * 2.0f +
		kSTChatCellTimeStampLabelHeight + kSTChatCellVerticalGap +
		kSTChatLocationLabelHeight + kSTChatCellVerticalGap + // sharing explanation
		kSTChatShowLocationWellViewHeight; // well view with contents
	}
	
	if (isBottomMessage) {
		height += kSTChatCellBottomEmptySpaceHeight;
	}
	
	
	return height;
}


#pragma mark - Actions Delegation

- (void)setDelegate:(id<STChatGeolocationViewCellDelegate>)delegate withCellIndex:(NSInteger)cellIndex
{
	_delegate = delegate;
	_cellIndex = cellIndex;
}


- (void)clearDelegate
{
	_delegate = nil;
	_cellIndex = -1;
}


@end
