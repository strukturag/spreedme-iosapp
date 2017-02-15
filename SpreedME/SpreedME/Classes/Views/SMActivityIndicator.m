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

#import "SMActivityIndicator.h"


const CGFloat kSMActivityIndicatorDefaultHeight		= 22.0f;

const CGFloat kSMActivityIndicatorHorizontalEdge		= 1.0f;
const CGFloat kSMActivityIndicatorVerticalEdge		= 1.0f;

@interface SMActivityIndicator ()
{
	BOOL _isAnimating;
	
	CGFloat _imageAspectRatio;
	
	BOOL _shouldRestartAnimation;
}

@property (nonatomic, strong) UIImageView *leftE;
@property (nonatomic, strong) UIImageView *rightE;

@end


@implementation SMActivityIndicator

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = nil;
    return self;
}


- (instancetype)initWithHeight:(CGFloat)height
{
	CGFloat width = height * 4.0f;
	
	self = [super initWithFrame:CGRectMake(0.0f, 0.0f, width, height)];
	if (self) {
		
		UIImage *leftImage = [UIImage imageNamed:@"left_e"];
		if (leftImage.size.width > 0.5f && leftImage.size.height > 0.5f) {
			_imageAspectRatio = leftImage.size.width / leftImage.size.height;
		} else {
			_imageAspectRatio = 0.0f;
		}
		
		self.leftE = [[UIImageView alloc] initWithImage:leftImage];
		self.leftE.backgroundColor = [UIColor clearColor];
		self.leftE.contentMode = UIViewContentModeScaleAspectFit;
		self.rightE = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"right_e"]];
		self.rightE.backgroundColor = [UIColor clearColor];
		self.rightE.contentMode = UIViewContentModeScaleAspectFit;
		
		self.leftE.frame = CGRectMake(kSMActivityIndicatorHorizontalEdge,
									  kSMActivityIndicatorVerticalEdge,
									  (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
									  self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge);
		self.rightE.frame = CGRectMake(self.bounds.size.width - kSMActivityIndicatorHorizontalEdge - (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
									   kSMActivityIndicatorVerticalEdge,
									   (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
									   self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge);
		
		
		[self addSubview:self.leftE];
		[self addSubview:self.rightE];
	}
	
	return self;
}


- (instancetype)init
{
	self = [self initWithHeight:kSMActivityIndicatorDefaultHeight];
	return self;
}


- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
	return [super initWithCoder:aDecoder];
}


- (instancetype)awakeAfterUsingCoder:(NSCoder *)aDecoder
{
	SMActivityIndicator *indicator = [super awakeAfterUsingCoder:aDecoder];
	self = [[SMActivityIndicator alloc] initWithHeight:indicator.bounds.size.height];
	
	return self;
}


#pragma mark - UIView overrides

- (void)setBounds:(CGRect)bounds
{
	return;
}


- (void)setFrame:(CGRect)frame
{	
	return;
}


- (void)setCenter:(CGPoint)center
{
	return [super setCenter:center];
}


- (void)setHidden:(BOOL)hidden
{
	[super setHidden:hidden];
	if (hidden == YES && _isAnimating == YES) {
		[self stopAnimating];
	}
}


- (void)didMoveToWindow
{
	if (!self.window) {
		if (_isAnimating) {
			[self stopAnimating];
			_shouldRestartAnimation = YES;
		}
	} else {
		if (_shouldRestartAnimation && !_isAnimating) {
			[self startAnimating];
		}
	}
}


#pragma mark -

- (void)checkStartAnimating
{
	if (_isAnimating) {
		[self animate];
	}
}


- (void)animate
{
	self.leftE.frame = CGRectMake(kSMActivityIndicatorHorizontalEdge,
								  kSMActivityIndicatorVerticalEdge,
								  (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
								  self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge);
	self.rightE.frame = CGRectMake(self.bounds.size.width - kSMActivityIndicatorHorizontalEdge - (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
								   kSMActivityIndicatorVerticalEdge,
								   (self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge) * _imageAspectRatio,
								   self.bounds.size.height - 2 * kSMActivityIndicatorVerticalEdge);

	[UIView animateWithDuration:1.0
						  delay:0
						options:UIViewAnimationOptionCurveLinear
					 animations:^{
						 self.leftE.center = CGPointMake(self.bounds.size.width / 2.0f - self.leftE.frame.size.width / 2.0f,
														 self.leftE.center.y);
						 self.rightE.center = CGPointMake(self.bounds.size.width / 2.0f + self.rightE.frame.size.width / 2.0f,
														  self.rightE.center.y);
					 }
					 completion:^(BOOL finished) {
						 if (!finished) {
							 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
								 [self checkStartAnimating];
							 });
						 } else {
							 [UIView animateWithDuration:1.0
												   delay:0
												 options:UIViewAnimationOptionCurveLinear
											  animations:^{
												  self.leftE.transform = CGAffineTransformMakeScale(-1, 1);
												  self.rightE.transform = CGAffineTransformMakeScale(-1, 1);
											  }
											  completion:^(BOOL finished) {
												  if (!finished) {
													  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
														  [self checkStartAnimating];
													  });
												  } else {
													  [UIView animateWithDuration:1.0
																			delay:0
																		  options:UIViewAnimationOptionCurveLinear
																	   animations:^{
																		   self.leftE.center = CGPointMake(kSMActivityIndicatorHorizontalEdge + self.leftE.frame.size.width / 2.0f,
																										   self.leftE.center.y);
																		   self.rightE.center = CGPointMake(self.bounds.size.width - self.rightE.frame.size.width / 2.0f - kSMActivityIndicatorHorizontalEdge,
																											self.rightE.center.y);
																	   }
																	   completion:^(BOOL finished) {
																		   if (!finished) {
																			   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
																				   [self checkStartAnimating];
																			   });
																		   } else {
																			   [UIView animateWithDuration:1.0
																									 delay:0
																								   options:UIViewAnimationOptionCurveLinear
																								animations:^{
																									self.leftE.transform = CGAffineTransformMakeScale(1, 1);
																									self.rightE.transform = CGAffineTransformMakeScale(1, 1);
																								}
																								completion:^(BOOL finished) {
																									if (!finished) {
																										dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
																											[self checkStartAnimating];
																										});
																									} else {
																										[self checkStartAnimating];
																									}
																								}];
																		   }
																	   }];
												  }
											  }];
						 }
					 }];
}


#pragma mark - Public methods

- (void)startAnimating
{
	if (!_isAnimating) {
		_isAnimating = YES;
		[self checkStartAnimating];
	}
}


- (void)stopAnimating
{
	[self.layer removeAllAnimations];
	_isAnimating = NO;
	_shouldRestartAnimation = NO;
	
	if (self.hidesWhenStopped) {
		self.hidden = YES;
	}
}


- (BOOL)isAnimating
{
	return _shouldRestartAnimation;
}


@end
