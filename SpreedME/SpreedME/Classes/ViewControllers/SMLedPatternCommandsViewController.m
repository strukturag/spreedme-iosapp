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

#import "SMLedPatternCommandsViewController.h"

#import "ChildRotationNavigationController.h"
#import "LEDCommandTableViewCell.h"
#import "SMLedImportPatternListViewController.h"
#import "SMLedPatternCommandViewController.h"
#import "SMLocalizedStrings.h"
#import "STSectionModel.h"
#import "STRowModel.h"
#import "STUserViewTableViewCell.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


typedef enum : NSUInteger {
    kLEDStatePatternTableViewSectionCommands = 0,
    kLEDStatePatternTableViewSectionActions,
    kLEDStatePatternTableViewSectionCount,
} LEDStatePatternTableViewSections;

typedef enum : NSUInteger {
    kLEDPatternActionsSectionRowPreview = 0,
    kLEDPatternActionsSectionRowImport,
} LEDPatternActionsSectionRows;


NSString * const LEDPreviewSuccededNotification                 = @"LEDPreviewSuccededNotification";
NSString * const LEDPreviewSuccessUserInfoKey                   = @"LEDPreviewSuccessUserInfoKey";
NSString * const LEDConfigurationHasBeenUpdatedNotification     = @"LEDConfigurationHasBeenUpdatedNotification";
NSString * const LEDStatesUserInfoKey                           = @"LEDStatesUserInfoKey";
NSString * const LEDStatesUpdateSuccessUserInfoKey              = @"LEDStatesUpdateSuccessUserInfoKey";


@interface SMLedPatternCommandsViewController () <UITableViewDataSource, UITableViewDelegate, SMLedPatternCommandViewControllerDelegate, SMLedImportPatternListViewControllerrDelegate>
{
    SMLEDState *_ledState;
    NSMutableArray *_commands;
    NSArray *_importableLEDStates;
    NSDictionary *_defaultLEDStates;
    
    NSTimer *_previewTimer;
    UILabel *_previewCountDownLabel;
    int _previewSeconds;
    
    NSMutableArray *_datasource;
    STSectionModel *_commandsSection;
    STSectionModel *_actionsSection;
    
    //Actions section
    STRowModel *_previewPatternRow;
    STRowModel *_importPatternRow;
    
    UIBarButtonItem *_doneBarButtonItem;
    UIBarButtonItem *_editBarButtonItem;
    UIBarButtonItem *_addBarButtonItem;
    UIBarButtonItem *_saveBarButtonItem;
    UIBarButtonItem *_cancelBarButtonItem;
    UIBarButtonItem *_space;
}

@property (nonatomic, strong) IBOutlet UITableView *tableView;

@end

@implementation SMLedPatternCommandsViewController

- (id)initWithLEDState:(SMLEDState *)ledState withImportableLEDStates:(NSArray *)importableLEDStates andDefaultLEDStates:(NSDictionary *)defaultLEDStates
{
    self = [super initWithNibName:@"SMLedPatternCommandsViewController" bundle:nil];
    if (self) {
        _ledState = ledState;
        _importableLEDStates = importableLEDStates;
        _defaultLEDStates = defaultLEDStates;
        _commands = [[NSMutableArray alloc] initWithArray:_ledState.pattern.commands];
        _datasource = [[NSMutableArray alloc] init];
                
        //Configuration Section
        _commandsSection = [STSectionModel new];
        _commandsSection.title = kSMLocalStringPatternLabel;
        _commandsSection.type = kLEDStatePatternTableViewSectionCommands;
        
        _commandsSection.items = [[NSMutableArray alloc] initWithArray:_commands];
        
        //Actions section
        _actionsSection = [STSectionModel new];
        _actionsSection.title = kSMLocalStringActionsLabel;
        _actionsSection.type = kLEDStatePatternTableViewSectionActions;
        
        _previewPatternRow = [STRowModel new];
        _previewPatternRow.type = kLEDPatternActionsSectionRowPreview;
        _previewPatternRow.title = kSMLocalStringLedPreviewLabel;
        
        _importPatternRow = [STRowModel new];
        _importPatternRow.type = kLEDPatternActionsSectionRowImport;
        _importPatternRow.title = kSMLocalStringImportPatternLabel;
        [_actionsSection.items addObject:_previewPatternRow];
        [_actionsSection.items addObject:_importPatternRow];
        
        [_datasource addObject:_commandsSection];
        [_datasource addObject:_actionsSection];
        
        _doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneBarButtonPressed)];
        _editBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editTableButtonPressed)];
        _addBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewCommand)];
        _saveBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(savePattern)];
        _cancelBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
        _space = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
        _space.width = 20;
        
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:_saveBarButtonItem, _space, _editBarButtonItem, _space, _addBarButtonItem, nil]];
        [self.navigationItem setLeftBarButtonItems:[NSArray arrayWithObjects:_cancelBarButtonItem, nil]];
        
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
    
    [self checkAvailabilityOfAddCommand];
}


