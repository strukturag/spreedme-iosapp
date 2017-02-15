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

#import "STProgressView.h"

@interface STProgressView ()
{
	UIColor *_defaultTextColor;
}

@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

@end


@implementation STProgressView

#pragma mark - Forbid default init methods

- (instancetype)init
{
	return nil;
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	return [self init];
}


- (instancetype)initWithFrame:(CGRect)frame
{
	return [self init];
}


#pragma mark - Object lifecycle

- (instancetype)initWithWidth:(CGFloat)width
					  message:(NSString *)message
						 font:(UIFont *)font
			 cancelButtonText:(NSString *)cancelButtonText
					 userInfo:(NSDictionary *)userInfo
{
	self = [super initWithFrame:CGRectZero];
	if (self) {
		
		if (!font) {
			font = [UIFont systemFontOfSize:17.0f];
		}
		
		_defaultTextColor = [UIColor whiteColor];
		self.messageTextColor = _defaultTextColor;
		self.backgroundColor = [UIColor blackColor];
		
		CGFloat verticalEdge = 5.0f;
		CGFloat horizontalEdge = 5.0f;
		CGFloat verticalGap = 3.0f;
		CGFloat cancelButtonHeight = 30.0f;
		
		CGFloat labelWidth = width - horizontalEdge * 2.0f;
	
		CGSize sizeForText = [message sizeWithFont:font
								 constrainedToSize:CGSizeMake(labelWidth, CGFLOAT_MAX)
									 lineBreakMode:NSLineBreakByTruncatingTail];
		
		
		_userInfo = userInfo;
		
		
		self.messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(horizontalEdge,
																	  verticalEdge,
																	  labelWidth,
																	  sizeForText.height)];
		self.messageLabel.textAlignment = NSTextAlignmentCenter;
        self.messageLabel.backgroundColor = [UIColor clearColor];
		self.messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
		self.messageLabel.numberOfLines = 0;
		self.messageLabel.textColor = self.messageTextColor;
		self.messageLabel.text = message;
		
		[self addSubview:self.messageLabel];
		
		
		self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		[self.spinner startAnimating];
		self.spinner.center = CGPointMake(width / 2.0f,
										  verticalGap + self.messageLabel.frame.size.height + verticalGap +
											self.spinner.frame.size.height / 2.0f);
		
		[self addSubview:self.spinner];
		if (cancelButtonText.length) {
		
			self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
			self.cancelButton.frame = CGRectMake(horizontalEdge,
												 self.spinner.frame.origin.y + self.spinner.frame.size.height + verticalGap,
												 self.messageLabel.frame.size.width,
												 cancelButtonHeight);
			[self.cancelButton setTitle:cancelButtonText forState:UIControlStateNormal];
			[self.cancelButton addTarget:self
								  action:@selector(cancelButtonPressed:)
						forControlEvents:UIControlEventTouchUpInside];
			
			[self addSubview:self.cancelButton];
		}
		
		CGFloat selfHeight = verticalEdge + self.messageLabel.frame.size.height + verticalGap + self.spinner.frame.size.height +
			(self.cancelButton ? (self.cancelButton.frame.size.height + verticalGap * 2.0f) : 0.0f) + verticalEdge;
		
		self.frame = CGRectMake(0.0f, 0.0f,
								width,
								selfHeight);
	}
	
	return self;
}


- (void)dealloc
{
	
}


#pragma mark - Public Setters/Getters

- (void)setMessageTextColor:(UIColor *)messageTextColor
{
	if (_messageTextColor != messageTextColor) {
		
		_messageTextColor = messageTextColor;
		
		if (_messageTextColor == nil) {
			_messageTextColor = _defaultTextColor;
		}
		
		self.messageLabel.textColor = messageTextColor;
	}
}


#pragma mark - Presentation/dismiss

- (void)presentModallyInView:(UIView *)view
{
	if (view) {
		_viewForModalPresentation = view;
	}
}


- (void)dismiss
{
	if (_viewForModalPresentation) {
		
	}
	
	[self removeFromSuperview];
}


#pragma mark - Actions

- (void)cancelButtonPressed:(id)sender
{
	if (self.cancelBlock) {
		__weak STProgressView* weakSelf = self;
		self.cancelBlock(weakSelf);
	}
	
	[self dismiss];
}


@end
