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

#import "TrustedSSLStore.h"

#import "ChildRotationNavigationController.h"
#import "ConfirmSSLCertificateViewController.h"
#import "SSLCertificate.h"
#import "SSLCertificateViewController.h"

SecTrustResultType EvaluateServerTrust(SecTrustRef serverTrust) {
    SecTrustResultType result = 0;
	
#if defined(NS_BLOCK_ASSERTIONS)
    SecTrustEvaluate(serverTrust, &result);
#else
    OSStatus status = SecTrustEvaluate(serverTrust, &result);
    NSCAssert(status == errSecSuccess, @"SecTrustEvaluate error: %ld", (long int)status);
#endif
	
    return result;
}


static NSString * const separator = @"\n======================END======================\n";


NSString * const SSLTrustedStoreHasAddNewTrustedCertificateNotification			= @"SSLTrustedStoreHasAddNewTrustedCertificateNotification";
NSString * const kSSLTrustedStoreCertificateKey									= @"SSLTrustedStoreCertificateKey";

NSString * const UserDidAcceptCertificateNotification		= @"UserDidAcceptCertificateNotification";
NSString * const UserDidRejectCertificateNotification		= @"UserDidRejectCertificateNotification";
NSString * const kTrustedSSLStoreCertificate                = @"kTrustedSSLStoreCertificate";



@interface TrustedSSLStore () <ConfirmSSLCertificateViewControllerDelegate>
{
	NSMutableArray *_certificates;
	
	NSMutableDictionary *_pendingCertificates;
	
	SSLCertificate *_currentProposedCertificate;
	
	NSRecursiveLock *_lock;
	
	ConfirmSSLCertificateViewController *_currentSSLCertificateController;
}


@end


@implementation TrustedSSLStore


+ (instancetype)sharedTrustedStore
{
	static dispatch_once_t once;
    static TrustedSSLStore *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (instancetype)init
{
	self = [super init];
	if (self) {
		NSURL *fileURL = [self fileStorageUrl];
		_certificates = [[NSMutableArray alloc] initWithArray:[self loadCertificatesFromFileURL:fileURL]];
		_pendingCertificates = [[NSMutableDictionary alloc] init];
		_lock = [[NSRecursiveLock alloc] init];
	}
	
	return self;
}


#pragma mark - Private methods

- (NSURL *)fileStorageUrl
{
	NSString *appSupportDirectory = applicationSupportDirectory();
	
	NSString *certificatesFilesDir = [appSupportDirectory stringByAppendingPathComponent:@"cert"];
	
	BOOL isDirectory = YES;
	if (![[NSFileManager defaultManager] fileExistsAtPath:certificatesFilesDir isDirectory:&isDirectory]) {
		NSError *error = nil;
		//TODO: maybe we want to exclude this from backuping in iCloud/iTunes
		BOOL succes = [[NSFileManager defaultManager] createDirectoryAtPath:certificatesFilesDir withIntermediateDirectories:YES attributes:nil error:&error];
		if (!succes) {
			spreed_me_log("We couldn't create directory to store trusted certificates!");
			NSAssert(NO, @"We couldn't create directory to store trusted certificates!");
		}
	}
	
	NSString *filePath = [certificatesFilesDir stringByAppendingPathComponent:@"certs.stor"];
	
	NSURL *fileURL = [NSURL fileURLWithPath:filePath];
	
	return fileURL;
}


- (NSArray *)loadCertificatesFromFileURL:(NSURL *)fileURL
{
	NSMutableArray *certs = [NSMutableArray array];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:[fileURL path]]) {
		
		NSError *error = nil;
		NSString *fileString = [[NSString alloc] initWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
		if (!fileString && error) {
			NSAssert(NO, @"error loading certificates %@", [error localizedDescription]);
		}
		
		
		NSArray *certificateStrings = [fileString componentsSeparatedByString:separator];
		for (NSString *certString in certificateStrings) {
			if ([certString length] > 0) {
				
				NSData *certData = nil;
				
				if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
					certData = [[NSData alloc] initWithBase64Encoding:certString];
				} else {
					certData = [[NSData alloc] initWithBase64EncodedString:certString options:0];
				}
								
				SSLCertificate *cert = [[SSLCertificate alloc] initWithDerData:certData];
				
				if (!cert) {
					NSAssert(NO, @"Couldn't recreate certificate");
				}
				
				[certs addObject:cert];
			}
		}
	}
	
	return [NSArray arrayWithArray:certs];
}


