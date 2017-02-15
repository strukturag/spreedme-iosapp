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

#import "SMLEDState.h"

@implementation SMLEDState

+ (SMLEDState *)ledStateFromStateId:(NSString *)stateId andCommands:(NSArray *)commandArray
{
    SMLEDState *ledState = [[SMLEDState alloc] init];
    
    ledState.stateId = stateId;
    ledState.stateName = [self getLEDStateNameFromStateId:stateId];
    ledState.pattern = [SMLEDPattern ledPatternFromCommands:commandArray];
    
    return ledState;
}


- (id)copyWithZone:(NSZone *)zone
{
    SMLEDState* copyObject = [[[self class] allocWithZone:zone] init];
    copyObject.stateId = [_stateId copyWithZone:zone];
    copyObject.stateName = [_stateName copyWithZone:zone];
    copyObject.pattern = [_pattern copyWithZone:zone];
    
    return copyObject;
}


- (NSArray *)colorArray
{
    return [self.pattern patternColors];
}


- (NSArray *)editableColorsArray
{
    return [self.pattern patternEditableColors];
}


#pragma mark - Utils

+ (NSString *)getLEDStateNameFromStateId:(NSString *)state
{
    if ([state isEqualToString:@"call-incoming"]) {
        return @"Incoming call";
    } else if ([state isEqualToString:@"call-incoming-prio"]) {
        return @"Priority incoming call";
    } else if ([state isEqualToString:@"idle"]) {
        return @"Idle";
    } else if ([state isEqualToString:@"network-disconnected"]) {
        return @"Network disconnected";
    } else if ([state isEqualToString:@"system-updating"]) {
        return @"System updating";
    } else if ([state isEqualToString:@"system-updating-critical"]) {
        return @"System updating critical";
    } else if ([state isEqualToString:@"user-message"]) {
        return @"Message received";
    } else if ([state isEqualToString:@"user-message-prio"]) {
        return @"Priority message received";
    } else if ([state isEqualToString:@"user-missed-call"]) {
        return @"Missed call";
    } else if ([state isEqualToString:@"wlan-hotspot"]) {
        return @"Wi-Fi hotspot";
    }
    
    return state;
}

@end
