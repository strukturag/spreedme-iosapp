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

#import "STChatInputView.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


const CGFloat kHorisontalEdge		= 5.0f;
const CGFloat kHorisontalGap		= kHorisontalEdge;
const CGFloat kVerticalEdge			= 5.0f;
const CGFloat kVerticalGap			= kVerticalEdge;

const CGFloat kSendButtonWidth		= 60.0f;
const CGFloat kSendButtonHeight		= 40.0f;

const CGFloat kSendPhotoButtonWidth		= 40.0f;
const CGFloat kSendPhotoButtonHeight	= 40.0f;

const CGFloat kTextViewIntialHeight     = 35.5f;
const CGFloat kTextViewMaxHeight        = 131.0f;


@implementation STChatInputView
{
    BOOL _isTyping;
    BOOL _isLastCharacter;
    CALayer *_upperBorder;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self initViews];
	}
	return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		[self initViews];
    }
    return self;
}


- (void)initViews
{
	_enabled = YES;
	
    self.backgroundColor = kSTChatInputViewBackgroundColor;
    
    // Add an upperBorder.
    _upperBorder = [CALayer layer];
    _upperBorder.frame = CGRectMake(0.0f, 0.0f, self.frame.size.width, 0.5f);
    _upperBorder.backgroundColor = [[[UIColor grayColor] colorWithAlphaComponent:0.8] CGColor];
    [self.layer addSublayer:_upperBorder];
    
    //Configuring Send Button
	_sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	_sendButton.frame = CGRectMake(self.frame.size.width - kHorisontalEdge - kSendButtonWidth,
								   kVerticalEdge,
								   kSendButtonWidth, kSendButtonHeight);
    
    _sendButton.titleLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:24];
    [_sendButton setTitle:[NSString fontAwesomeIconStringForEnum:FAsend] forState:UIControlStateNormal];
	[_sendButton setTitleColor:kSTChatInputViewSendButtonTitleColor forState:UIControlStateNormal];
    [_sendButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
    [_sendButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateDisabled];
	[_sendButton addTarget:self action:@selector(sendButtonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
	
	[self addSubview:_sendButton];
    
    //Configuring Send Photo Button
    _sendPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_sendPhotoButton.frame = CGRectMake(kHorisontalEdge,
								   kVerticalEdge,
								   kSendPhotoButtonWidth, kSendPhotoButtonHeight);
	_sendPhotoButton.titleLabel.font = [UIFont fontWithName:kFontAwesomeFamilyName size:24];
	[_sendPhotoButton setTitle:[NSString fontAwesomeIconStringForEnum:FAShareSquareO] forState:UIControlStateNormal];
	[_sendPhotoButton setTitleColor:kSMBlueButtonColor forState:UIControlStateNormal];
    [_sendPhotoButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
    [_sendPhotoButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateDisabled];
	[_sendPhotoButton addTarget:self action:@selector(sendPhotoButtonWasPressed:) forControlEvents:UIControlEventTouchUpInside];
	
	[self addSubview:_sendPhotoButton];
	
    //Configuring TextView Input Field
	_textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(2.0f * kHorisontalEdge + kSendPhotoButtonWidth, (self.frame.size.height - kTextViewIntialHeight)/2,
																  self.frame.size.width - kSendButtonWidth - kHorisontalEdge - kSendPhotoButtonWidth - kHorisontalEdge * 2.0f - kHorisontalGap,
																  kTextViewIntialHeight)];
    _textViewContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	_textView = [[UITextView alloc] initWithFrame:_textViewContainer.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_textView setDelegate:self];
    [_textView setFont:[UIFont systemFontOfSize:16]];
	_textView.backgroundColor = [UIColor whiteColor];
    
    [_textView.layer setBorderColor:[[[UIColor darkGrayColor] colorWithAlphaComponent:0.6] CGColor]];
    [_textView.layer setBorderWidth:1.0];
    
    _textView.layer.cornerRadius = kViewCornerRadius;
    _textView.clipsToBounds = YES;
    
	[_textViewContainer addSubview:_textView];
	
	[self addSubview:_textViewContainer];
	
	[self setupItselfEnabled];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    _upperBorder.frame = CGRectMake(_upperBorder.frame.origin.x,
                                    _upperBorder.frame.origin.y,
                                    self.bounds.size.width,
                                    _upperBorder.frame.size.height);
}


- (void)sendTextMessage
{
	NSString *text = [_textView.text copy];
    _isTyping = NO;
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputView:sendTextMessageWithText:)]) {
		[self.delegate chatInputView:self sendTextMessageWithText:text];
	}
}


