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

#import "STServerSetupTableViewCell.h"

#import "SMLocalizedStrings.h"
#import "UIFont+FontAwesome.h"
#import "NSString+FontAwesome.h"


const CGFloat kServerURLTextFieldHeight = 35.0f;
const CGFloat kServerURLTextFieldBorderWidth = 1.0f;
const CGFloat kConnectionStatusLabelHeight = 25.0f;
const CGFloat kConnectionStatusIconViewlHeight = kConnectionStatusLabelHeight;
const CGFloat kConnectionStatusIconViewlWidth = 20.0f;


@implementation STServerSetupTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.serverURLTextField = [[UITextField alloc] initWithFrame:self.contentView.bounds];
        self.serverURLTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        self.serverURLTextField.font = [UIFont systemFontOfSize:16];
        self.serverURLTextField.keyboardType = UIKeyboardTypeURL;
        self.serverURLTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.serverURLTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.serverURLTextField.returnKeyType = UIReturnKeyDone;
        self.serverURLTextField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        self.serverURLTextField.layer.cornerRadius = kViewCornerRadius;
        self.serverURLTextField.clipsToBounds = YES;
        [self.contentView addSubview:self.serverURLTextField];
        
        self.connectionStatusLabel = [[UILabel alloc] initWithFrame:self.contentView.bounds];
        self.connectionStatusLabel.font = [UIFont systemFontOfSize:14];
        self.connectionStatusLabel.textColor = kSMBuddyCellSubtitleColor;
        self.connectionStatusLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.connectionStatusLabel];
        
        self.connectionStatusIconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kConnectionStatusLabelHeight, kConnectionStatusLabelHeight)];
        [self.contentView addSubview:self.connectionStatusIconView];
        
        if ([self respondsToSelector:@selector(setSeparatorInset:)]) {
            self.separatorInset = UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f);
        }
    }
    return self;
}


- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.serverURLTextField.delegate = nil;
    self.serverURLTextField.text = nil;
    self.serverURLTextField.backgroundColor = [UIColor clearColor];
    
    self.connectionStatusLabel.text = nil;
    self.connectionStatusLabel.backgroundColor = [UIColor clearColor];
    
    [[self.connectionStatusIconView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
}


- (void)layoutSubviews
{
    [super layoutSubviews];
    
    
    self.serverURLTextField.frame = CGRectMake(kTVCellHorizontalEdge,
                                               kTVCellVerticalEdge,
                                               self.contentView.bounds.size.width - 2 * kTVCellHorizontalEdge,
                                               kServerURLTextFieldHeight);
    
    self.connectionStatusIconView.frame = CGRectMake(kTVCellHorizontalEdge,
                                                     self.serverURLTextField.frame.origin.y + self.serverURLTextField.frame.size.height + kTVCellVerticalGap,
                                                     kConnectionStatusIconViewlWidth,
                                                     kConnectionStatusIconViewlHeight);
    
    self.connectionStatusLabel.frame = CGRectMake(self.connectionStatusIconView.frame.origin.x + self.connectionStatusIconView.frame.size.width + kTVCellHorizontalGap,
                                                  self.connectionStatusIconView.frame.origin.y ,
                                                  self.contentView.bounds.size.width - self.connectionStatusIconView.frame.size.width - 4 * kTVCellHorizontalEdge,
                                                  kConnectionStatusLabelHeight);
    
    self.serverURLTextField.backgroundColor = [UIColor clearColor];
}


#pragma mark - CustomTableViewCellProtocol

+ (NSString *)cellReuseIdentifier
{
    return @"STServerSetupTableViewCellIdentifier";
}


+ (CGFloat)cellHeight
{
    return kTVCellVerticalEdge + kServerURLTextFieldHeight + kConnectionStatusLabelHeight + kTVCellVerticalEdge;
}


#pragma mark - Getters/setters

- (void)setConnectionStatus:(ServerConnectionStatus)connectionStatus
{
    if (connectionStatus != _connectionStatus) {
        _connectionStatus = connectionStatus;
    }
    
    [self setupConnectionStatusUI];
}


#pragma mark - Utils

- (void)setupConnectionStatusUI
{
    [self setupServerURLTextField];
    [self setupConnectionStatusInfo];
}


- (void)setupServerURLTextField
{
    if (_connectionStatus == kServerConnectionStatusDisconnected) {
        self.serverURLTextField.font = [UIFont systemFontOfSize:16];
        self.serverURLTextField.textColor = kSMBuddyCellTitleColor;
        self.serverURLTextField.userInteractionEnabled = YES;
    } else {
        self.serverURLTextField.font = [UIFont systemFontOfSize:14];
        self.serverURLTextField.textColor = kSMBuddyCellSubtitleColor;
        self.serverURLTextField.userInteractionEnabled = NO;
    }
}


- (void)setupConnectionStatusInfo
{
    NSString *infoText = nil;
    UILabel *iconLabel = nil;
    UIActivityIndicatorView *activityIndicatorView = nil;
    
    switch (_connectionStatus) {
        case kServerConnectionStatusDisconnected:
            iconLabel = [self createIconLabel:[NSString fontAwesomeIconStringForEnum:FABan] color:kSMRedButtonColor];
            infoText = kSMLocalStringDisconnectedLabel;
            break;
            
        case kServerConnectionStatusConnecting:
            activityIndicatorView = [self createActivityIndicatorView];
            infoText = kSMLocalStringConnectingEllipsisLabel;
            break;
            
        case kServerConnectionStatusConnected:
            iconLabel = [self createIconLabel:[NSString fontAwesomeIconStringForEnum:FACheckCircleO] color:kSMGreenButtonColor];
            infoText = kSMLocalStringConnectedLabel;
            break;
            
        default:
            break;
    }
    
    if (activityIndicatorView) {
        [activityIndicatorView startAnimating];
        [self.connectionStatusIconView addSubview:activityIndicatorView];
    } else {
        [self.connectionStatusIconView addSubview:iconLabel];
    }
    
    self.connectionStatusLabel.text = infoText;
}


- (UILabel *)createIconLabel:(NSString *)iconName color:(UIColor *)color
{
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, kConnectionStatusLabelHeight, kConnectionStatusLabelHeight)];
    NSString *labelText = [NSString stringWithFormat:@"%@", iconName];
    UIFont *iconFont=[UIFont fontWithName:kFontAwesomeFamilyName size:18];
    
    NSMutableAttributedString *labelAttributedText = [[NSMutableAttributedString alloc] initWithString:labelText];
    [labelAttributedText addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0,1)];
    [labelAttributedText addAttribute:NSFontAttributeName value:iconFont range:NSMakeRange(0, 1)];
    
    iconLabel.backgroundColor = [UIColor clearColor];
    iconLabel.attributedText = labelAttributedText;
    
    return iconLabel;
}


- (UIActivityIndicatorView *)createActivityIndicatorView
{
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, kConnectionStatusIconViewlWidth, kConnectionStatusIconViewlHeight)];
    activityIndicatorView.color = kSpreedMeBlueColor;
    
    return activityIndicatorView;
}


@end
