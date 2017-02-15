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

#import "AnimationView.h"

@implementation ViewAnimation
- (instancetype)init
{
	self = [super init];
	if (self) {
		self.animationOptions = UIViewAnimationOptionCurveEaseInOut;
		self.animationDelay = 0.0;
	}
	return self;
}
@end


@implementation AnimationView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if (self) {
		_runningAnimations = [[NSMutableArray alloc] init];
		_animations = [[NSMutableArray alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appWillResignActive:)
													 name:UIApplicationWillResignActiveNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(appDidBecomeActive:)
													 name:UIApplicationDidBecomeActiveNotification
												   object:nil];
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - UIView Overrides

- (void)didMoveToWindow
{
	[super didMoveToWindow];
	
	if (!self.window) {
		[self conditionalStop];
	} else {
		[self conditionalStart];
	}
}


#pragma mark - Notifications

- (void)appWillResignActive:(NSNotification *)notification
{
	[self conditionalStop];
}


- (void)appDidBecomeActive:(NSNotification *)notification
{
	[self conditionalStart];
}


#pragma mark - Public methods

- (void)animateSequence
{
	if ([_animations count]) {
		_type = kAnimationViewAnimationTypeSequence;
		_runningAnimations = [_animations mutableCopy];
		_isAnimationRepeating = NO;
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			_isAnimating = YES;
			[self animateSequenceInternal];
		}
	} else {
		_isAnimationRepeating = NO;
		_isAnimating = NO;
		_type = kAnimationViewAnimationTypeStopped;
	}
}


- (void)animateSequenceRepeatedly
{
	if ([_animations count]) {
		_type = kAnimationViewAnimationTypeSequenceRepeatedly;
		_runningAnimations = [_animations mutableCopy];
		_isAnimationRepeating = YES;
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			_isAnimating = YES;
			[self animateSequenceRepeatedlyInternal];
		}
	} else {
		_isAnimationRepeating = NO;
		_isAnimating = NO;
		_type = kAnimationViewAnimationTypeStopped;
	}
}


- (void)animateConcurently
{
	
}


- (void)animateConcurentlyRepeatedly
{
	if ([_animations count]) {
		_type = kAnimationViewAnimationTypeConcurentlyRepeatedly;
		_runningAnimations = [_animations mutableCopy];
		_isAnimationRepeating = YES;
		if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
			_isAnimating = YES;
			[self animateConcurentlyRepeatedlyInternal];
		}
	} else {
		_isAnimationRepeating = NO;
		_isAnimating = NO;
		_type = kAnimationViewAnimationTypeStopped;
	}
}


- (void)stopAnimation
{
	[self.layer removeAllAnimations];
	_isAnimating = NO;
	_isAnimationRepeating = NO;
	_type = kAnimationViewAnimationTypeStopped;
}


#pragma mark - Private methods

- (void)conditionalStop
{
	if (_isAnimating) {
		BOOL restartWhenInWindowAgain = NO;
		AnimationViewAnimationType type = _type;
		if (_isAnimationRepeating) {
			restartWhenInWindowAgain = YES;
		}
		
		[self stopAnimation];
		
		if (restartWhenInWindowAgain) {
			_isAnimationRepeating = YES;
			_type = type;
		}
	}
}


- (void)conditionalStart
{
	if (_isAnimationRepeating && !_isAnimating) {
		
		switch (_type) {
			case kAnimationViewAnimationTypeConcurently:
				
			break;
			
			case kAnimationViewAnimationTypeSequence:
				[self animateSequenceInternal];
			break;
			
			case kAnimationViewAnimationTypeSequenceRepeatedly:
				[self animateSequenceRepeatedlyInternal];
			break;
				
			case kAnimationViewAnimationTypeConcurentlyRepeatedly:
				[self animateConcurentlyRepeatedlyInternal];
			break;
				
			case kAnimationViewAnimationTypeStopped:
			default:
			break;
		}
	}
}


