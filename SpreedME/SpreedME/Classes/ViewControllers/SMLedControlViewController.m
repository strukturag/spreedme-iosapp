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

#import "SMLedControlViewController.h"

#import "SortedDictionary/SortedDictionary/Public/MutableSortedDictionary.h"
#import "SortedDictionary/SortedDictionary/Public/SortedDictionaryEntry.h"

#import "ChildRotationNavigationController.h"
#import "FCColorPickerViewController.h"
#import "SettingsController.h"
#import "SMLocalizedStrings.h"
#import "SMLedStateConfigurationViewController.h"
#import "SMLedPatternCommandsViewController.h"
#import "STProgressView.h"


typedef void (^GetLEDControlValuesCompletionBlock)(NSError *error);


@interface SMLedControlViewController () <UITableViewDataSource, UITableViewDelegate, SMLedStateConfigurationViewControllerDelegate>
{
    NSMutableDictionary *_serverLEDConfig;
    NSMutableDictionary *_serverLEDStatesDict;
    MutableSortedDictionary *_sortedLEDStatesDict;
    
    NSDictionary *_defaultLEDStates;
    NSArray *_ledStates;
    
    STProgressView *_retrievingLEDConfigView;
}

@property (nonatomic, strong) IBOutlet UITableView *ledStatesTableView;

@end

@implementation SMLedControlViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = kSMLocalStringLedControlLabel;
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.ledStatesTableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.ledStatesTableView.backgroundView = nil;
    }
    
    [self createRetrievingLEDConfView];
    [self getLEDConfiguration];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self.ledStatesTableView reloadData];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Get and Set LED Configuration

- (void)getLEDConfiguration
{
    [self showRetrievingLEDConfView];
    
    [[SettingsController sharedInstance] getLEDConfigurationWithCompletionBlock:^(NSDictionary *ledConfigDict, NSError *error) {
        
        [self hideRetrievingLEDConfView];
        
        if (!error) {
            _serverLEDConfig = [[NSMutableDictionary alloc] initWithDictionary:ledConfigDict];
            _serverLEDStatesDict = [[NSMutableDictionary alloc] initWithDictionary:[ledConfigDict objectForKeyedSubscript:@"parameters"]];
            _sortedLEDStatesDict = [[MutableSortedDictionary alloc] initWithDictionary:_serverLEDStatesDict];
            
            [self compareLEDConfigurationWithDefaultsWithCompletionBlock:^(NSDictionary *ledConfigDict, NSError *error) {
                [self generateLEDStates];
                [self.ledStatesTableView reloadData];
            }];
            
        } else {
            spreed_me_log("Error getting LED configuration.");
        }
    }];
}


- (void)setLEDConfiguration:(NSDictionary *)ledConfDict
{
    [[SettingsController sharedInstance] setLEDConf:ledConfDict withCompletionBlock:^(NSDictionary *ledConfigDictSET, NSError *error) {
        if (!error) {
            _serverLEDConfig = [[NSMutableDictionary alloc] initWithDictionary:ledConfigDictSET];
            
            if ([ledConfigDictSET objectForKey:@"led"]) {
                _serverLEDConfig = [[NSMutableDictionary alloc] initWithDictionary:[ledConfigDictSET objectForKey:@"led"]];
            }
            
            _serverLEDStatesDict = [[NSMutableDictionary alloc] initWithDictionary:[_serverLEDConfig objectForKeyedSubscript:@"parameters"]];
            _sortedLEDStatesDict = [[MutableSortedDictionary alloc] initWithDictionary:_serverLEDStatesDict];
            
            [self generateLEDStates];
            
            NSDictionary *userInfo = @{LEDStatesUserInfoKey : _ledStates,
                                       LEDStatesUpdateSuccessUserInfoKey : @YES};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:LEDConfigurationHasBeenUpdatedNotification object:self userInfo:userInfo];
            });
            
            [self.ledStatesTableView reloadData];
        } else {
            NSDictionary *userInfo = @{LEDStatesUserInfoKey : _ledStates,
                                       LEDStatesUpdateSuccessUserInfoKey : @NO};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:LEDConfigurationHasBeenUpdatedNotification object:self userInfo:userInfo];
            });
            
            spreed_me_log("Error setting LED configuration.");
        }
    }];
}


