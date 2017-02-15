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

#import "SMLedStateConfigurationViewController.h"

#import "ChildRotationNavigationController.h"
#import "FCColorPickerViewController.h"
#import "SMLocalizedStrings.h"
#import "SMLEDState.h"
#import "SMLedPatternCommandsViewController.h"
#import "STProgressView.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "STUserViewTableViewCell.h"
#import "TextFieldTableViewCell.h"
#import "UserImageTableViewCell.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


typedef enum : NSUInteger {
    kLEDStateTableViewSectionColors = 0,
    kLEDStateTableViewSectionEdit,
    kLEDStateTableViewSectionActions,
    kLEDStateTableViewSectionCount,
} LEDStateTableViewSections;


typedef enum : NSInteger {
    kActionsSectionPreview = 0,
    kActionsSectionReset,
} ActionsSectionRows;


@interface SMLedStateConfigurationViewController () <UIActionSheetDelegate, UINavigationControllerDelegate,
FCColorPickerViewControllerDelegate, UITextFieldDelegate , UITableViewDataSource, UITableViewDelegate, SMLedPatternCommandsViewControllerDelegate>
{
    NSInteger _editingColorIndex;
    SMLEDState *_originalLedState;
    SMLEDState *_ledState;
    UIBarButtonItem *_saveButton;
    NSArray *_importableLEDStates;
    NSDictionary *_defaultLEDStates;
    
    NSTimer *_previewTimer;
    UILabel *_previewCountDownLabel;
    int _previewSeconds;
    
    NSMutableArray *_datasource;
    STSectionModel *_colorsSection;
    STSectionModel *_editSection;
    STSectionModel *_actionsSection;
    
    //Edit section
    STRowModel *_editPatternRow;
    
    //Actions section
    STRowModel *_previewLedConfigRow;
    STRowModel *_resetLedConfigRow;
    
    STProgressView *_savingLEDGonfigurationView;
}

@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (nonatomic, assign) BOOL needSave;

@end

@implementation SMLedStateConfigurationViewController

- (id)initWithLEDState:(SMLEDState *)ledState withImportableLEDStates:(NSArray *)importableLEDStates andDefaultLEDStates:(NSDictionary *)defaultLEDStates
{
    self = [super initWithNibName:@"SMLedStateConfigurationViewController" bundle:nil];
    if (self) {
        _ledState = ledState;
        _originalLedState = [ledState copy];
        _importableLEDStates = importableLEDStates;
        _defaultLEDStates = defaultLEDStates;
        _datasource = [[NSMutableArray alloc] init];
        
        self.navigationItem.title = ledState.stateName;
        
        //Configuration Section
        _colorsSection = [STSectionModel new];
        _colorsSection.type = kLEDStateTableViewSectionColors;
        _colorsSection.title = NSLocalizedStringWithDefaultValue(@"label_colors",
                                                                 nil, [NSBundle mainBundle],
                                                                 @"Colors",
                                                                 @"Colors");
        _colorsSection.items = [[NSMutableArray alloc] initWithArray:_ledState.editableColorsArray];
        
        //Edit Section
        _editSection = [STSectionModel new];
        _editSection.type = kLEDStateTableViewSectionEdit;
        NSString *patternString =  kSMLocalStringPatternLabel;
        _editSection.title = [NSString stringWithFormat:@"%@ - %@", patternString, _ledState.pattern.patternName];
        
        _editPatternRow = [STRowModel new];
        _editPatternRow.type = kActionsSectionPreview;
        _editPatternRow.title = NSLocalizedStringWithDefaultValue(@"label_edit-pattern",
                                                                  nil, [NSBundle mainBundle],
                                                                  @"Edit pattern",
                                                                  @"Edit pattern");
        
        [_editSection.items addObject:_editPatternRow];
        
        //Actions section
        _actionsSection = [STSectionModel new];
        _actionsSection.type = kLEDStateTableViewSectionActions;
        _actionsSection.title = kSMLocalStringActionsLabel;
        
        _previewLedConfigRow = [STRowModel new];
        _previewLedConfigRow.type = kActionsSectionPreview;
        _previewLedConfigRow.title = kSMLocalStringLedPreviewLabel;
        _resetLedConfigRow = [STRowModel new];
        _resetLedConfigRow.type = kActionsSectionReset;
        _resetLedConfigRow.title = NSLocalizedStringWithDefaultValue(@"label_led-reset",
                                                                     nil, [NSBundle mainBundle],
                                                                     @"Reset to default",
                                                                     @"Reset to default");
        [_actionsSection.items addObject:_previewLedConfigRow];
        [_actionsSection.items addObject:_resetLedConfigRow];
        
        [_datasource addObject:_colorsSection];
        [_datasource addObject:_editSection];
        [_datasource addObject:_actionsSection];
        
        [self createSavingLEDConfView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ledConfigurationHasBeenUpdated:) name:LEDConfigurationHasBeenUpdatedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkIfLedPreviewHasSucceded:) name:LEDPreviewSuccededNotification object:nil];
}
    
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    self.view.backgroundColor = kGrayColor_e5e5e5;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        self.tableView.backgroundColor = kGrayColor_e5e5e5;
    } else {
        self.tableView.backgroundView = nil;
    }
    
    _previewCountDownLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 20, 40)];
    _previewCountDownLabel.textColor = kSMBuddyCellTitleColor;
    _previewCountDownLabel.backgroundColor = [UIColor clearColor];
    _previewCountDownLabel.hidden = YES;
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    _saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(saveChanges)];
    _saveButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = _saveButton;
}


