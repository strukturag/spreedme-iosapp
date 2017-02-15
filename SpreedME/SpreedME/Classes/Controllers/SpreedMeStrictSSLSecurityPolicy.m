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

#import "SpreedMeStrictSSLSecurityPolicy.h"

#import "SpreedMeTrustedSSLStore.h"

#ifndef AF_Require_noErr
#define AF_Require_noErr(errorCode, exceptionLabel)          \
do {                                                     \
if (__builtin_expect(0 != (errorCode), 0)) {         \
goto exceptionLabel;                             \
}                                                    \
} while (0)
#endif

static BOOL AFServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    AF_Require_noErr(SecTrustEvaluate(serverTrust, &result), _out);
    
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
    
_out:
    return isValid;
}


@implementation SpreedMeStrictSSLSecurityPolicy

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.validatesCertificateChain = YES;
    
    return self;
}

+ (NSArray *)defaultPinnedCertificates {
    static NSArray *_defaultPinnedCertificates = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSArray *paths = [bundle pathsForResourcesOfType:@"cer" inDirectory:@"."];
        
        NSMutableArray *certificates = [NSMutableArray arrayWithCapacity:[paths count]];
        for (NSString *path in paths) {
            NSData *certificateData = [NSData dataWithContentsOfFile:path];
            [certificates addObject:certificateData];
        }
        
        _defaultPinnedCertificates = [[NSArray alloc] initWithArray:certificates];
    });
    
    return _defaultPinnedCertificates;
}

+ (instancetype)defaultPolicy {
    SpreedMeStrictSSLSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = AFSSLPinningModeCertificate;
    securityPolicy.validatesDomainName = YES;
    [securityPolicy setPinnedCertificates:[self defaultPinnedCertificates]];
    
    return securityPolicy;
}


- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust {
    return [self evaluateServerTrust:serverTrust forDomain:nil];
}


- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    NSMutableArray *pinnedCertificates = [NSMutableArray array];
    for (NSData *certificateData in self.pinnedCertificates) {
        [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
    }
    SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);
    SecTrustSetAnchorCertificatesOnly(serverTrust, true);
    
    if (!AFServerTrustIsValid(serverTrust)) {
        return NO;
    }
    
	return [[SpreedMeTrustedSSLStore sharedTrustedStore] evaluateServerTrust:serverTrust forDomain:domain shouldValidateDomainName:self.validatesDomainName];
}


@end
