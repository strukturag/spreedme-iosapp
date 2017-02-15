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

#import <Foundation/Foundation.h>
#import <Security/Security.h>

#import "SSLCertificate.h"


extern NSString * const SSLTrustedStoreHasAddNewTrustedCertificateNotification;
extern NSString * const kSSLTrustedStoreCertificateKey;

extern NSString * const UserDidAcceptCertificateNotification;
extern NSString * const UserDidRejectCertificateNotification;
extern NSString * const kTrustedSSLStoreCertificate;


/*
 At the moment this class is intented to be used only as singleton. If you create more than one instance it will mess up certificates persistant store.
 */

@interface TrustedSSLStore : NSObject

+ (instancetype)sharedTrustedStore;

@property (nonatomic, strong) UIViewController *viewControllerForActions;

- (NSArray *)trustedCertificates; // Returns an array of trusted certificates ready to be used in SecTrustSetAnchorCertificates

- (void)addNewTrustedCertificate:(SSLCertificate *)certificate;
- (void)addNewTrustedCertificateAsData:(NSData *)certificateData;
- (void)removeTrustedCertificate:(SSLCertificate *)certificate;


- (void)resetStore; // Wipes out all trusted certificates

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
   shouldValidateDomainName:(BOOL)shouldValidateDomainName;


- (void)proposeUserToSaveCertificate:(SSLCertificate *)certificate;

@end

SecTrustResultType EvaluateServerTrust(SecTrustRef serverTrust);

