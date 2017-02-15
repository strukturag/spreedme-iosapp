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

#import "SMLEDPatternCommand.h"

@implementation SMLEDPatternCommand

+ (SMLEDPatternCommand *)ledPatternCommandFromCommandString:(NSString *)commandString
{
    SMLEDPatternCommand *ledPatternCommand = [[SMLEDPatternCommand alloc] init];
    
    ledPatternCommand.well_formed = NO;
    
    if ([commandString length] > 0) {
        NSArray *commandComponents = [commandString componentsSeparatedByString:@" "];
        if ([commandComponents count] == 4) { // Check that there are 4 components
            
            if ([[commandComponents objectAtIndex:0] isEqualToString:@"add"]) { // Chack that first component is "add"
                NSString *color = [commandComponents objectAtIndex:1];
                NSCharacterSet* nonHex = [[NSCharacterSet
                                           characterSetWithCharactersInString: @"0123456789ABCDEFabcdef"]
                                          invertedSet];
                NSRange nonHexRange = [color rangeOfCharacterFromSet: nonHex];
                BOOL isHex = (nonHexRange.location == NSNotFound);
                
                if (isHex && [color length] == 6) { // Check that second component is a hexadecimal number
                    NSString *holdTime = [commandComponents objectAtIndex:2];
                    NSString *fadeTime = [commandComponents objectAtIndex:3];
                    NSCharacterSet* nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
                    NSRange nonDigitsHoldRange = [holdTime rangeOfCharacterFromSet: nonDigits];
                    NSRange nonDigitsFadeRange = [fadeTime rangeOfCharacterFromSet: nonDigits];
                    BOOL areNumbers = (nonDigitsHoldRange.location == NSNotFound) && (nonDigitsFadeRange.location == NSNotFound);
                    
                    if (areNumbers) { // Check that third and fourth components are numbers
                        ledPatternCommand.commandType = [commandComponents objectAtIndex:0];
                        ledPatternCommand.color = [commandComponents objectAtIndex:1];
                        ledPatternCommand.holdTime = [commandComponents objectAtIndex:2];
                        ledPatternCommand.fadeTime = [commandComponents objectAtIndex:3];
                        
                        ledPatternCommand.well_formed = YES;
                    }
                }
                
            }
        }
    }
    
    return ledPatternCommand;
}


- (id)copyWithZone:(NSZone *)zone
{
    SMLEDPatternCommand* copyObject = [[[self class] allocWithZone:zone] init];
    copyObject.well_formed = _well_formed;
    copyObject.commandType = [_commandType copyWithZone:zone];
    copyObject.color = [_color copyWithZone:zone];
    copyObject.holdTime = [_holdTime copyWithZone:zone];
    copyObject.fadeTime = [_fadeTime copyWithZone:zone];
    
    return copyObject;
}


- (NSString *)fullCommandString
{
    return [NSString stringWithFormat:@"%@ %@ %@ %@", self.commandType, self.color, self.holdTime, self.fadeTime];
}


@end
