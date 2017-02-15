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

#import "SMLEDPattern.h"


NSString * const kSMLEDPatternTypePredefined1       = @"add;black;holdfade;0;400;add;color;holdfade;400;400;add;black;holdfade;100;400;add;color;holdfade;400;400;add;black;holdfade;1000;400";
NSString * const kSMLEDPatternTypePredefined2       = @"add;black;holdfade;0;200;add;color;holdfade;200;200;add;black;holdfade;100;200;add;color;holdfade;200;200;add;black;holdfade;800;200";
NSString * const kSMLEDPatternTypePredefined3       = @"add;color;holdfade;1000;0";
NSString * const kSMLEDPatternTypePredefined4       = @"add;black;holdfade;0;200;add;color;holdfade;5000;200;add;black;holdfade;100;200";
NSString * const kSMLEDPatternTypePredefined5       = @"add;black;holdfade;500;250;add;color;holdfade;500;250";
NSString * const kSMLEDPatternTypePredefined6       = @"add;black;holdfade;250;150;add;color;holdfade;250;150";
NSString * const kSMLEDPatternTypePredefined7       = @"add;black;holdfade;500;500;add;color;holdfade;500;500";
NSString * const kSMLEDPatternTypePredefined8       = @"add;black;holdfade;0;250;add;color;holdfade;0;250";
NSString * const kSMLEDPatternTypePredefined9       = @"add;black;holdfade;0;200;add;color;holdfade;2000;200;add;black;holdfade;100;200";
NSString * const kSMLEDPatternTypeCustom            = @"kSMLEDPatternTypeCustom";
NSString * const kSMLEDPatternTypeDisabled          = @"kSMLEDPatternTypeDisabled";
NSString * const kSMLEDPatternTypeUnknown           = @"kSMLEDPatternTypeUnknown";


@implementation SMEditableLEDColor

+ (SMEditableLEDColor *)ledEditableColor:(NSString *)color withOriginalPositionArray:(NSArray *)positionArray
{
    SMEditableLEDColor *ledEditableColor = [[SMEditableLEDColor alloc] init];
    
    ledEditableColor.color = color;
    ledEditableColor.originalPositionArray = positionArray;
    
    return ledEditableColor;
}

@end


@implementation SMLEDPattern

+ (SMLEDPattern *)ledPatternFromCommands:(NSArray *)commandArray
{
    return [self ledPatternFromCommands:commandArray andName:nil];
}


+ (SMLEDPattern *)ledPatternFromCommands:(NSArray *)commandArray andName:(NSString *)name
{
    SMLEDPattern *ledPattern = [[SMLEDPattern alloc] init];
    
    NSArray *patternCommands = [self ledPatternCommandsFromCommands:commandArray];
    NSString *patternType = [self createPatternIdFromPatternCommands:patternCommands];
    NSString *patternName = [self getPatternNameFromPatternType:patternType];
    
    if (name) {
        patternName = name;
        patternType = kSMLEDPatternTypeCustom;
    }
    
    ledPattern.patternName = patternName;
    ledPattern.patternType = patternType;
    ledPattern.commands = patternCommands;
    
    return ledPattern;
}


+ (NSArray *)ledPatternCommandsFromCommands:(NSArray *)commandArray
{
    NSMutableArray *commands = [[NSMutableArray alloc] init];
    
    if (![commandArray isEqual:[NSNull null]]) {
        for (NSString *command in commandArray) {
            SMLEDPatternCommand *patternCommand = [SMLEDPatternCommand ledPatternCommandFromCommandString:command];
            [commands addObject:patternCommand];
        }
    }
    
    return commands;
}


- (id)copyWithZone:(NSZone *)zone
{
    SMLEDPattern* copyObject = [[[self class] allocWithZone:zone] init];
    copyObject.patternName = [_patternName copyWithZone:zone];
    copyObject.patternType = [_patternType copyWithZone:zone];
    copyObject.commands = [[NSArray alloc] initWithArray:_commands copyItems:YES];
    
    return copyObject;
}


