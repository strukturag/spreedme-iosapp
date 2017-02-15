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

#import "WaveBackgroundAnimationView.h"

#import <QuartzCore/QuartzCore.h>

#import "FrameView.h"

@interface WaveBackgroundAnimationView ()
{
	BOOL _hidesWhenStopped;
	
	BOOL _isAnimating;
	BOOL _shouldRestartAnimation;
	
	
	NSMutableArray *_waves;
	
	NSMutableArray *_waveWidths;
}

@end


@implementation WaveBackgroundAnimationView

@synthesize hidesWhenStopped = _hidesWhenStopped;


- (instancetype)initWithWithForegroundView:(UIView *)foregroundView numberOfWaves:(NSUInteger)numberOfWaves waveWidths:(NSArray *)waveWidths
{
	if (numberOfWaves == 0 || numberOfWaves != [waveWidths count] || !foregroundView) {
		self = nil;
		return self;
	}
	
	CGRect foregroundViewFrame = foregroundView.frame;
	
	CGRect calculatedFrame = foregroundView.bounds;
	
	for (NSNumber *waveWidth in waveWidths) {
		calculatedFrame.size.height += [waveWidth floatValue];
		calculatedFrame.size.width += [waveWidth floatValue];
	}
	
	self = [super initWithFrame:calculatedFrame];
	if (self) {
		_waveWidths = [[NSMutableArray alloc] initWithArray:waveWidths];
		
		_waves = [[NSMutableArray alloc] initWithCapacity:[waveWidths count]];
		
		CGFloat accumulatedFrameWidth = 0.0f;
		CGFloat previousAccumulatedFrameWidth = 0.0f;
		
		BOOL isFirstWave = YES;
		
		for (NSNumber *waveWidth in _waveWidths) {
			
			accumulatedFrameWidth += [waveWidth floatValue];
			
			FrameView *wave = [[FrameView alloc] initWithFrame:CGRectMake(0.0f, 0.0f,
																		  foregroundViewFrame.size.width + accumulatedFrameWidth * 2.0f,
																		  foregroundViewFrame.size.height + accumulatedFrameWidth * 2.0f)
												 andFrameWidth:[waveWidth floatValue] + previousAccumulatedFrameWidth];
			wave.layer.cornerRadius = foregroundView.layer.cornerRadius;
			wave.layer.masksToBounds = YES;
            wave.backgroundColor = kSpreedMeBlueColorAlpha06;
			
//			if (isFirstWave) {
				wave.innerRadius = foregroundView.layer.cornerRadius;
				isFirstWave = NO;
//			}
			
			[_waves addObject:wave];
			[self addSubview:wave];
			wave.center = self.center;
			previousAccumulatedFrameWidth += [waveWidth floatValue];
			wave.alpha = 0.0f;
		}
		
		self.layer.cornerRadius = foregroundView.layer.cornerRadius;
		self.backgroundColor = [UIColor clearColor];
	}
	
	return self;
}


- (instancetype)initWithWithForegroundView:(UIView *)foregroundView
{
	NSArray *waveWidths = @[@(10.0f), @(10.0f), @(10.0f)];
	return [self initWithWithForegroundView:foregroundView numberOfWaves:3 waveWidths:waveWidths];
}


#pragma mark - UIView Overrides

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


#pragma mark - Public Methods

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


#pragma mark - Private methods

- (void)checkStartAnimating
{
	if (_isAnimating && self.window) {
		[self stopAnimating];
		_isAnimating = YES;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self animate];
		});
	} else if (_isAnimating && !self.window) {
		[self stopAnimating];
		_shouldRestartAnimation = YES;
	}
}


- (void)animate
{
	double wavesNumber = (double)[_waves count];
	NSTimeInterval duration = (NSTimeInterval)[_waves count];
	if (duration > 2) {
		duration = 2;
	}
	
	for (FrameView *wave in _waves) {
		wave.alpha = 0.0f;
	}
	
//	if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
//	
//		[UIView animateKeyframesWithDuration:duration delay:0.0
//									 options:UIViewKeyframeAnimationOptionBeginFromCurrentState |
//											UIViewKeyframeAnimationOptionRepeat |
//											UIViewKeyframeAnimationOptionAutoreverse |
//											UIViewKeyframeAnimationOptionCalculationModeCubic
//								  animations:^{
//									  
//									  for (FrameView *wave in _waves) {
//										  NSInteger waveNumber = [_waves indexOfObject:wave];
//										  
//										  [UIView addKeyframeWithRelativeStartTime:waveNumber / wavesNumber
//																  relativeDuration:1 / wavesNumber
//																		animations:^{
//																			wave.alpha = 1.0f / waveNumber;
//																		}];
//									  }
//									  
//								  } completion:^(BOOL finished) {
//									  [self checkStartAnimating];
//								  }];
//	} else {
	
		
		
		for (FrameView *wave in _waves) {
			NSInteger waveNumber = [_waves indexOfObject:wave];
			ViewAnimation *animation = [[ViewAnimation alloc] init];
			animation.animationOptions = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat;
			animation.animationBlock = ^{ wave.alpha = 1.0f / waveNumber; };
			animation.animationDuration = (1 / wavesNumber) * duration;
			animation.animationDelay = ((waveNumber * 1 + 0) / wavesNumber) * duration;
			
			if (waveNumber == wavesNumber - 1) {
				animation.completionBlock = ^(BOOL finished) {
//					[self checkStartAnimating];
				};
			}
			
			[_animations addObject:animation];	
		}
		[self animateConcurentlyRepeatedly];
//	}
}


@end