- (void)compareLEDConfigurationWithDefaultsWithCompletionBlock:(GetLEDConfigCompletionBlock)block
{
    GetLEDConfigCompletionBlock complBlock = NULL;
    
    if (block) {
        complBlock = [block copy];
    }
    
    [[SettingsController sharedInstance] getLEDDefaultConfigurationWithCompletionBlock:^(NSDictionary *ledConfigDict, NSError *error) {
        if (!error) {
            NSMutableDictionary *defaultStatesDict = [[NSMutableDictionary alloc] initWithDictionary:[ledConfigDict objectForKeyedSubscript:@"parameters"]];
            NSMutableDictionary *receivedStatesDict = [[NSMutableDictionary alloc] initWithDictionary:_serverLEDStatesDict];
            NSMutableDictionary *resultLEDStateDict = [[NSMutableDictionary alloc] init];
            NSArray *defaultLedStatesKeys = [defaultStatesDict allKeys];
            
            for (NSString *stateId in defaultLedStatesKeys) {
                if ([receivedStatesDict objectForKey:stateId]) {
                    // If LED State exists in Defaults then keep the current state for that LED.
                    [resultLEDStateDict setObject:[receivedStatesDict objectForKey:stateId] forKey:stateId];
                } else {
                    // If LED State does NOT exists in Defaults then keep then grab default values for that LED.
                    [resultLEDStateDict setObject:[defaultStatesDict objectForKey:stateId] forKey:stateId];
                }
            }
            
            _defaultLEDStates = [[NSMutableDictionary alloc] initWithDictionary:defaultStatesDict];
            _serverLEDStatesDict = [[NSMutableDictionary alloc] initWithDictionary:resultLEDStateDict];
            _sortedLEDStatesDict = [[MutableSortedDictionary alloc] initWithDictionary:_serverLEDStatesDict];
            
            if (complBlock) {
                complBlock(nil, error);
            }
            
        } else {
            spreed_me_log("Error trying get defaults after getting LED configuration.");
            
            _defaultLEDStates = nil;
            
            if (complBlock) {
                complBlock(nil, error);
            }
        }
    }];
}


- (void)generateLEDStates
{
    NSMutableArray *ledStates = [[NSMutableArray alloc] init];
    
    NSArray *sortedLEDStatesIds = [_sortedLEDStatesDict allKeys];
    
    for (NSString *stateId in sortedLEDStatesIds) {
        SMLEDState *state = [SMLEDState ledStateFromStateId:stateId andCommands:[_serverLEDStatesDict objectForKey:stateId]];
        [ledStates addObject:state];
    }
    
    _ledStates = ledStates;
}


#pragma mark - SMLedStateConfigurationViewControllerDelegate Methods

- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToSaveLEDState:(SMLEDState *)ledState
{
    NSMutableArray *newStates = [[NSMutableArray alloc] initWithArray:_ledStates];
    
    for (int i = 0; i < [newStates count]; i++) {
        SMLEDState *state = [newStates objectAtIndex:i];
        if ([state.stateId isEqualToString:ledState.stateId]) {
            state = ledState;
            break;
        }
    }
    
    _ledStates = [[NSArray alloc] initWithArray:newStates];
    [_serverLEDStatesDict setObject:ledState.pattern.ledPatternStringArrayRepresentation forKey:ledState.stateId];

    NSMutableDictionary *ledConfDict = [[NSMutableDictionary alloc] initWithDictionary:_serverLEDConfig];
    [ledConfDict setValue:_serverLEDStatesDict forKey:@"parameters"];
    
    [self setLEDConfiguration:ledConfDict];
}


- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToPreviewLEDState:(SMLEDState *)ledState
{
    NSArray *patternCommands = [ledState.pattern ledPatternStringArrayRepresentation];
    NSNumber *time = [NSNumber numberWithInt:10];
    
    NSDictionary *json = @{@"duration" : time,
                           @"commands" : patternCommands};
    
    [[SettingsController sharedInstance] previewLEDStateConfiguration:json withCompletionBlock:^(NSDictionary *ledConfigDict, NSError *error) {
        if (!error) {
            NSDictionary *userInfo = @{LEDPreviewSuccessUserInfoKey : @YES};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:LEDPreviewSuccededNotification object:self userInfo:userInfo];
            });
        } else {
            spreed_me_log("Error trying to preview LED configuration.");
            NSString *alertTitle = NSLocalizedStringWithDefaultValue(@"message_title_preview-led-failed",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Preview failed",
                                                                     @"Preview failed");
            
            NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_preview-led-failed",
                                                                       nil, [NSBundle mainBundle],
                                                                       @"Preview LED configuration has failed",
                                                                       @"Preview LED configuration has failed");
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            
            NSDictionary *userInfo = @{LEDPreviewSuccessUserInfoKey : @NO};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:LEDPreviewSuccededNotification object:self userInfo:userInfo];
            });
        }
    }];
}


