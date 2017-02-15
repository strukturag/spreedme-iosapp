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

#import "MapViewController.h"
#import "MapAnnotation.h"

@interface MapViewController ()
@property (nonatomic, weak) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) MapAnnotation *annotation;
@end

@implementation MapViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.mapView setRegion:self.boundingRegion];

    MKMapItem *mapItem = [self.mapItemList objectAtIndex:0];

    MapAnnotation *annotation = [[MapAnnotation alloc] init];
    annotation.coordinate = mapItem.placemark.location.coordinate;
    annotation.title = mapItem.name;
    [self.mapView addAnnotation:annotation];
    
    [self.mapView selectAnnotation:[self.mapView.annotations objectAtIndex:0] animated:YES];
    
    self.mapView.centerCoordinate = mapItem.placemark.coordinate;
}


- (void)viewWillAppear:(BOOL)animated
{
    /* This solves a problem on iOS 7.0.
     In this iOS versionv NavBar is changed to translucent black when MKMapView appears*/
    self.navigationController.navigationBar.translucent = NO;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self.mapView removeAnnotations:self.mapView.annotations];
    
    /* This solves a problem on iOS 7.0.
     In this iOS versionv NavBar is changed to translucent black when MKMapView appears*/
    self.navigationController.navigationBar.translucent = NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
}


#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
	MKPinAnnotationView *annotationView = nil;
	if ([annotation isKindOfClass:[MapAnnotation class]])
	{
		annotationView = (MKPinAnnotationView *)[self.mapView dequeueReusableAnnotationViewWithIdentifier:@"Pin"];
		if (annotationView == nil)
		{
			annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin"];
			annotationView.canShowCallout = YES;
			annotationView.animatesDrop = YES;
		}
	}
	return annotationView;
}

@end
