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

#import "SMLedImportPatternListViewController.h"
#import "SMLEDState.h"
#import "SMLocalizedStrings.h"

@interface SMLedImportPatternListViewController ()
{
    NSArray *_ledStates;
}

@property (nonatomic, strong) IBOutlet UITableView *ledStatesTableView;

@end

@implementation SMLedImportPatternListViewController

- (id)initWithLEDStates:(NSArray *)ledStates
{
    self = [super initWithNibName:@"SMLedImportPatternListViewController" bundle:nil];
    if (self) {
        _ledStates = ledStates;
        
        self.title = kSMLocalStringImportPatternLabel;
        
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
        self.navigationItem.rightBarButtonItem = cancelButton;
    }
    
    return self;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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


#pragma mark - Utils

- (void)cancel
{
    [_delegate ledImportPatternListViewControllerDidCancelImport:self];
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SMLEDState *ledState = [_ledStates objectAtIndex:indexPath.row];
    SMLEDPattern *pattern = [ledState.pattern copy];
    
    [_delegate ledImportPatternListViewController:self haveSelectedPatternToImport:pattern];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark - UITableView Datasource

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


#pragma mark - Utils

- (UIImage *)imageForLedState:(SMLEDState *)ledState withSize:(CGSize)size
{
    CGRect imageDrawCanvas = CGRectMake(0.0f, 0.0f, size.width, size.height);
    NSArray *colorArray = [NSArray arrayWithArray:ledState.editableColorsArray];
    
    UIGraphicsBeginImageContext(imageDrawCanvas.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    switch ([colorArray count]) {
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


@end