- (void)ledStateConfigurationViewController:(SMLedStateConfigurationViewController *)ledStateConfigurationVC wantToResetToDefaultLEDState:(SMLEDState *)ledState
{
    [[SettingsController sharedInstance] getLEDDefaultConfigurationWithCompletionBlock:^(NSDictionary *ledConfigDict, NSError *error) {
        if (!error) {
            NSMutableDictionary *defaultStatesDict = [[NSMutableDictionary alloc] initWithDictionary:[ledConfigDict objectForKeyedSubscript:@"parameters"]];
            NSMutableDictionary *newStatesDict = [[NSMutableDictionary alloc] initWithDictionary:_serverLEDStatesDict];
            NSArray *defaultLedStatesKeys = [defaultStatesDict allKeys];
            
            for (NSString *stateId in defaultLedStatesKeys) {
                if ([stateId isEqualToString:ledState.stateId]) {
                    [newStatesDict setObject:[defaultStatesDict objectForKey:stateId] forKey:stateId];
                    break;
                }
            }
            
            NSMutableDictionary *ledConfDict = [[NSMutableDictionary alloc] initWithDictionary:_serverLEDConfig];
            [ledConfDict setValue:newStatesDict forKey:@"parameters"];
            
            [self setLEDConfiguration:ledConfDict];
            
        } else {
            spreed_me_log("Error trying to reset LED configuration.");
            NSString *alertTitle = NSLocalizedStringWithDefaultValue(@"message_title_reset-led-failed",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Reset failed",
                                                                     @"Reset failed");
            
            NSString *alertMessage = NSLocalizedStringWithDefaultValue(@"message_body_reset-led-failed",
                                                                       nil, [NSBundle mainBundle],
                                                                       @"Reset LED to default configuration has failed",
                                                                       @"Reset LED to default configuration has failed");
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            
            NSDictionary *userInfo = @{LEDStatesUserInfoKey : _ledStates,
                                       LEDStatesUpdateSuccessUserInfoKey : @NO};
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:LEDConfigurationHasBeenUpdatedNotification object:self userInfo:userInfo];
            });
        }
    }];
}


#pragma mark - UIViewController Rotation

- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger supportedInterfaceOrientations = UIInterfaceOrientationMaskAll;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        supportedInterfaceOrientations = UIInterfaceOrientationMaskPortrait;
    }
    
    return supportedInterfaceOrientations;
}


#pragma mark - Loading views

// This method should be called only once on viewDidLoad
- (void)createRetrievingLEDConfView
{
    _retrievingLEDConfigView = [[STProgressView alloc] initWithWidth:240.0f
                                                      message:NSLocalizedStringWithDefaultValue(@"label_user-view_retrieving-led-conf",
                                                                                                nil, [NSBundle mainBundle],
                                                                                                @"Retrieving LED configuration",
                                                                                                @"Retrieving LED configuration")
                                                         font:nil
                                             cancelButtonText:nil
                                                     userInfo:nil];
    
    _retrievingLEDConfigView.frame = CGRectMake(40.0f, 92.0f,
                                                _retrievingLEDConfigView.frame.size.width,
                                                _retrievingLEDConfigView.frame.size.height);
    
    _retrievingLEDConfigView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:_retrievingLEDConfigView];
    
    
    _retrievingLEDConfigView.layer.cornerRadius = 5.0;
    _retrievingLEDConfigView.backgroundColor = [[UIColor alloc] initWithRed:0.0 green:0.0 blue:0.0 alpha:0.6];
    _retrievingLEDConfigView.hidden = YES;
}


- (void)showRetrievingLEDConfView
{
    _retrievingLEDConfigView.hidden = NO;
    [self.view bringSubviewToFront:_retrievingLEDConfigView];
}


- (void)hideRetrievingLEDConfView
{
    _retrievingLEDConfigView.hidden = YES;
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMLEDState *ledState = [_ledStates objectAtIndex:indexPath.row];
    SMLEDState *stateToModify = [ledState copy];

    SMLedStateConfigurationViewController *ledStateViewController = [[SMLedStateConfigurationViewController alloc] initWithLEDState:stateToModify withImportableLEDStates:_ledStates andDefaultLEDStates:_defaultLEDStates];
    ledStateViewController.delegate = self;
    [self.navigationController pushViewController:ledStateViewController animated:YES];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) {
        return kTableViewHeaderHeight + kTableViewFooterHeight;
    }
    
    return kTableViewHeaderHeight;
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return kTableViewFooterHeight;
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_ledStates count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMLEDState *ledState = [_ledStates objectAtIndex:indexPath.row];
    
    static NSString *ledStatesCellIdentifier = @"LedStatesCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ledStatesCellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:ledStatesCellIdentifier];
    }
    
    UIImageView *imageView= [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 28.0, 28.0)];
    imageView.layer.borderWidth = 0.5f;
    imageView.layer.borderColor = [kGrayColor_e5e5e5 CGColor];
    UIImage *colorImage = [self imageForLedState:ledState withSize:imageView.frame.size];
    [imageView setImage:colorImage];
    
    cell.accessoryView = imageView;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    }
    
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        cell.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    cell.textLabel.textColor = kSMBuddyCellTitleColor;
    
    cell.textLabel.text = ledState.stateName;
    
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return NSLocalizedStringWithDefaultValue(@"label_led-states",
                                             nil, [NSBundle mainBundle],
                                             @"States",
                                             @"States");
}


