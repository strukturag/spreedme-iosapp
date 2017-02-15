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

#import "STChatCellColorController.h"


@interface STChatCellColorController ()
{
	NSMutableDictionary *_indexForId;
	NSMutableArray *_colorPool;
	NSUInteger _lastUsedColorIndex;
	
	NSMutableDictionary *_userSpecificColorsForIds;
	
	BOOL _poolIsNotEnough;
}


@end


@implementation STChatCellColorController

+ (STChatCellColorController *)sharedInstance
{
	static dispatch_once_t once;
    static STChatCellColorController *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


#pragma mark - Object lifecycle

- (instancetype)init
{
	self = [super init];
	if (self) {
		_indexForId = [[NSMutableDictionary alloc] init];
		_userSpecificColorsForIds = [[NSMutableDictionary alloc] init];
		_lastUsedColorIndex = 0;
		[self populateColorPool];
	}
	
	return self;
}


- (void)populateColorPool
{
	UIColor *color0 = [UIColor colorWithRed:164.0f/255.0f green:184.0f/255.0f blue:204.0f/255.0f alpha:0.8];
	UIColor *color1 = [UIColor colorWithRed:197.0f/255.0f green:184.0f/255.0f blue:204.0f/255.0f alpha:0.8];
	UIColor *color2 = [UIColor colorWithRed:197.0f/255.0f green:218.0f/255.0f blue:204.0f/255.0f alpha:0.8];
	UIColor *color3 = [UIColor colorWithRed:183.0f/255.0f green:191.0f/255.0f blue:224.0f/255.0f alpha:0.8];
	UIColor *color4 = [UIColor colorWithRed:183.0f/255.0f green:191.0f/255.0f blue:135.0f/255.0f alpha:0.8];
	UIColor *color5 = [UIColor colorWithRed:183.0f/255.0f green:176.0f/255.0f blue:86.0f/255.0f alpha:0.8];
	UIColor *color6 = [UIColor colorWithRed:183.0f/255.0f green:150.0f/255.0f blue:137.0f/255.0f alpha:0.8];
	UIColor *color7 = [UIColor colorWithRed:234.0f/255.0f green:197.0f/255.0f blue:23.0f/255.0f alpha:0.8];
	UIColor *color8 = [UIColor colorWithRed:234.0f/255.0f green:174.0f/255.0f blue:255.0f/255.0f alpha:0.8];
	UIColor *color9 = [UIColor colorWithRed:165.0f/255.0f green:174.0f/255.0f blue:255.0f/255.0f alpha:0.8];
	UIColor *color10 = [UIColor colorWithRed:165.0f/255.0f green:188.0f/255.0f blue:34.0f/255.0f alpha:0.8];
	UIColor *color11 = [UIColor colorWithRed:229.0f/255.0f green:170.0f/255.0f blue:122.0f/255.0f alpha:0.8];
	
	
	_colorPool = [@[color0, color1, color2, color3, color4, color5, color6, color7, color8, color9, color10, color11] mutableCopy];
}


#pragma mark - Public Methods

- (UIColor *)colorForId:(NSString *)uId
{
	UIColor *color = nil;
	
	if ([uId length] > 0) {
		
		color = [_userSpecificColorsForIds objectForKey:uId];
		if (color) {
			return color;
		}
		
		// If pool is not enough then give all users the same 'spreed grey' color
		if (_poolIsNotEnough) {
            return kGrayColor_e5e5e5;
		}
		
		NSNumber *index = [_indexForId objectForKey:uId];
		if (index) {
			color = _colorPool[[index unsignedIntegerValue]];
		} else {
			// if we need color and color pool is finished
			if (_lastUsedColorIndex > [_colorPool count] - 1) {
				_poolIsNotEnough = YES;
                return kGrayColor_e5e5e5;
			}
			
			[_indexForId setObject:@(_lastUsedColorIndex) forKey:uId];
			color = _colorPool[_lastUsedColorIndex];
			
			++_lastUsedColorIndex; // We don't really expect more than couple of thousands users at the same time
		}
	}
	
	return color;
}


- (void)setSpecificColor:(UIColor *)color forId:(NSString *)uId
{
	if (color && [uId length] > 0) {
		[_userSpecificColorsForIds setObject:color forKey:uId];
	}
}


@end