- (IBAction)sendButtonWasPressed:(id)sender
{
	[self sendTextMessage];
    [self textViewDidChange:_textView];
}


- (IBAction)sendPhotoButtonWasPressed:(id)sender
{
	if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputViewPhotoButtonWasPressed:)]) {
		[self.delegate chatInputViewPhotoButtonWasPressed:self];
	}
}


- (void)resizeInputViewWithHeight:(CGFloat)height
{
    CGFloat heightDifference = height - _textView.frame.size.height;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputView:willResizeWithHeight:)]) {
        [self.delegate chatInputView:self willResizeWithHeight:heightDifference];
    }
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y - heightDifference, self.frame.size.width, self.frame.size.height + heightDifference);
    _textViewContainer.frame = CGRectMake(_textViewContainer.frame.origin.x, _textViewContainer.frame.origin.y, _textViewContainer.frame.size.width, height);
    _textView.frame = CGRectMake(_textView.frame.origin.x, _textView.frame.origin.y, _textView.frame.size.width, height);
    _sendButton.frame = CGRectMake(_sendButton.frame.origin.x, _sendButton.frame.origin.y + heightDifference, _sendButton.frame.size.width, _sendButton.frame.size.height);
    _sendPhotoButton.frame = CGRectMake(_sendPhotoButton.frame.origin.x, _sendPhotoButton.frame.origin.y + heightDifference, _sendPhotoButton.frame.size.width, _sendPhotoButton.frame.size.height);
    
    CGPoint scrollPoint = CGPointMake(0, self.textView.contentSize.height - _textView.frame.size.height);
    [_textView setContentOffset:scrollPoint animated:YES];
}


#pragma mark - 

- (void)setupItselfEnabled
{
	self.textView.userInteractionEnabled = YES;
	self.textView.backgroundColor = [UIColor whiteColor];
	self.sendButton.enabled = YES;
}


- (void)setupItselfDisabled
{
	self.textView.userInteractionEnabled = NO;
	self.textView.backgroundColor = [UIColor lightGrayColor];
	self.sendButton.enabled = NO;
}


- (void)setEnabled:(BOOL)enabled
{
	if (_enabled != enabled) {
		_enabled = enabled;
		if (_enabled) {
			[self setupItselfEnabled];
		} else {
			[self setupItselfDisabled];
		}
	}
}


#pragma mark - UITextView delegate


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    _isLastCharacter = (range.location == _textView.text.length) ? YES : NO;
    return YES;
}


- (void)textViewDidChange:(UITextView *)textView
{
    CGFloat fixedWidth = textView.frame.size.width;
    CGSize newSize = [textView sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];
    CGSize newContentSize = textView.contentSize;
    CGFloat neededHeight = newSize.height;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputView:userIsTyping:)]) {
        if ([textView.text length]>0) {
            _isTyping = YES;
            [self.delegate chatInputView:self userIsTyping:YES];
            
        } else {
            if (_isTyping) {
                [self.delegate chatInputView:self userIsTyping:NO];
                _isTyping = NO;
            }
        }
    }
    
    if (neededHeight > textView.frame.size.height) {
        if (neededHeight > kTextViewMaxHeight) {
            if (textView.frame.size.height < kTextViewMaxHeight) {
                [self resizeInputViewWithHeight:kTextViewMaxHeight];
            }
            if (_textView.contentSize.height < newSize.height) {
                newContentSize.height = neededHeight;
                self.textView.contentSize = newContentSize;
                CGPoint scrollPoint = CGPointMake(0, self.textView.contentSize.height - _textView.frame.size.height);
                
                if (_isLastCharacter) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [textView setContentOffset:scrollPoint animated:YES];
                    });
                }
            }
            
        } else {
            [self resizeInputViewWithHeight:neededHeight];
        }
    } else if (neededHeight <= kTextViewIntialHeight) {
        [self resizeInputViewWithHeight:kTextViewIntialHeight];
    } else {
        [self resizeInputViewWithHeight:neededHeight];
    }
}


- (void)textViewDidEndEditing:(UITextView *)textView
{
    if (_isTyping) {
        [self.delegate chatInputView:self userIsTyping:NO];
    }
}


@end