#pragma mark - Utils

- (UIImage *)imageForLedState:(SMLEDState *)ledState withSize:(CGSize)size
{
    CGRect imageDrawCanvas = CGRectMake(0.0f, 0.0f, size.width, size.height);
    NSArray *colorArray = [NSArray arrayWithArray:ledState.editableColorsArray];
    
    UIGraphicsBeginImageContext(imageDrawCanvas.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    switch ([colorArray count]) {
        case 0:
        {
            CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
            CGContextFillRect(context, imageDrawCanvas);
        }
            break;
        case 1:
        {
            SMEditableLEDColor *firstColor = colorArray[0];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:firstColor.color] CGColor]);
            CGContextFillRect(context, imageDrawCanvas);
        }
            break;
        case 2:
        {
            SMEditableLEDColor *firstColor = colorArray[0];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:firstColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(0, 0, imageDrawCanvas.size.width / 2 - 1, imageDrawCanvas.size.height));
            SMEditableLEDColor *secondColor = colorArray[1];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:secondColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(imageDrawCanvas.size.width / 2 + 1, 0, imageDrawCanvas.size.width, imageDrawCanvas.size.height));
        }
            break;
        case 3:
        {
            SMEditableLEDColor *firstColor = colorArray[0];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:firstColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(0, 0, imageDrawCanvas.size.width / 3 - 1, imageDrawCanvas.size.height));
            SMEditableLEDColor *secondColor = colorArray[1];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:secondColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake((imageDrawCanvas.size.width / 3 + 1), 0, imageDrawCanvas.size.width / 3 - 1, imageDrawCanvas.size.height));
            SMEditableLEDColor *thirdColor = colorArray[2];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:thirdColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake((imageDrawCanvas.size.width / 3 + 1) * 2, 0, imageDrawCanvas.size.width, imageDrawCanvas.size.height));
        }
            break;
        default:
        {
            // 4 or more.
            SMEditableLEDColor *firstColor = colorArray[0];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:firstColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(0, 0, imageDrawCanvas.size.width / 2 - 1, imageDrawCanvas.size.height / 2 - 1));
            SMEditableLEDColor *secondColor = colorArray[1];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:secondColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(imageDrawCanvas.size.width / 2 + 1, 0, imageDrawCanvas.size.width, imageDrawCanvas.size.height / 2 - 1));
            SMEditableLEDColor *thirdColor = colorArray[2];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:thirdColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(0, imageDrawCanvas.size.height / 2 + 1, imageDrawCanvas.size.width / 2 - 1, imageDrawCanvas.size.height / 2 - 1));
            SMEditableLEDColor *forthColor = colorArray[3];
            CGContextSetFillColorWithColor(context, [[self uicolorFromLedCommandColor:forthColor.color] CGColor]);
            CGContextFillRect(context, CGRectMake(imageDrawCanvas.size.width / 2 + 1, imageDrawCanvas.size.height / 2 + 1, imageDrawCanvas.size.width, imageDrawCanvas.size.height));
        }
            break;
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


- (UIColor *)uicolorFromLedCommandColor:(NSString *)commandColor
{
    unsigned colorInt = 0;
    NSString *hexColor = [NSString stringWithFormat:@"%@%@", @"0x", commandColor];
    [[NSScanner scannerWithString:hexColor] scanHexInt:&colorInt];
    return UIColorFromRGB(colorInt);
}


