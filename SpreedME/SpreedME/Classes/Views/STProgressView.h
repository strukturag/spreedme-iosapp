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

#import <UIKit/UIKit.h>

@class STProgressView;

typedef void (^STProgressViewCancelBlock)(STProgressView *progressView);

/*
 STProgressView is not intended to be resized after creation. Although you can resize it this will break layout.
 */

@interface STProgressView : UIView
{
	UIColor *_messageTextColor;
	STProgressViewCancelBlock _cancelBlock;
	
	UIView *_viewForModalPresentation;
	
	NSDictionary *_userInfo;
	NSString *_message;
	NSString *_cancelButtonTitle;
}

@property (nonatomic, strong) UIColor *messageTextColor; // by default [UIColor whiteColor]
@property (nonatomic, strong) STProgressViewCancelBlock cancelBlock; // executed only when cancel button pressed


- (instancetype)initWithWidth:(CGFloat)width
					  message:(NSString *)message
						 font:(UIFont *)font // pass nil for systemFontWithSize:17.0
			 cancelButtonText:(NSString *)cancelButtonText
					 userInfo:(NSDictionary *)userInfo;

- (void)presentModallyInView:(UIView *)view;

- (void)dismiss; // does not execute cancel block


@end