- (void)viewWillDisappear:(BOOL)animated
{
    [self stopPreviewCountDown];
}


- (void)setNeedSave:(BOOL)needSave
{
    _needSave = needSave;
    
    if (needSave) {
        _saveButton.enabled = YES;
    } else {
        _saveButton.enabled = NO;
    }
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


#pragma mark - LED Configuration Notifications

- (void)ledConfigurationHasBeenUpdated:(NSNotification *)notification
{
    NSArray *updatedLEDStates = [notification.userInfo objectForKey:LEDStatesUserInfoKey];
    BOOL success = [notification.userInfo objectForKey:LEDStatesUpdateSuccessUserInfoKey];
    
    if (success) {
        [self checkUpdatedLedStates:updatedLEDStates];
    }
    
    [self hideSavingLEDConfView];
}


- (void)checkUpdatedLedStates:(NSArray *)updatedStates
{
    _importableLEDStates = updatedStates;
    
    for (SMLEDState *updatedState in updatedStates) {
        if ([_ledState.stateId isEqualToString:updatedState.stateId]) {
            _ledState = [updatedState copy];
        }
    }
    _originalLedState = [_ledState copy];
    _colorsSection.items = [[NSMutableArray alloc] initWithArray:_ledState.editableColorsArray];
    
    NSString *patternString =  kSMLocalStringPatternLabel;
    _editSection.title = [NSString stringWithFormat:@"%@ - %@", patternString, _ledState.pattern.patternName];
        
    [_tableView reloadData];
}


#pragma mark - Actions

- (void)changePatternColorAtIndex:(NSInteger)index
{
    FCColorPickerViewController *colorPicker = [FCColorPickerViewController colorPicker];
    SMEditableLEDColor *editableColor = [_ledState.editableColorsArray objectAtIndex:index];
    unsigned colorInt = 0;
    [[NSScanner scannerWithString:editableColor.color] scanHexInt:&colorInt];
    colorPicker.color = UIColorFromRGB(colorInt);
    colorPicker.delegate = self;
    colorPicker.backgroundColor = kGrayColor_e5e5e5;
    
    _editingColorIndex = index;
    
    ChildRotationNavigationController *colorPickerNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:colorPicker];
    [self.navigationController presentViewController:colorPickerNavController animated:YES completion:nil];
}