- (UIColor *)colorFromBoxToApp:(UIColor *)boxColor
{
    CGColorRef cgcolor = [boxColor CGColor];
    
    const CGFloat *components = CGColorGetComponents(cgcolor);
    CGFloat red = components[0];
    CGFloat green = components[1];
    CGFloat blue = components[2];
    CGFloat alpha = components[3];
    
    CGFloat hue = 0;
    CGFloat saturation = 0;
    CGFloat brightness = 0;
    
    CGFloat minRGB = MIN(red, MIN(green,blue));
    CGFloat maxRGB = MAX(red, MAX(green,blue));
    
    if (minRGB==maxRGB) {
        hue = 0;
        saturation = 0;
        brightness = minRGB;
    } else {
        CGFloat d = (red==minRGB) ? green-blue : ((blue==minRGB) ? red-green : blue-red);
        CGFloat h = (red==minRGB) ? 3 : ((blue==minRGB) ? 1 : 5);
        hue = (h - d/(maxRGB - minRGB)) / 6.0;
        saturation = (maxRGB - minRGB)/maxRGB;
        brightness = maxRGB;
    }
    
    CGFloat moduloResult = (float)((int)((hue * 360) - 0) % (int)360);
    CGFloat hueMod = (moduloResult < 0) ? moduloResult + 360 : moduloResult;
    hueMod = hueMod / 360;
    
    UIColor *colorMod = [UIColor colorWithHue:hueMod saturation:saturation brightness:brightness alpha:alpha];
    NSString *hexValueMod = [self hexadecimalValueFromUIColor:colorMod];
    
    return colorMod;
}


- (UIColor *)colorFromAppToBox:(UIColor *)appColor
{
    NSLog(@"UICOLOR: %@", appColor);
    NSLog(@"HEX-COLOR: %@", [self hexadecimalValueFromUIColor:appColor]);
    
    CGColorRef cgcolor = [appColor CGColor];
    
    const CGFloat *components = CGColorGetComponents(cgcolor);
    CGFloat red = components[0];
    CGFloat green = components[1];
    CGFloat blue = components[2];
    CGFloat alpha = components[3];
    
    CGFloat hue = 0;
    CGFloat saturation = 0;
    CGFloat brightness = 0;
    
    CGFloat minRGB = MIN(red, MIN(green,blue));
    CGFloat maxRGB = MAX(red, MAX(green,blue));
    
    if (minRGB==maxRGB) {
        hue = 0;
        saturation = 0;
        brightness = minRGB;
    } else {
        CGFloat d = (red==minRGB) ? green-blue : ((blue==minRGB) ? red-green : blue-red);
        CGFloat h = (red==minRGB) ? 3 : ((blue==minRGB) ? 1 : 5);
        hue = (h - d/(maxRGB - minRGB)) / 6.0;
        saturation = (maxRGB - minRGB)/maxRGB;
        brightness = maxRGB;
    }
    NSLog(@"HUE-COLOR: %0.4f, saturation: %0.2f, value: %0.2f", hue, saturation, brightness);
    CGFloat moduloResult = (float)((int)((hue * 360) + 0) % (int)360);
    CGFloat hueMod = (moduloResult < 0) ? moduloResult + 360 : moduloResult;
    hueMod = hueMod / 360;
    
    NSLog(@"HUE-COLOR360: %0.4f", hue * 360);
    NSLog(@"HUE-COLOR-MODULO: %0.4f", hueMod * 360);
    
    NSLog(@"HUE-COLOR-MOD: %0.4f, saturation: %0.2f, value: %0.2f", hueMod, saturation, brightness);
    
    UIColor *colorMod = [UIColor colorWithHue:hueMod saturation:saturation brightness:brightness alpha:alpha];
    NSString *hexValueMod = [self hexadecimalValueFromUIColor:colorMod];
    
    NSLog(@"HEX-COLOR-MOD: %@", hexValueMod);
    
    return colorMod;
}


-(NSString *)hexadecimalValueFromUIColor:(UIColor *)color
{
    CGFloat redFloatValue, greenFloatValue, blueFloatValue;
    int redIntValue, greenIntValue, blueIntValue;
    NSString *redHexValue, *greenHexValue, *blueHexValue;
    
    if(color)
    {
        // Get the red, green, and blue components of the color
        [color getRed:&redFloatValue green:&greenFloatValue blue:&blueFloatValue alpha:NULL];
        
        // Convert the components to numbers (unsigned decimal integer) between 0 and 255
        redIntValue=redFloatValue*255.0f;
        greenIntValue=greenFloatValue*255.0f;
        blueIntValue=blueFloatValue*255.0f;
        
        // Convert the numbers to hex strings
        redHexValue=[NSString stringWithFormat:@"%02x", redIntValue];
        greenHexValue=[NSString stringWithFormat:@"%02x", greenIntValue];
        blueHexValue=[NSString stringWithFormat:@"%02x", blueIntValue];
        
        // Concatenate the red, green, and blue components' hex strings together with a "#"
        return [NSString stringWithFormat:@"%@%@%@", redHexValue, greenHexValue, blueHexValue];
    }
    return nil;
}


@end
