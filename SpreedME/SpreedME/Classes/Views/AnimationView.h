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

typedef enum : NSUInteger {
	kAnimationViewAnimationTypeStopped = 0,
	kAnimationViewAnimationTypeSequence,
	kAnimationViewAnimationTypeSequenceRepeatedly,
	kAnimationViewAnimationTypeConcurently,
	kAnimationViewAnimationTypeConcurentlyRepeatedly,
} AnimationViewAnimationType;


typedef void (^AnimationBlock)(void);
typedef void (^CompletionBlock)(BOOL finished);

@interface ViewAnimation : NSObject
@property (nonatomic, strong) AnimationBlock animationBlock;
@property (nonatomic, assign) NSTimeInterval animationDuration;
@property (nonatomic, strong) CompletionBlock completionBlock;
@property (nonatomic, readwrite) UIViewAnimationOptions animationOptions; // Defaults to UIViewAnimationOptionCurveEaseInOut
@property (nonatomic, readwrite) NSTimeInterval animationDelay; // Defaults to 0.0

@end


@interface AnimationView : UIView 
{
	BOOL _isAnimating;
	BOOL _isAnimationRepeating;
	
	NSMutableArray *_runningAnimations;
	NSMutableArray *_animations;
	
	AnimationViewAnimationType _type;
}

@property (nonatomic, copy) NSMutableArray *animations;


- (void)animateSequence;
- (void)animateSequenceRepeatedly;
- (void)animateConcurentlyRepeatedly;
- (void)stopAnimation;

@end
