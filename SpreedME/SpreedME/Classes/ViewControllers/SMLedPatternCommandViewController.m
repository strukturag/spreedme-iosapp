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

#import "SMLedPatternCommandViewController.h"

#import "ChildRotationNavigationController.h"
#import "FCColorPickerViewController.h"
#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "TextFieldTableViewCell.h"
#import "UserImageTableViewCell.h"


typedef enum : NSUInteger {
    kCommandTableViewSectionConfiguration = 0,
    kCommandTableViewSectionCount,
} CommandTableViewSections;

typedef enum : NSInteger {
    kConfigurationSectionRowsColor = 0,
    kConfigurationSectionRowsHoldTime,
    kConfigurationSectionRowsFadeTime,
} ConfigurationSectionRows;


@interface SMLedPatternCommandViewController () <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, FCColorPickerViewControllerDelegate>
{
    SMLEDPatternCommand *_patternCommand;
    NSInteger _index;
    
    NSMutableArray *_datasource;
    STSectionModel *_configurationSection;
    
    //Configuration section
    STRowModel *_colorRow;
    STRowModel *_holdTimeRow;
    STRowModel *_fadeTimeRow;
}

@property (nonatomic, strong) IBOutlet UITableView *tableView;

@property (nonatomic, strong) UITextField *holdTimeTextField;
@property (nonatomic, strong) UITextField *fadeTimeTextField;

@end

@implementation SMLedPatternCommandViewController

- (id)initWithPatternCommand:(SMLEDPatternCommand *)command atIndex:(NSInteger)index
{
    self = [super initWithNibName:@"SMLedPatternCommandViewController" bundle:nil];
    if (self) {
        _patternCommand = command;
        _index = index;
        _datasource = [[NSMutableArray alloc] init];
        
        //Configuration Section
        _configurationSection = [STSectionModel new];
        _configurationSection.type = kCommandTableViewSectionConfiguration;
        
        _colorRow = [STRowModel new];
        _colorRow.type = kConfigurationSectionRowsColor;
        _colorRow.title = kSMLocalStringColorLabel;
        _colorRow.rowHeight = [UserImageTableViewCell cellHeight];
        
        _holdTimeRow = [STRowModel new];
        _holdTimeRow.type = kConfigurationSectionRowsHoldTime;
        _holdTimeRow.rowHeight = [TextFieldTableViewCell cellHeight];
        NSString *holdString = NSLocalizedStringWithDefaultValue(@"label_hold-time",
                                                                 nil, [NSBundle mainBundle],
                                                                 @"Hold",
                                                                 @"Hold");
        _holdTimeRow.title = [NSString stringWithFormat:@"%@ (ms)", holdString];
        
        _fadeTimeRow = [STRowModel new];
        _fadeTimeRow.type = kConfigurationSectionRowsFadeTime;
        _fadeTimeRow.rowHeight = [TextFieldTableViewCell cellHeight];
        NSString *fadeString = NSLocalizedStringWithDefaultValue(@"label_fade-time",
                                                                 nil, [NSBundle mainBundle],
                                                                 @"Fade",
                                                                 @"Fade");
        _fadeTimeRow.title = [NSString stringWithFormat:@"%@ (ms)", fadeString];
        
        [_configurationSection.items addObject:_colorRow];
        [_configurationSection.items addObject:_holdTimeRow];
        [_configurationSection.items addObject:_fadeTimeRow];
        
        [_datasource addObject:_configurationSection];
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
}


- (void)viewDidAppear:(BOOL)animated
{
    [self.tableView reloadData];
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


#pragma mark - Actions

- (void)changePatternCommandColor
{
    FCColorPickerViewController *colorPicker = [FCColorPickerViewController colorPicker];
    unsigned colorInt = 0;
    [[NSScanner scannerWithString:_patternCommand.color] scanHexInt:&colorInt];
    colorPicker.color = UIColorFromRGB(colorInt);
    colorPicker.delegate = self;
    colorPicker.backgroundColor = kGrayColor_e5e5e5;
        
    ChildRotationNavigationController *colorPickerNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:colorPicker];
    [self.navigationController presentViewController:colorPickerNavController animated:YES completion:nil];
}


#pragma mark - Utils

-(void)dismissKeyboard
{
    [self.holdTimeTextField resignFirstResponder];
    [self.fadeTimeTextField resignFirstResponder];
    
    _patternCommand.holdTime = _holdTimeTextField.text;
    _patternCommand.fadeTime = _fadeTimeTextField.text;
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


#pragma mark - FCColorPickerViewControllerDelegate Methods

-(void)colorPickerViewController:(FCColorPickerViewController *)colorPicker didSelectColor:(UIColor *)color
{
    _patternCommand.color = [[self hexadecimalValueFromUIColor:color] uppercaseString];
    
    [_delegate ledPatternCommandViewController:self haveChangedPatternCommand:_patternCommand atIndex:_index];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)colorPickerViewControllerDidCancel:(FCColorPickerViewController *)colorPicker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITextField delegate

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField.text.length == 0) {
        textField.text = @"0";
    }
    
    _patternCommand.holdTime = _holdTimeTextField.text;
    _patternCommand.fadeTime = _fadeTimeTextField.text;
    
    [_delegate ledPatternCommandViewController:self haveChangedPatternCommand:_patternCommand atIndex:_index];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    _patternCommand.holdTime = _holdTimeTextField.text;
    _patternCommand.fadeTime = _fadeTimeTextField.text;
    
    [_delegate ledPatternCommandViewController:self haveChangedPatternCommand:_patternCommand atIndex:_index];
    
    return YES;
}


- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *alreadyModifiedText = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    NSCharacterSet* nonNumber = [[NSCharacterSet
                                  characterSetWithCharactersInString: @"0123456789"]
                                 invertedSet];
    NSRange nonNumberRange = [alreadyModifiedText rangeOfCharacterFromSet: nonNumber];
    BOOL isNumber = (nonNumberRange.location == NSNotFound);
    
    if ((!isNumber || alreadyModifiedText.integerValue > 5000)) {
        return NO;
    }
    
    return YES;
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kCommandTableViewSectionConfiguration:
        {
            switch (rowModel.type) {
                case kConfigurationSectionRowsColor:
                    [self changePatternCommandColor];
                    break;
                    
                case kConfigurationSectionRowsHoldTime:
                    break;
                    
                case kConfigurationSectionRowsFadeTime:
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
    
    return rowModel.rowHeight;
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self dismissKeyboard];
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kCommandTableViewSectionCount;
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
    
    static NSString *patternCommandColorCellIdentifier = @"PatternCommandColorCellIdentifier";
    static NSString *patternCommandHoldCellIdentifier = @"PatternCommandHoldCellIdentifier";
    static NSString *patternCommandFadeCellIdentifier = @"PatternCommandFadeCellIdentifier";
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kCommandTableViewSectionConfiguration:
        {
            switch (rowModel.type) {
                case kConfigurationSectionRowsColor:
                {
                    cell = [tableView dequeueReusableCellWithIdentifier:patternCommandColorCellIdentifier];
                    if (!cell) {
                        cell = [[UserImageTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:patternCommandColorCellIdentifier];
                    }
                    
                    NSString *hexColor = [NSString stringWithFormat:@"0x%@", _patternCommand.color];
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
                    
                    cell.textLabel.text = kSMLocalStringColorLabel;
                }
                    break;
                    
                case kConfigurationSectionRowsHoldTime:
                {
                    TextFieldTableViewCell *textFieldCell = (TextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:patternCommandHoldCellIdentifier];
                    if (!textFieldCell) {
                        textFieldCell = [[TextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:patternCommandHoldCellIdentifier];
                    }
                    
                    textFieldCell.textLabel.text = rowModel.title;
                    textFieldCell.textField.text = _patternCommand.holdTime;
                    textFieldCell.textField.backgroundColor = [UIColor whiteColor];
                    textFieldCell.textField.delegate = self;
                    textFieldCell.textField.keyboardType = UIKeyboardTypeNumberPad;
                    self.holdTimeTextField = textFieldCell.textField;
                    
                    cell = textFieldCell;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                }
                    break;
                    
                case kConfigurationSectionRowsFadeTime:
                {
                    TextFieldTableViewCell *textFieldCell = (TextFieldTableViewCell *)[tableView dequeueReusableCellWithIdentifier:patternCommandFadeCellIdentifier];
                    if (!textFieldCell) {
                        textFieldCell = [[TextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:patternCommandFadeCellIdentifier];
                    }
                    
                    textFieldCell.textLabel.text = rowModel.title;
                    textFieldCell.textField.text = _patternCommand.fadeTime;
                    textFieldCell.textField.backgroundColor = [UIColor whiteColor];
                    textFieldCell.textField.delegate = self;
                    textFieldCell.textField.keyboardType = UIKeyboardTypeNumberPad;
                    self.fadeTimeTextField = textFieldCell.textField;
                    
                    cell = textFieldCell;
                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                }
                    break;
                    
                default:
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
