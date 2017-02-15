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

#import "SpreedMeRoundedButton.h"

#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"
#import "SMLocalizedStrings.h"


@implementation SpreedMeRoundedButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)configureButtonWithButtonType:(SpreedMeButtonType)type
{
    NSString *buttonIcon;
    NSString *buttonText;
    NSMutableAttributedString *buttonAttributedString;
    UIFont *font=[UIFont fontWithName:kFontAwesomeFamilyName size:22];
    UIFont *font2=[UIFont boldSystemFontOfSize:16];
    
    [self setBackgroundColor:kSMGreenButtonColor forState:UIControlStateNormal];
    [self setBackgroundColor:kSMGreenSelectedButtonColor forState:UIControlStateSelected];
    
    switch (type) {
        case kSpreedMeButtonTypeCall:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAPhone];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringCallButton];
            break;
			
		case kSpreedMeButtonTypeVideoCall:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAVideoCamera];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringVideoCallButton];
            break;
			
		case kSpreedMeButtonTypeAddToCall:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAPlus];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringAddToCallButton];
            break;
            
        case kSpreedMeButtonTypeChat:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FACommentsO];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringChatButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            
            break;
            
        case kSpreedMeButtonTypeFile:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAshareAlt];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringMoreOptionsButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            
            break;
            
        case kSpreedMeButtonTypeFullInfo:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAInfo];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringFullInfoButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            
            break;
            
        case kSpreedMeButtonTypeHangUp:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FASignOut];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringHangUpButton];
            
            [self setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMRedSelectedButtonColor forState:UIControlStateSelected];
            
            break;
            
        case kSpreedMeButtonTypeVolume:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FABullhorn];
            buttonText = [NSString stringWithFormat:@"%@", buttonIcon];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            
            break;
            
        case kSpreedMeButtonTypeAddParticipants:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAPlus];
            buttonText = [NSString stringWithFormat:@"%@", buttonIcon];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
        
        case kSpreedMeButtonTypeAbout:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAInfo];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringAboutButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        case kSpreedMeButtonTypeChangeServer:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringChangeServerButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        case kSpreedMeButtonTypeLogOut:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FASignOut];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringSignOutButton];
            
            [self setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMRedSelectedButtonColor forState:UIControlStateSelected];
            break;
        
        case kSpreedMeButtonTypeLogIn:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FASignIn];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringSignInButton];
            
            [self setBackgroundColor:kSMGreenButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMGreenSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        case kSpreedMeButtonTypeChangeVideoOptions:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringChangeOptionsButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
			
		case kSpreedMeButtonTypeDisconnect:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringDisconnectButton];
            
            [self setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMRedSelectedButtonColor forState:UIControlStateSelected];
            break;
		
		case kSpreedMeButtonTypeConnect:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringConnectButton];
            
            [self setBackgroundColor:kSMGreenButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMGreenSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        case kSpreedMeButtonTypeCreate:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringCreateButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        case kSpreedMeButtonTypeReload:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FARefresh];
            buttonText = [NSString stringWithFormat:@"%@", buttonIcon];
            
            [self setBackgroundColor:[UIColor clearColor] forState:UIControlStateNormal];
            [self setBackgroundColor:[UIColor clearColor] forState:UIControlStateSelected];
            break;
			
		case kSpreedMeButtonTypeAcceptNoVideo:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAPhone];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringAnswerButton];
			
			font = [UIFont fontWithName:kFontAwesomeFamilyName size:26];
			font2 = [UIFont boldSystemFontOfSize:22];
			
            break;
			
		case kSpreedMeButtonTypeAcceptWithVideo:
            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAVideoCamera];
            buttonText = [NSString stringWithFormat:@"%@ %@", buttonIcon, kSMLocalStringVideoAnswerButton];
			font = [UIFont fontWithName:kFontAwesomeFamilyName size:26];
			font2 = [UIFont boldSystemFontOfSize:22];
            break;
			
		case kSpreedMeButtonTypeRejectCall:
//            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAVideoCamera];
            buttonText = [NSString stringWithFormat:@"%@", kSMLocalStringRejectCallButton];
			font = [UIFont fontWithName:kFontAwesomeFamilyName size:26];
			font2 = [UIFont boldSystemFontOfSize:22];
			
            [self setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMRedSelectedButtonColor forState:UIControlStateSelected];
            break;
		case kSpreedMeButtonTypeCancelOutgoingCall:
			//            buttonIcon = [NSString fontAwesomeIconStringForEnum:FAVideoCamera];
            buttonText = [NSString stringWithFormat:@"%@", kSMLocalStringStopCallingButton];
			font = [UIFont fontWithName:kFontAwesomeFamilyName size:26];
			font2 = [UIFont boldSystemFontOfSize:22];
			
            [self setBackgroundColor:kSMRedButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMRedSelectedButtonColor forState:UIControlStateSelected];
            break;
        
        case kSpreedMeButtonTypeSignIn:
            buttonIcon = @"";
            buttonText = [NSString stringWithFormat:@"%@", kSMLocalStringSignMeInButton];
            
            [self setBackgroundColor:kSMBlueButtonColor forState:UIControlStateNormal];
            [self setBackgroundColor:kSMBlueSelectedButtonColor forState:UIControlStateSelected];
            break;
            
        default:
            break;
    }
    buttonAttributedString = [[NSMutableAttributedString alloc] initWithString:buttonText];
    [buttonAttributedString addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
    [buttonAttributedString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(1, [buttonAttributedString length]-1)];
    if ([buttonIcon isEqualToString:@""]) {
        [buttonAttributedString addAttribute:NSFontAttributeName value:font2 range:NSMakeRange(0, [buttonAttributedString length]-1)];
    }
    [buttonAttributedString addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, [buttonAttributedString length])];
    
    [self setAttributedTitle:buttonAttributedString forState:UIControlStateNormal];
}

@end