+ (NSString *)getPatternNameFromPatternType:(NSString *)patternType
{
    NSDictionary *patternIdsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
        @"Predefined 1", kSMLEDPatternTypePredefined1,
        @"Predefined 2", kSMLEDPatternTypePredefined2,
        @"Predefined 3", kSMLEDPatternTypePredefined3,
        @"Predefined 4", kSMLEDPatternTypePredefined4,
        @"Predefined 5", kSMLEDPatternTypePredefined5,
        @"Predefined 6", kSMLEDPatternTypePredefined6,
        @"Predefined 7", kSMLEDPatternTypePredefined7,
        @"Predefined 8", kSMLEDPatternTypePredefined8,
        @"Predefined 9", kSMLEDPatternTypePredefined9, nil];
    
    if ([patternType isEqualToString:kSMLEDPatternTypeDisabled]) {
        return @"Disabled";
    } else if ([patternType isEqualToString:kSMLEDPatternTypeUnknown]) {
        return @"Unknown";
    }
    
    NSString *patternName = [patternIdsDict objectForKey:patternType];
    if (!patternName) {
        patternName = @"Custom";
    }
    
    return patternName;
}


+ (NSString *)createPatternIdFromPatternCommands:(NSArray *)commands
{
    NSMutableArray *patternIdArray = [[NSMutableArray alloc] init];
    NSString *patternId = kSMLEDPatternTypeUnknown;
    
    if (commands) {
        NSInteger numberOfCommands = [commands count];
        if (numberOfCommands > 0) {
            for (int i = 0; i < numberOfCommands; i++) {
                SMLEDPatternCommand *command = [commands objectAtIndex:i];
                if (command.well_formed) {
                    if ([command.commandType isEqualToString:@"add"]) {
                        // add 000000 500 500
                        [patternIdArray addObject:@"add"];
                        if ([command.color isEqualToString:@"000000"]) {
                            [patternIdArray addObject:@"black"];
                        } else {
                            [patternIdArray addObject:@"color"];
                        }
                        [patternIdArray addObject:@"holdfade"];
                        [patternIdArray addObject:command.holdTime];
                        [patternIdArray addObject:command.fadeTime];
                        
                        patternId = [patternIdArray componentsJoinedByString:@";"];
                    }
                } else {
                    patternId = kSMLEDPatternTypeUnknown;
                }
            }
        } else {
            patternId = kSMLEDPatternTypeDisabled;
        }
    }
    
    return patternId;
}


- (NSArray *)ledPatternStringArrayRepresentation
{
    NSMutableArray *ledPatternArray = [[NSMutableArray alloc] init];
    
    for (SMLEDPatternCommand *command in _commands) {
        [ledPatternArray addObject:command.fullCommandString];
    }
    
    return ledPatternArray;
}


- (NSArray *)patternColors
{
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    
    for (SMLEDPatternCommand *command in _commands) {
        [colors addObject:command.color];
    }
    
    return colors;
}


- (NSArray *)patternEditableColors
{
    NSMutableArray *colors = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < _commands.count; i++) {
        SMLEDPatternCommand *command = [_commands objectAtIndex:i];
        if (![command.color isEqualToString:@"000000"]) {
            BOOL alreadyExist = NO;
            if (_patternType != kSMLEDPatternTypeUnknown && _patternType != kSMLEDPatternTypeDisabled) {
                for (int j = 0; j < [colors count]; j++) {
                    SMEditableLEDColor *editableColor = [colors objectAtIndex:j];
                    if ([editableColor.color isEqualToString:command.color]) {
                        NSMutableArray *positions = [NSMutableArray arrayWithArray:editableColor.originalPositionArray];
                        [positions addObject:[NSNumber numberWithInteger:i]];
                        SMEditableLEDColor *newEditableColor = [SMEditableLEDColor ledEditableColor:command.color withOriginalPositionArray:positions];
                        [colors replaceObjectAtIndex:j withObject:newEditableColor];
                        alreadyExist = YES;
                        break;
                    }
                }
            }
            if (!alreadyExist) {
                NSArray *positionArray = [NSArray arrayWithObjects:[NSNumber numberWithInteger:i], nil];
                SMEditableLEDColor *editableColor = [SMEditableLEDColor ledEditableColor:command.color withOriginalPositionArray:positionArray];
                [colors addObject:editableColor];
            }
        }
    }
    
    return colors;
}


- (void)setColorsToPatternFromEditableColors:(NSArray *)editableColors
{
    NSMutableArray *patternCommands = [[NSMutableArray alloc] initWithArray:_commands];
    
    if (_patternType != kSMLEDPatternTypeUnknown) {
        for (SMEditableLEDColor *editableColor in editableColors) {
            for (NSNumber *position in editableColor.originalPositionArray) {
                SMLEDPatternCommand *command = [patternCommands objectAtIndex:position.integerValue];
                command.color = editableColor.color;
            }
        }
    }
    
    _commands = patternCommands;
}


@end