- (void)viewDidAppear:(BOOL)animated
{
    [self.tableView reloadData];
}


- (void)viewWillDisappear:(BOOL)animated
{
    [self stopPreviewCountDown];
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

- (void)editTableButtonPressed
{
    if(!self.editing) {
        [super setEditing:YES animated:YES];
        [self.tableView setEditing:YES animated:YES];
        [self.tableView reloadData];
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:_saveBarButtonItem, _space, _doneBarButtonItem, _space, _addBarButtonItem, nil]];
    }
}


- (void)doneBarButtonPressed
{
    if(self.editing) {
        [super setEditing:NO animated:NO];
        [self.tableView setEditing:NO animated:NO];
        [self.tableView reloadData];
        [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:_saveBarButtonItem, _space, _editBarButtonItem, _space, _addBarButtonItem, nil]];
    }
}


- (void)addNewCommand
{
    SMLEDPatternCommand *newCommand = [SMLEDPatternCommand ledPatternCommandFromCommandString:@"add 000000 400 400"];
    [_commands addObject:newCommand];
    _commandsSection.items = _commands;
    
    [self checkAvailabilityOfAddCommand];
    
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:[_datasource indexOfObject:_commandsSection]] withRowAnimation:UITableViewRowAnimationNone];
}


- (void)savePattern
{
    _ledState.pattern.commands = [[NSArray alloc] initWithArray:_commands];
    [_delegate ledPatternCommandsViewController:self haveChangedLEDStatePattern:_ledState];
}


- (void)previewPattern
{
    _ledState.pattern.commands = [[NSArray alloc] initWithArray:_commands];
    [_delegate ledPatternCommandsViewController:self wantToPreviewLEDStatePattern:_ledState];
}


- (void)importPattern
{
    SMLedImportPatternListViewController *importVC = [[SMLedImportPatternListViewController alloc] initWithLEDStates:_importableLEDStates];
    importVC.delegate = self;
    
    ChildRotationNavigationController *importPatternNavController = [[ChildRotationNavigationController alloc] initWithRootViewController:importVC];
    [self.navigationController presentViewController:importPatternNavController animated:YES completion:nil];
}


- (void)cancel
{
    [_delegate ledPatternCommandsViewControllerDidCancelChanges:self];
}


#pragma mark - Utils

- (void)checkAvailabilityOfAddCommand
{
    if ([_commandsSection.items count] < 20) {
        _addBarButtonItem.enabled = YES;
    } else {
        _addBarButtonItem.enabled = NO;
    }
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


#pragma mark - SMLedPatternCommandViewController Delegate

- (void)ledPatternCommandViewController:(SMLedPatternCommandViewController *)ledPatternCommandVC haveChangedPatternCommand:(SMLEDPatternCommand *)command atIndex:(NSInteger)index
{
    [_commands replaceObjectAtIndex:index withObject:command];
    
    [self.tableView reloadData];
}


#pragma mark - SMLedImportPatternListViewController Delegate

- (void)ledImportPatternListViewController:(SMLedImportPatternListViewController *)ledImportPatternVC haveSelectedPatternToImport:(SMLEDPattern *)pattern
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSMutableArray *newCommands = [[NSMutableArray alloc] initWithArray:pattern.commands];
    _commands = newCommands;
    _commandsSection.items = _commands;
    
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:[_datasource indexOfObject:_commandsSection]] withRowAnimation:UITableViewRowAnimationNone];
}