- (void)saveCertificates
{
	NSString *certificatesString = @"";
	
	[_lock lock];
	
	for (SSLCertificate *cert in _certificates) {
		
		NSData *certData = [cert toDER];
		
		NSString *base64String = nil;
		if ([[[UIDevice currentDevice] systemVersion] floatValue] < 7.0) {
			base64String = [certData base64Encoding];
		} else {
			base64String = [certData base64EncodedStringWithOptions:0];
		}
		base64String = [base64String stringByAppendingString:separator];
		
		certificatesString = [certificatesString stringByAppendingString:base64String];
	}
	
	[_lock unlock];
    
    NSURL *fileURL = [self fileStorageUrl];
	
	if ([certificatesString length] > [separator length]) {
		NSError *error = nil;
		BOOL success = [certificatesString writeToURL:fileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
		NSAssert(success, @"error saving certificates %@", [error localizedDescription]);
    } else {
        NSError *error = nil;
        BOOL success = [[NSFileManager defaultManager] removeItemAtURL:fileURL error:&error];
        if (!success) {
            spreed_me_log("We could not delete certificates file %s", [error cDescription]);
        }
    }
}


// This method is expected to be run in main thread
- (BOOL)isCertificateInUserProposalQueue:(SSLCertificate *)certificate
{
	if (certificate) {
		for (id cert in _certificates) {
			
			if ([cert isEqualByFingerprints:certificate]) {
				[_pendingCertificates removeObjectForKey:certificate.uId];
				return YES;
			}
		}
	}
	id object = [_pendingCertificates objectForKey:certificate.uId];
	
	return object != nil;
}


// This method is expected to be run in main thread
- (void)addCertificateToUserProposalQueue:(SSLCertificate *)certificate
{
	if (certificate) {
		[_pendingCertificates setObject:certificate forKey:certificate.uId];
	}
}


// This method is expected to be run in main thread
- (void)removeCertificateFromUserProposalQueue:(SSLCertificate *)certificate
{
	if (certificate) {
		[_pendingCertificates removeObjectForKey:certificate.uId];
	}
}


- (void)processProposalQueue
{
	dispatch_async(dispatch_get_main_queue(), ^{
		SSLCertificate *certificate = [_pendingCertificates objectForKey:[[_pendingCertificates allKeys] firstObject]];
		
		if (certificate) {
			[_pendingCertificates removeObjectForKey:certificate.uId];
			[self proposeUserToSaveCertificate:certificate];
		}
	});
}


#pragma mark - User interaction

- (void)proposeUserCurrentPendingCertificate
{
	_currentSSLCertificateController = [[ConfirmSSLCertificateViewController alloc] initWithSSLCertificate:_currentProposedCertificate];
	_currentSSLCertificateController.delegate = self;
	ChildRotationNavigationController *navController = [[ChildRotationNavigationController alloc] initWithRootViewController:_currentSSLCertificateController];
	
	[self.viewControllerForActions presentViewController:navController animated:YES completion:^{
		
	}];
}


- (void)userDidAcceptCertificateInSSLCertificateViewController:(SSLCertificateViewController *)controller
{
	[self addNewTrustedCertificate:_currentProposedCertificate];
	
    [self postUserDidAcceptCertificateInSSLCertificateViewController:_currentProposedCertificate];
    	
	_currentProposedCertificate = nil;
	
	[_currentSSLCertificateController dismissViewControllerAnimated:YES completion:^{
		_currentSSLCertificateController = nil;
		
		[self processProposalQueue];
	}];
}


- (void)userDidRejectCertificateInSSLCertificateViewController:(SSLCertificateViewController *)controller
{
    [self postUserDidRejectCertificateInSSLCertificateViewController:_currentProposedCertificate];
    
	_currentProposedCertificate = nil;
	
	[_currentSSLCertificateController dismissViewControllerAnimated:YES completion:^{
		_currentSSLCertificateController = nil;
		
		[self processProposalQueue];
	}];
}


#pragma mark - Notifications

- (void)postUserDidAcceptCertificateInSSLCertificateViewController:(SSLCertificate *)certificate
{
    if (certificate) {
        NSDictionary *userInfo =  @{kTrustedSSLStoreCertificate : certificate};
        [[NSNotificationCenter defaultCenter] postNotificationName:UserDidAcceptCertificateNotification object:self userInfo:userInfo];
    }
}


- (void)postUserDidRejectCertificateInSSLCertificateViewController:(SSLCertificate *)certificate
{
    if (certificate) {
        NSDictionary *userInfo =  @{kTrustedSSLStoreCertificate : certificate};
        [[NSNotificationCenter defaultCenter] postNotificationName:UserDidRejectCertificateNotification object:self userInfo:userInfo];
    }
}


#pragma mark - Public methods

- (NSArray *)trustedCertificates
{
	[_lock lock];
	NSArray *returnArray = [NSArray arrayWithArray:_certificates];
	[_lock unlock];
	
	return returnArray;
}


- (void)addNewTrustedCertificate:(SSLCertificate *)certificate
{
	if (certificate) {
		[_lock lock];
		NSInteger firstEqualCertIndex = -1;
		for (SSLCertificate *cert in _certificates) {
			if ([cert isEqualByFingerprints:certificate]){
				firstEqualCertIndex = [_certificates indexOfObject:cert];
				break;
			}
		}
		
		if (firstEqualCertIndex == -1) {
			[_certificates addObject:certificate];
			dispatch_async(dispatch_get_main_queue(), ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:SSLTrustedStoreHasAddNewTrustedCertificateNotification
																	object:self
																  userInfo:@{kSSLTrustedStoreCertificateKey:certificate}];
			});
			
		} else {
			spreed_me_log("A certificate with the same fingerprints already exists in base! md5 %s sha1 %s",
						  [SSLCertificate stringRepresentationForFingerprint:certificate.md5_fingerprint],
						  [SSLCertificate stringRepresentationForFingerprint:certificate.sha1_fingerprint]);
		}
		
		
		[_lock unlock];
		
		[self saveCertificates];
	}
}


