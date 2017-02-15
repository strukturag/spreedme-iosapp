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

#import "STChatTextTableViewCell.h"


@interface STChatTextTableViewCell()
{
}
@end

@implementation STChatTextTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
		self.messageTextView = [[UITextView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.bounds.size.width, self.bounds.size.height)];
		self.messageTextView.font = MessageTextViewFont;
		self.messageTextView.scrollEnabled = NO;
        self.messageTextView.editable = NO;
        self.messageTextView.dataDetectorTypes = UIDataDetectorTypeLink | UIDataDetectorTypePhoneNumber;
        
		[self.contentView addSubview:self.messageTextView];
		self.backgroundColor = [UIColor clearColor];
    }
    return self;
}


- (void)setupCellWithMessage:(id<STTextChatMessage>)textMessage
{
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:MessageTextViewFont forKey:NSFontAttributeName];
    
	[super setupCellWithMessage:textMessage];
    
	if (textMessage) {
        /*
         There is a bug on iOS7 related with link and phone detectors.
         That's why we assign the message text to the attributedText property
         http://stackoverflow.com/a/20669356/2183064 
         */
		self.messageTextView.attributedText = [[NSAttributedString alloc] initWithString:[textMessage message] attributes:attrsDictionary];
		self.messageTextView.backgroundColor = [UIColor clearColor];
        
        [self setNeedsLayout];
	}
}


- (void)layoutSubviews
{
	[super layoutSubviews];
	
	CGSize constrainedSize = CGSizeMake(self.contentView.bounds.size.width, CGFLOAT_MAX);
    constrainedSize.width -= kSTChatCellDeliveryStatusContainerViewWidth + kSTChatCellHorisontalGap;
    
	// This text size checking should always correspond to the one in "+ (CGFloat)neededHeightForCellWithTextChatMessage:(id<STTextChatMessage>)message ..." method!!!
	CGSize textSize = [self.messageTextView sizeThatFits:CGSizeMake(constrainedSize.width, FLT_MAX)];
	
	self.timestampLabel.hidden = !self.top;
	
	if (self.top) {
		self.avatarImageView.hidden = NO;
		self.userNameLabel.hidden = NO;
		
		// here we care about origin.y and height
		self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
														self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + kSTChatCellVerticalGap,
														kSTChatCellDeliveryStatusContainerViewWidth,
														kSTChatCellDeliveryStatusContainerViewHeight);
		
		self.messageTextView.frame = CGRectMake(self.messageTextView.frame.origin.x,
											 self.avatarImageView.frame.origin.y + self.avatarImageView.frame.size.height + kSTChatCellVerticalGap,
											 self.contentView.bounds.size.width,
											 textSize.height);
	} else {
		self.avatarImageView.hidden = YES;
		self.userNameLabel.hidden = YES;
		
		// here we care about origin.y and height
		self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
														kSTChatCellVerticalEdge,
														kSTChatCellDeliveryStatusContainerViewWidth,
														kSTChatCellDeliveryStatusContainerViewHeight);
		
		self.messageTextView.frame = CGRectMake(self.messageTextView.frame.origin.x,
											 kSTChatCellVerticalEdge,
											 self.contentView.bounds.size.width,
											 textSize.height);
	}

    // here we care about origin.x and width since we set correct origin.y and height prevoiusly
    self.deliveryStatusContainerView.hidden = NO;
    // TODO: Align delivery status to the first line of text correctly.
    self.deliveryStatusContainerView.frame = CGRectMake(kSTChatCellHorisontalEdge,
                                                    self.deliveryStatusContainerView.frame.origin.y + [self calculateDeliveryStatusOffsetToMatchText], // This is hackery to align delivery status to text.
                                                    self.deliveryStatusContainerView.frame.size.width,
                                                    self.deliveryStatusContainerView.frame.size.height);
    self.messageTextView.frame = CGRectMake(self.deliveryStatusContainerView.frame.origin.x + self.deliveryStatusContainerView.frame.size.width + kSTChatCellHorisontalGap,
                                         self.messageTextView.frame.origin.y,
                                         self.contentView.bounds.size.width - self.deliveryStatusContainerView.frame.size.width - kSTChatCellHorisontalGap,
                                         textSize.height);
}


- (CGFloat)calculateDeliveryStatusOffsetToMatchText
{
	// This value is picked by hand. This is hackery
    
    //It looks like default content insets are different in iOS 7
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        return 10.0f;
    }
    
    return 12.0f;
}


#pragma mark - Height calculation

+ (CGFloat)neededHeightForCellWithTextChatMessage:(id<STTextChatMessage>)message
									   topMessage:(BOOL)isTopMessage
									bottomMessage:(BOOL)isBottomMessage
								restrictedToWidth:(CGFloat)restrictedToWidth
				   withDeliveryStatusNotification:(BOOL)withDeliveryStatusNotification
{
	CGFloat height = 44.0f;
	NSString *messageText = [message message];
    
	/*
	 We have to correct width for calculation since our text lies in contentView which is layed out differently. 
	 In this method we assume that restricted width is width of the cell but we might want to change layout inside of cell.
	 */
	CGFloat widthCorrection = kSTChatCellWholeHorizontalEdge + 2.0f * kSTChatCellHorisontalEdge; // These values are taken from layout of contentView in STChatGeneralTableViewCell
	widthCorrection = widthCorrection + (withDeliveryStatusNotification ? kSTChatCellDeliveryStatusContainerViewWidth + kSTChatCellHorisontalGap : 0.0f); // this is introduced by placing 'deliveryStatusImageView' in the same row as text label
	restrictedToWidth = restrictedToWidth - widthCorrection;
	
    
    NSDictionary *attrsDictionary = [NSDictionary dictionaryWithObject:MessageTextViewFont forKey:NSFontAttributeName];
    UITextView *textView = [[UITextView alloc] init];
    [textView setAttributedText:[[NSAttributedString alloc] initWithString:messageText attributes:attrsDictionary]];
    CGSize textSize = [textView sizeThatFits:CGSizeMake(restrictedToWidth, FLT_MAX)];
	
	if (isTopMessage) {
		
		height = kSTChatCellVerticalEdge * 2.0f + kSTChatCellAvatarImageHeight + kSTChatCellVerticalGap + textSize.height;
		
	} else {
		height = kSTChatCellVerticalEdge * 2.0f + textSize.height;
	}
	
	if (isBottomMessage) {
		height += kSTChatCellBottomEmptySpaceHeight;
	}
	
	
	return height;
}


@end