- (void)editPattern
{
    SMLEDState *state = [_ledState copy];
    SMLedPatternCommandsViewController *patternCommandsViewController = [[SMLedPatternCommandsViewController alloc] initWithLEDState:state withImportableLEDStates:_importableLEDStates andDefaultLEDStates:_defaultLEDStates];
    patternCommandsViewController.delegate = self;
    
//    [self.navigationController pushViewController:patternCommandsViewController animated:YES];
    
    ChildRotationNavigationController *colorPickerNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:patternCommandsViewController];
    [self.navigationController presentViewController:colorPickerNavController animated:YES completion:nil];
}


- (void)askForResettingToDefault
{
    [self showResetLEDStateAlert];
}


- (void)resetLEDStateToDefault
{
    [self showSavingLEDConfView];
    
    if (self.needSave) {
        self.needSave = NO;
    }
    
    [_delegate ledStateConfigurationViewController:self wantToResetToDefaultLEDState:_ledState];
}


- (void)previewLEDState
{
    [_delegate ledStateConfigurationViewController:self wantToPreviewLEDState:_ledState];
}


- (void)saveChanges
{
    [self showSavingLEDConfView];
    [_delegate ledStateConfigurationViewController:self wantToSaveLEDState:_ledState];
    self.needSave = NO;
}


#pragma mark - LED Preview Utils

- (void)checkIfLedPreviewHasSucceded:(NSNotification *)notification
{
    BOOL success = [notification.userInfo objectForKey:LEDPreviewSuccessUserInfoKey];
    
    if (success) {
        [self startPreviewCountDown];
    } else {
        [self stopPreviewCountDown];
    }
}


- (void)startPreviewCountDown
{
    [_previewTimer invalidate];
    
    _previewSeconds = 10;
    [_previewCountDownLabel setText:[NSString stringWithFormat:@"%d", _previewSeconds]];
    _previewCountDownLabel.hidden = NO;
    
    _previewTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerFired) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_previewTimer forMode:NSRunLoopCommonModes];
}


- (void)stopPreviewCountDown
{
    [_previewTimer invalidate];
    _previewCountDownLabel.hidden = YES;
}


-(void)timerFired
{
    if(_previewSeconds > 1) {
        _previewSeconds-=1;
        [_previewCountDownLabel setText:[NSString stringWithFormat:@"%d", _previewSeconds]];
    } else {
        [self stopPreviewCountDown];
    }
}


#pragma mark - SMLedPatternCommandsViewController Delegate

- (void)ledPatternCommandsViewController:(SMLedPatternCommandsViewController *)ledPatternCommandsVC haveChangedLEDStatePattern:(SMLEDState *)ledState
{
    _ledState.pattern = ledState.pattern;
    _colorsSection.items = [[NSMutableArray alloc] initWithArray:_ledState.editableColorsArray];
    
    if (self.needSave) {
        self.needSave = NO;
    }
    
    [self showSavingLEDConfView];
    
    [_delegate ledStateConfigurationViewController:self wantToSaveLEDState:_ledState];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)ledPatternCommandsViewControllerDidCancelChanges:(SMLedPatternCommandsViewController *)ledPatternCommandsVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


- (void)ledPatternCommandsViewController:(SMLedPatternCommandsViewController *)ledPatternCommandsVC wantToPreviewLEDStatePattern:(SMLEDState *)ledState
{
    [_delegate ledStateConfigurationViewController:self wantToPreviewLEDState:ledState];
}


#pragma mark - Loading views

// This method should be called only once on viewDidLoad
- (void)createSavingLEDConfView
{
    _savingLEDGonfigurationView = [[STProgressView alloc] initWithWidth:240.0f
                                                             message:NSLocalizedStringWithDefaultValue(@"label_user-view_saving-led-conf",
                                                                                                       nil, [NSBundle mainBundle],
                                                                                                       @"Saving LED configuration",
                                                                                                       @"Saving LED configuration")
                                                                font:nil
                                                    cancelButtonText:nil
                                                            userInfo:nil];
    
    _savingLEDGonfigurationView.frame = CGRectMake(40.0f, 92.0f,
                                                _savingLEDGonfigurationView.frame.size.width,
                                                _savingLEDGonfigurationView.frame.size.height);
    
    _savingLEDGonfigurationView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    [self.view addSubview:_savingLEDGonfigurationView];
    
    _savingLEDGonfigurationView.layer.cornerRadius = 5.0;
    _savingLEDGonfigurationView.backgroundColor = [[UIColor alloc] initWithRed:0.0 green:0.0 blue:0.0 alpha:0.6];
    _savingLEDGonfigurationView.hidden = YES;
}