- (void)addNewTrustedCertificateAsData:(NSData *)certificateData
{
	[_lock lock];
	SSLCertificate *certificate = [[SSLCertificate alloc] initWithDerData:certificateData];
	if (certificate) {
		[self addNewTrustedCertificate:certificate];
	}
	[_lock unlock];
}


- (void)removeTrustedCertificate:(SSLCertificate *)certificate
{
	[_lock lock];
	if (certificate) {
		NSInteger certsToDeleteIndex = -1;
		for (SSLCertificate *cert in _certificates) {
			if ([cert isEqualByFingerprints:certificate]){
				certsToDeleteIndex = [_certificates indexOfObject:cert];
				break;
			}
		}
		
		if (certsToDeleteIndex > -1) {
			[_certificates removeObjectAtIndex:certsToDeleteIndex];
		}
	}
	[_lock unlock];
	
	[self saveCertificates];
}


- (void)resetStore
{
	[_lock lock];
	[_certificates removeAllObjects];
	[_lock unlock];
	[self saveCertificates];
}


- (BOOL)nativeEvaluateServerTrust:(SecTrustRef)serverTrust
						forDomain:(NSString *)domain
		 shouldValidateDomainName:(BOOL)shouldValidateDomainName
{
	NSMutableArray *policies = [NSMutableArray array];
    if (shouldValidateDomainName) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
	
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
	
	[_lock lock];
	CFArrayRef certArrayRef = CFBridgingRetain(self.trustedCertificates);
	[_lock unlock];
	SecTrustSetAnchorCertificates(serverTrust, certArrayRef);
	
	SecTrustResultType trustResult = EvaluateServerTrust(serverTrust);
	CFRelease(certArrayRef);
	
    if (trustResult == kSecTrustResultUnspecified || trustResult == kSecTrustResultProceed) {
		
        return YES;
    }
	
	return NO;
}


- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
   shouldValidateDomainName:(BOOL)shouldValidateDomainName
{
	[_lock lock];
	
	SecCertificateRef secCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0); // take the leaf only
	
	SSLCertificate *certificate = [[SSLCertificate alloc] initWithNativeHandle:secCertificate];
	
	// Check if proposed certificate valid, if no don't trust immidiately.
	BOOL shouldTrust = [certificate isValid];
	if (shouldTrust == NO) {
		[_lock unlock];
		return shouldTrust;
	}
	
	// if certificate is valid set shouldTrust to NO again before trust evaluation.
	shouldTrust = NO;
	
	
	for (SSLCertificate *cert in _certificates) {
		if ([cert isEqualByFingerprints:certificate]) {
			shouldTrust = YES;
			break;
		}
	}
	
	[_lock unlock];
	
	
	return shouldTrust;
}


- (void)proposeUserToSaveCertificate:(SSLCertificate *)certificate
{
	if (certificate) {
		
//		NSLog(@"cert issuer name %@, sha1 fingerprint = %@, md5 fingerprint = %@",
//			  [certificate issuerRawString],
//			  [SSLCertificate stringRepresentationForFingerprint:certificate.sha1_fingerprint],
//			  [SSLCertificate stringRepresentationForFingerprint:certificate.md5_fingerprint]);
//		
//		NSLog(@"pub key %@", [certificate publicKey]);
//		NSLog(@"cert serial number = %@", [certificate serialNumberString]);
		
		dispatch_async(dispatch_get_main_queue(), ^{
		
			if (![self isCertificateInUserProposalQueue:certificate]) {
				
				if (!_currentProposedCertificate && self.viewControllerForActions) {
				
					_currentProposedCertificate = certificate;
					
					[self proposeUserCurrentPendingCertificate];
					
				} else {
                    if (![_currentProposedCertificate.uId isEqualToString:certificate.uId]) {
                        [self addCertificateToUserProposalQueue:certificate];
                    }
				}
			}
		});
	}
}


@end
