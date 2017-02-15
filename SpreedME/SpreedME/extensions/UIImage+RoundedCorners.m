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

#import "UIImage+RoundedCorners.h"

@implementation UIImage (RoundedCorners)

- (UIImage *)roundCornersWithRadius:(CGFloat)cornerRadius
{	
	// Begin a new image that will be the new image with the rounded corners
	// (here with the size of an UIImageView)
	UIGraphicsBeginImageContextWithOptions(CGSizeMake(self.size.width, self.size.height), NO, 0.0);
	
	CGRect rect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
	
	// Add a clip before drawing anything, in the shape of an rounded rect
	[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, self.size.width, self.size.height)
								cornerRadius:cornerRadius] addClip];
	// Draw your image
	[self drawInRect:rect];
	
	// Get the image, here setting the UIImageView image
	UIImage *roundedImage = UIGraphicsGetImageFromCurrentImageContext();
	
	// Lets forget about that we were drawing
	UIGraphicsEndImageContext();
	
	return roundedImage;
}

@end
