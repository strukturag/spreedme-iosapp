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

#import <Foundation/Foundation.h>

#import "SMLEDPatternCommand.h"


NSString * const kSMLEDPatternTypePredefined1;
NSString * const kSMLEDPatternTypePredefined2;
NSString * const kSMLEDPatternTypePredefined3;
NSString * const kSMLEDPatternTypePredefined4;
NSString * const kSMLEDPatternTypePredefined5;
NSString * const kSMLEDPatternTypePredefined6;
NSString * const kSMLEDPatternTypePredefined7;
NSString * const kSMLEDPatternTypePredefined8;
NSString * const kSMLEDPatternTypePredefined9;
NSString * const kSMLEDPatternTypeCustom;
NSString * const kSMLEDPatternTypeDisabled;
NSString * const kSMLEDPatternTypeUnknown;


@interface SMEditableLEDColor : NSObject

@property (nonatomic, strong) NSArray *originalPositionArray;
@property (nonatomic, strong) NSString *color;

+ (SMEditableLEDColor *)ledEditableColor:(NSString *)color withOriginalPositionArray:(NSArray *)positionArray;

@end



@interface SMLEDPattern : NSObject <NSCopying>

@property (nonatomic, strong) NSString *patternName;
@property (nonatomic, strong) NSString *patternType;
@property (nonatomic, strong) NSArray *commands;

+ (SMLEDPattern *)ledPatternFromCommands:(NSArray *)commandArray;
+ (SMLEDPattern *)ledPatternFromCommands:(NSArray *)commandArray andName:(NSString *)name;
- (NSArray *)ledPatternStringArrayRepresentation;
- (NSArray *)patternColors;
- (NSArray *)patternEditableColors;
- (void)setColorsToPatternFromEditableColors:(NSArray *)editableColors;

@end