- (void)animateSequenceInternal
{
	if ([_runningAnimations count] > 0) {
        ViewAnimation *animation = [_runningAnimations objectAtIndex:0];
        [UIView animateWithDuration:animation.animationDuration
							  delay:animation.animationDelay
							options:animation.animationOptions
                         animations:animation.animationBlock
						 completion:^(BOOL finished){
							 
							 [_runningAnimations removeObjectAtIndex:0];
							 
							 if (animation.completionBlock) {
								 animation.completionBlock(finished);
							 }
							 
							 if (_isAnimating) {
								 [self animateSequenceInternal];
							 }
                         }];
    }
}


- (void)animateSequenceRepeatedlyInternal
{
	if ([_runningAnimations count] > 0) {
        ViewAnimation *animation = [_runningAnimations objectAtIndex:0];
        [UIView animateWithDuration:animation.animationDuration
							  delay:animation.animationDelay
							options:animation.animationOptions
                         animations:animation.animationBlock
						 completion:^(BOOL finished){
							 
							 [_runningAnimations removeObjectAtIndex:0];
							 
							 if (animation.completionBlock) {
								 animation.completionBlock(finished);
							 }
							 
							 if (_isAnimating) {
								 [self animateSequenceRepeatedlyInternal];
							 }
                         }];
    } else {
		[self animateSequenceRepeatedly];
	}
}


- (void)animateConcurentlyRepeatedlyInternal
{
	if ([_runningAnimations count] > 0) {
		
		for (ViewAnimation *animation in _runningAnimations) {
			
			BOOL lastAnimation = animation == _runningAnimations.lastObject;
			
			[UIView animateWithDuration:animation.animationDuration
								  delay:animation.animationDelay
								options:animation.animationOptions
							 animations:animation.animationBlock
							 completion:^(BOOL finished){
								 
								 if (animation.completionBlock) {
									 animation.completionBlock(finished);
								 }
								 
								 if ([self isAnimating] && lastAnimation) {
									 // this dispatch after is needed in order to break infinite loop on iOS6
									 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.001 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
										[self animateConcurentlyRepeatedlyInternal];
									 });
								 }
							 }];
		}

	} else {
		[self animateConcurentlyRepeatedly];
	}
}


- (BOOL)isAnimating
{
    return _isAnimating;
}


@end


// Canvas for animations.
//- (void)prepareDissolveAnimations
//{
//	if (!_animations) {
//		_animations = [[NSMutableArray alloc] init];
//	} else {
//		[_animations removeAllObjects];
//	}
//	
//	ViewAnimation *animation = [[ViewAnimation alloc] init];
//	animation.animationDuration = 0.3;
//	animation.animationBlock = ^{_alertView.alpha = 0.0f;};
//	animation.completionBlock = ^(BOOL finished) {
//		[_alertView removeFromSuperview];
//		_alertView = nil;
//	};
//	
//	[_animations addObject:animation];
//}
//
//
//- (void)prepareShakeAnimations
//{
//	if (!_animations) {
//		_animations = [[NSMutableArray alloc] init];
//	} else {
//		[_animations removeAllObjects];
//	}
//	
//	int animationQuanity = 10;
//	
//	for (int i = 0; i < animationQuanity; i++) {
//		ViewAnimation *animation = [[ViewAnimation alloc] init];
//		animation.animationDuration = 0.03;
//		animation.animationBlock = ^{
//			int randNumX = 0;
//			int randNumY = 0;
//			
//			int module = i % 4;
//			switch (module) {
//				case 0: randNumX = -5; randNumY = 5; break;
//				case 1: randNumX = 5; randNumY = -5; break;
//				case 2: randNumX = 5; randNumY = 5; break;
//				case 3: randNumX = -5; randNumY = -5; break;
//				default: break;
//			}
//			
//			_alertView.center = CGPointMake(_alertView.center.x + randNumX, _alertView.center.y + randNumY);
//		};
//		
//		if (i == animationQuanity - 1) {
//			animation.animationDuration = 0.1;
//			animation.animationBlock = ^{
//				_alertView.alpha = 0.0;
//			};
//			animation.completionBlock = ^(BOOL finished) {
//				[_alertView removeFromSuperview];
//				_alertView = nil;
//			};
//		}
//		
//		[_animations addObject:animation];
//	}
//}


