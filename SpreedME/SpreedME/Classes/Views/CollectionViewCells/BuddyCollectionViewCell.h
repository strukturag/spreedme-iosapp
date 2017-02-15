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

#import <UIKit/UIKit.h>

#import "OutlinedLabel.h"
#import "User.h"
#import "SMCallDisconnectedUserActivityView.h"


typedef enum UserCallVisualState
{
	kUCVSConnecting = 0,
	kUCVSIncomingCall,
	kUCVSOutgoingCall,
	kUCVSConnected,
	kUCVSDisconnected,
	kUCVSFailed,
}
UserCallVisualState;


@interface BuddyVisual : NSObject
@property (nonatomic, strong) User *buddy;
@property (nonatomic, assign) UserCallVisualState visualState;
@property (nonatomic, strong) UIView *videoRenderView;
@property (nonatomic, assign) CGFloat videoRenderViewAspectRatio;
@end


@interface BuddyCollectionViewCell : UICollectionViewCell

+ (BuddyCollectionViewCell *)cellFromNibNamed:(NSString *)nibName;


@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@property (nonatomic, weak) IBOutlet UIImageView *logoImageView;
@property (nonatomic, weak) IBOutlet OutlinedLabel *nameLabel;
@property (nonatomic, weak) IBOutlet OutlinedLabel *statusLabel;
@property (nonatomic, weak) IBOutlet UIView *renderViewContainer;

@property (nonatomic, strong) SMCallDisconnectedUserActivityView *disconnectedActivityView;

@property (nonatomic, strong) BuddyVisual *buddyVisual;

- (void)updateUI;

@end