- (void)ledImportPatternListViewControllerDidCancelImport:(SMLedImportPatternListViewController *)ledImportPatternVC
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kLEDStatePatternTableViewSectionCommands:
        {
            SMLedPatternCommandViewController *patternCommandViewController = [[SMLedPatternCommandViewController alloc] initWithPatternCommand:[_commands objectAtIndex:indexPath.row] atIndex:indexPath.row];
            patternCommandViewController.delegate = self;
            [self.navigationController pushViewController:patternCommandViewController animated:YES];
        }
            break;
            
        case kLEDStatePatternTableViewSectionActions:
        {
            switch (rowModel.type) {
                case kLEDPatternActionsSectionRowPreview:
                {
                    [self previewPattern];
                }
                    break;
                    
                case kLEDPatternActionsSectionRowImport:
                {
                    [self importPattern];
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
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    if (sectionModel.type == kLEDStatePatternTableViewSectionCommands) {
        return [LEDCommandTableViewCell cellHeight];
    } else if (sectionModel.type == kLEDStatePatternTableViewSectionActions) {
        return [STUserViewTableViewCell cellHeight];
    }
    
    return rowModel.rowHeight;
}


#pragma mark - UITableView Datasource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return kLEDStatePatternTableViewSectionCount;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    STSectionModel *sectionModel = _datasource[section];
    NSInteger numberOfRows = sectionModel.items.count;
    
    return numberOfRows;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    static NSString *patternCommandCellIdentifier = @"PatternCommandCellIdentifier";
    static NSString *previewPatternCellIdentifier = @"PreviewPatternCellIdentifier";
    static NSString *importPatternCellIdentifier = @"ImportPatternCellIdentifier";
    
    STSectionModel *sectionModel = _datasource[indexPath.section];
    STRowModel *rowModel = sectionModel.items[indexPath.row];
    
    switch (sectionModel.type) {
        case kLEDStatePatternTableViewSectionCommands:
        {
            LEDCommandTableViewCell *pcell = [tableView dequeueReusableCellWithIdentifier:patternCommandCellIdentifier];
            if (!pcell) {
                pcell = [[LEDCommandTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:patternCommandCellIdentifier];
            }
            
            SMLEDPatternCommand *command = [_commands objectAtIndex:indexPath.row];
            
            NSString *hexColor = [NSString stringWithFormat:@"0x%@", command.color];
            unsigned colorInt = 0;
            [[NSScanner scannerWithString:hexColor] scanHexInt:&colorInt];
            
            CGRect rect = CGRectMake(0, 0, 20, 20);
            UIGraphicsBeginImageContext(rect.size);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, [UIColorFromRGB(colorInt) CGColor]);
            CGContextFillRect(context, rect);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            pcell.imageView.image = image;
            pcell.imageView.layer.cornerRadius = kViewCornerRadius;
            pcell.imageView.clipsToBounds = YES;
            pcell.imageView.layer.borderWidth = 0.5f;
            pcell.imageView.layer.borderColor = [[UIColor grayColor] CGColor];
            
            pcell.holdTimeLabel.text = [NSString stringWithFormat:@"%@ (ms)", command.holdTime];
            pcell.fadeTimeLabel.text = [NSString stringWithFormat:@"%@ (ms)", command.fadeTime];
            pcell.holdTimeLabel.textColor = kSMBuddyCellTitleColor;
            pcell.fadeTimeLabel.textColor = kSMBuddyCellTitleColor;
            
            pcell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell = pcell;
        }
            break;
            
        case kLEDStatePatternTableViewSectionActions:
        {
            switch (rowModel.type) {
                case kLEDPatternActionsSectionRowPreview:
                {
                    STUserViewTableViewCell *ucell = [tableView dequeueReusableCellWithIdentifier:previewPatternCellIdentifier];
                    if (!ucell) {
                        ucell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:previewPatternCellIdentifier];
                    }
                    
                    [ucell setupWithTitle:rowModel.title subtitle:nil
                                 iconText:[NSString fontAwesomeIconStringForEnum:FAFilm]
                            iconTextColor:kSMBlueButtonColor];
                    
                    ucell.accessoryView = _previewCountDownLabel;
                    
                    cell = ucell;
                }
                    break;
                    
                case kLEDPatternActionsSectionRowImport:
                {
                    STUserViewTableViewCell *ucell = [tableView dequeueReusableCellWithIdentifier:importPatternCellIdentifier];
                    if (!ucell) {
                        ucell = [[STUserViewTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:importPatternCellIdentifier];
                    }
                    
                    [ucell setupWithTitle:rowModel.title subtitle:nil
                                 iconText:[NSString fontAwesomeIconStringForEnum:FAReply]
                            iconTextColor:kSMBlueButtonColor];
                    
                    cell = ucell;
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


#pragma mark - UITableView Edit

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // We assume that if there are no defaults is because the Default Endpoint does not exist in that Spreedbox.
    // So user should not be able to remove all LED commands.
    if (!_defaultLEDStates && indexPath.row == 0) {
        return UITableViewCellEditingStyleNone;
    }
    
    return UITableViewCellEditingStyleDelete;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_commands removeObjectAtIndex:indexPath.row];
        _commandsSection.items = _commands;
        [self.tableView reloadData];
    }
    
    [self checkAvailabilityOfAddCommand];
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    SMLEDPatternCommand *command = [_commands objectAtIndex:sourceIndexPath.row];
    [_commands removeObjectAtIndex:sourceIndexPath.row];
    [_commands insertObject:command atIndex:destinationIndexPath.row];
    _commandsSection.items = _commands;
    [self.tableView reloadData];
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kLEDStatePatternTableViewSectionCommands) {
        return YES;
    }
    
    return NO;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    STSectionModel *sectionModel = _datasource[indexPath.section];
    
    if (sectionModel.type == kLEDStatePatternTableViewSectionCommands) {
        return YES;
    }
    
    return NO;
}


- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
        NSInteger row = 0;
        if (sourceIndexPath.section < proposedDestinationIndexPath.section) {
            row = [tableView numberOfRowsInSection:sourceIndexPath.section] - 1;
        }
        return [NSIndexPath indexPathForRow:row inSection:sourceIndexPath.section];
    }
    
    return proposedDestinationIndexPath;
}


@end