- (void)showSavingLEDConfView
{
    _savingLEDGonfigurationView.hidden = NO;
    [self.view bringSubviewToFront:_savingLEDGonfigurationView];
}


- (void)hideSavingLEDConfView
{
    _savingLEDGonfigurationView.hidden = YES;
}


#pragma mark - Utils

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


- (BOOL)compareEditableColorArray:(NSArray *)array withArray:(NSArray *)array2
{
    BOOL equals = YES;
    
    if (array.count != array2.count) {
        equals = NO;
    } else {
        for (int i = 0; i < array.count; i++) {
            SMEditableLEDColor *color1 = [array objectAtIndex:i];
            SMEditableLEDColor *color2 = [array2 objectAtIndex:i];
            if (![color1.color isEqualToString:color2.color]) {
                equals = NO;
                break;
            }
        }
    }
    
    return equals;
}


#pragma mark - FCColorPickerViewControllerDelegate Methods

-(void)colorPickerViewController:(FCColorPickerViewController *)colorPicker didSelectColor:(UIColor *)color
{
    //    UIColor *colorToBox = [self colorFromAppToBox:color];
    NSString *newColorHexValue = [[self hexadecimalValueFromUIColor:color] uppercaseString];
    
    if (_editingColorIndex >= 0) {
        NSMutableArray *newColorArray = [[NSMutableArray alloc] initWithArray:_ledState.editableColorsArray];
        SMEditableLEDColor *editableColor = [newColorArray objectAtIndex:_editingColorIndex];
        editableColor.color = newColorHexValue;
        [newColorArray replaceObjectAtIndex:_editingColorIndex withObject:editableColor];
        
        [_ledState.pattern setColorsToPatternFromEditableColors:newColorArray];
        
        _editingColorIndex = -1;
    }
    _colorsSection.items = [[NSMutableArray alloc] initWithArray:_ledState.editableColorsArray];
    
    if ([self compareEditableColorArray:_originalLedState.editableColorsArray withArray:_ledState.editableColorsArray]) {
        self.needSave = NO;
    } else {
        self.needSave = YES;
    }
    
    [self dismissViewControllerAnimated:YES completion:^{
        [_tableView reloadSections:[NSIndexSet indexSetWithIndex:[_datasource indexOfObject:_colorsSection]] withRowAnimation:UITableViewRowAnimationNone];
    }];
}

-(void)colorPickerViewControllerDidCancel:(FCColorPickerViewController *)colorPicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UIAlertView Delegate

- (void)showResetLEDStateAlert
{
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:_resetLedConfigRow.title
                                                          message:NSLocalizedStringWithDefaultValue(@"message_body_confirm-reset-led",
                                                                                                    nil, [NSBundle mainBundle],
                                                                                                    @"Do you really want to reset this LED state to default configuration?",
                                                                                                    @"Do you really want to reset this LED state to default configuration?")
                                                         delegate:self
                                                cancelButtonTitle:kSMLocalStringCancelButton
                                                otherButtonTitles:kSMLocalStringOKButton, nil];
    
    myAlertView.delegate = self;
    [myAlertView show];
}


- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1)
    {
        [self resetLEDStateToDefault];
    }
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kLEDStateTableViewSectionColors:
        {
            [self changePatternColorAtIndex:indexPath.row];
            
        }
            break;
            
        case kLEDStateTableViewSectionEdit:
        {
            [self editPattern];
            
        }
            break;
            
        case kLEDStateTableViewSectionActions:
        {
            switch (rowModel.type) {
                case kActionsSectionPreview:
                    [self previewLEDState];
                    break;
                    
                case kActionsSectionReset:
                    [self askForResettingToDefault];
                    break;

                default:
                    break;
            }
        }
            break;
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    if (sectionModel.type == kLEDStateTableViewSectionColors) {
        return [UserImageTableViewCell cellHeight];
    } else {
        return [STUserViewTableViewCell cellHeight];
    }
    
    return rowModel.rowHeight;
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kLEDStateTableViewSectionCount;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    
    STSectionModel *sectionModel = _datasource[section];
    
    numberOfRows = sectionModel.items.count;
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    static NSString *patternColorCellIdentifier = @"PatternColorCellIdentifier";
    static NSString *editPatternCellIdentifier = @"EditPatternCellIdentifier";
    static NSString *previewButtonCellIdentifier = @"PreviewButtonCellIdentifier";
    static NSString *resetButtonCellIdentifier = @"ResetButtonCellIdentifier";
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kLEDStateTableViewSectionColors:
        {
            cell = [tableView dequeueReusableCellWithIdentifier:patternColorCellIdentifier];
            if (!cell) {
                cell = [[UserImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:patternColorCellIdentifier];
            }
            
            NSString *colorString = kSMLocalStringColorLabel;
            SMEditableLEDColor *editableColor = [_ledState.editableColorsArray objectAtIndex:indexPath.row];
            NSString *hexColor = [NSString stringWithFormat:@"0x%@", editableColor.color];
            unsigned colorInt = 0;
            [[NSScanner scannerWithString:hexColor] scanHexInt:&colorInt];
            
            CGRect rect = CGRectMake(0, 0, 20, 20);
            UIGraphicsBeginImageContext(rect.size);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [UIColorFromRGB(colorInt) CGColor]);
            CGContextFillRect(context, rect);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            cell.imageView.image = image;
            cell.imageView.layer.cornerRadius = kViewCornerRadius;
            cell.imageView.clipsToBounds = YES;
            cell.imageView.layer.borderWidth = 0.5f;
            cell.imageView.layer.borderColor = [[UIColor grayColor] CGColor];
            
            cell.textLabel.text = colorString;
            if (_colorsSection.items.count > 1) {
                cell.textLabel.text = [NSString stringWithFormat:@"%@ #%ld", colorString, (long)indexPath.row + 1];
            }
        }
            break;
            
        case kLEDStateTableViewSectionEdit:
        {
            STUserViewTableViewCell *ucell = [tableView dequeueReusableCellWithIdentifier:editPatternCellIdentifier];
            if (!ucell) {
                ucell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:editPatternCellIdentifier];
            }
            
            [ucell setupWithTitle:rowModel.title subtitle:nil
                        iconText:[NSString fontAwesomeIconStringForEnum:FAPencilSquareO]
                   iconTextColor:kSMBlueButtonColor];
            
            cell = ucell;
        }
            break;
            
        case kLEDStateTableViewSectionActions:
        {
            switch (rowModel.type) {
                case kActionsSectionPreview:
                {
                    STUserViewTableViewCell *ucell = [tableView dequeueReusableCellWithIdentifier:previewButtonCellIdentifier];
                    if (!ucell) {
                        ucell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:previewButtonCellIdentifier];
                    }
                    
                    [ucell setupWithTitle:rowModel.title subtitle:nil
                                 iconText:[NSString fontAwesomeIconStringForEnum:FAFilm]
                            iconTextColor:kSMBlueButtonColor];
                    
                    ucell.accessoryView = _previewCountDownLabel;
                    
                    cell = ucell;
                }
                    break;
                    
                case kActionsSectionReset:
                {
                    STUserViewTableViewCell *ucell = [tableView dequeueReusableCellWithIdentifier:resetButtonCellIdentifier];
                    if (!ucell) {
                        ucell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:previewButtonCellIdentifier];
                    }
                    
                    [ucell setupWithTitle:rowModel.title subtitle:nil
                                 iconText:[NSString fontAwesomeIconStringForEnum:FARetweet]
                            iconTextColor:kSMRedButtonColor];
                    
                    cell = ucell;
                }
                    break;
            }
        }
            break;
            
        default:
            break;
    }
    
    cell.textLabel.textColor = kSMBuddyCellTitleColor;
    
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    STSectionModel *sectionModel = _datasource[section];
    NSString *title = sectionModel.title;
    return title;
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


@end
