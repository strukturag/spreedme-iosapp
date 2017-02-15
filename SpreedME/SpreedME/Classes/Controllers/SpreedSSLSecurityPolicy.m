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

#import "SpreedSSLSecurityPolicy.h"

// Equivalent of macro in <AssertMacros.h>, without causing compiler warning:
// "'DebugAssert' is deprecated: first deprecated in OS X 10.8"
#ifndef AF_Require
#define AF_Require(assertion, exceptionLabel)                \
do {                                                     \
if (__builtin_expect(!(assertion), 0)) {             \
goto exceptionLabel;                             \
}                                                    \
} while (0)
#endif

#ifndef AF_Require_noErr
#define AF_Require_noErr(errorCode, exceptionLabel)          \
do {                                                     \
if (__builtin_expect(0 != (errorCode), 0)) {         \
goto exceptionLabel;                             \
}                                                    \
} while (0)
#endif

#if !defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
static NSData * AFSecKeyGetData(SecKeyRef key) {
    CFDataRef data = NULL;
	
    AF_Require_noErr(SecItemExport(key, kSecFormatUnknown, kSecItemPemArmour, NULL, &data), _out);
	
    return (__bridge_transfer NSData *)data;
	
_out:
    if (data) {
        CFRelease(data);
    }
	
    return nil;
}
#endif

static BOOL AFSecKeyIsEqualToKey(SecKeyRef key1, SecKeyRef key2) {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    return [(__bridge id)key1 isEqual:(__bridge id)key2];
#else
    return [AFSecKeyGetData(key1) isEqual:AFSecKeyGetData(key2)];
#endif
}

static id AFPublicKeyForCertificate(NSData *certificate) {
    id allowedPublicKey = nil;
    SecCertificateRef allowedCertificate;
    SecCertificateRef allowedCertificates[1];
    CFArrayRef tempCertificates = nil;
    SecPolicyRef policy = nil;
    SecTrustRef allowedTrust = nil;
    SecTrustResultType result;
	
    allowedCertificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificate);
    AF_Require(allowedCertificate != NULL, _out);
	
    allowedCertificates[0] = allowedCertificate;
    tempCertificates = CFArrayCreate(NULL, (const void **)allowedCertificates, 1, NULL);
	
    policy = SecPolicyCreateBasicX509();
    AF_Require_noErr(SecTrustCreateWithCertificates(tempCertificates, policy, &allowedTrust), _out);
    AF_Require_noErr(SecTrustEvaluate(allowedTrust, &result), _out);
	
    allowedPublicKey = (__bridge_transfer id)SecTrustCopyPublicKey(allowedTrust);
	
_out:
    if (allowedTrust) {
        CFRelease(allowedTrust);
    }
	
    if (policy) {
        CFRelease(policy);
    }
	
    if (tempCertificates) {
        CFRelease(tempCertificates);
    }
	
    if (allowedCertificate) {
        CFRelease(allowedCertificate);
    }
	
    return allowedPublicKey;
}

static BOOL AFServerTrustIsValid(SecTrustRef serverTrust) {
    BOOL isValid = NO;
    SecTrustResultType result;
    AF_Require_noErr(SecTrustEvaluate(serverTrust, &result), _out);
	
    isValid = (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed);
	
_out:
    return isValid;
}

static NSArray * AFCertificateTrustChainForServerTrust(SecTrustRef serverTrust) {
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
	
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
        [trustChain addObject:(__bridge_transfer NSData *)SecCertificateCopyData(certificate)];
    }
	
    return [NSArray arrayWithArray:trustChain];
}

static NSArray * AFPublicKeyTrustChainForServerTrust(SecTrustRef serverTrust) {
    SecPolicyRef policy = SecPolicyCreateBasicX509();
    CFIndex certificateCount = SecTrustGetCertificateCount(serverTrust);
    NSMutableArray *trustChain = [NSMutableArray arrayWithCapacity:(NSUInteger)certificateCount];
    for (CFIndex i = 0; i < certificateCount; i++) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, i);
		
        SecCertificateRef someCertificates[] = {certificate};
        CFArrayRef certificates = CFArrayCreate(NULL, (const void **)someCertificates, 1, NULL);
		
        SecTrustRef trust;
        AF_Require_noErr(SecTrustCreateWithCertificates(certificates, policy, &trust), _out);
        
        SecTrustResultType result;
        AF_Require_noErr(SecTrustEvaluate(trust, &result), _out);
		
        [trustChain addObject:(__bridge_transfer id)SecTrustCopyPublicKey(trust)];
		
    _out:
        if (trust) {
            CFRelease(trust);
        }
		
        if (certificates) {
            CFRelease(certificates);
        }
		
        continue;
    }
    CFRelease(policy);
	
    return [NSArray arrayWithArray:trustChain];
}


#pragma mark -

@interface SpreedSSLSecurityPolicy() <UIAlertViewDelegate>
@property (readwrite, nonatomic, strong) NSArray *pinnedPublicKeys;
@end

@implementation SpreedSSLSecurityPolicy

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
	
    self.validatesCertificateChain = YES;
	self.allowUserCertificates = YES;
	self.trustedSSLStore = [TrustedSSLStore sharedTrustedStore];
	
    return self;
}


+ (instancetype)defaultPolicy {
    SpreedSSLSecurityPolicy *securityPolicy = [[self alloc] init];
    securityPolicy.SSLPinningMode = AFSSLPinningModeNone;
    securityPolicy.validatesDomainName = YES;
    
    return securityPolicy;
}

#pragma mark -

#pragma mark -

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust {
    return [self evaluateServerTrust:serverTrust forDomain:nil];
}

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust
                  forDomain:(NSString *)domain
{
    NSMutableArray *policies = [NSMutableArray array];
    if (self.validatesDomainName) {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateSSL(true, (__bridge CFStringRef)domain)];
    } else {
        [policies addObject:(__bridge_transfer id)SecPolicyCreateBasicX509()];
    }
	
    SecTrustSetPolicies(serverTrust, (__bridge CFArrayRef)policies);
	
	SecTrustResultType trustResult = EvaluateServerTrust(serverTrust);
	
    if (!(trustResult == kSecTrustResultUnspecified || trustResult == kSecTrustResultProceed)
		&& !self.allowInvalidCertificates && !self.allowUserCertificates) {
		
        return NO;
    }
	
	
	if (trustResult == kSecTrustResultRecoverableTrustFailure && self.allowUserCertificates) {
//	if ((trustResult == kSecTrustResultRecoverableTrustFailure || trustResult == kSecTrustResultUnspecified || trustResult == kSecTrustResultProceed) && self.allowUserCertificates) {
		BOOL trusted = [self.trustedSSLStore evaluateServerTrust:serverTrust forDomain:domain shouldValidateDomainName:self.validatesDomainName];
		if (!trusted) {
			SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0); // Take leaf certificate now. //TODO: maybe get root CA
			SSLCertificate *sslCert = [[SSLCertificate alloc] initWithNativeHandle:certificate];
			if (sslCert) {
				[self.trustedSSLStore proposeUserToSaveCertificate:sslCert];
			}
			return NO;
		}
	}
	
    NSArray *serverCertificates = AFCertificateTrustChainForServerTrust(serverTrust);
    switch (self.SSLPinningMode) {
        case AFSSLPinningModeNone:
            return YES;
        case AFSSLPinningModeCertificate: {
            NSMutableArray *pinnedCertificates = [NSMutableArray array];
            for (NSData *certificateData in self.pinnedCertificates) {
                [pinnedCertificates addObject:(__bridge_transfer id)SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certificateData)];
            }
            SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)pinnedCertificates);
			
            if (!AFServerTrustIsValid(serverTrust)) {
                return NO;
            }
			
            if (!self.validatesCertificateChain) {
                return YES;
            }
			
            NSUInteger trustedCertificateCount = 0;
            for (NSData *trustChainCertificate in serverCertificates) {
                if ([self.pinnedCertificates containsObject:trustChainCertificate]) {
                    trustedCertificateCount++;
                }
            }
			
            return trustedCertificateCount == [serverCertificates count];
        }
        case AFSSLPinningModePublicKey: {
            NSUInteger trustedPublicKeyCount = 0;
            NSArray *publicKeys = AFPublicKeyTrustChainForServerTrust(serverTrust);
            if (!self.validatesCertificateChain && [publicKeys count] > 0) {
                publicKeys = @[[publicKeys firstObject]];
            }
			
            for (id trustChainPublicKey in publicKeys) {
                for (id pinnedPublicKey in self.pinnedPublicKeys) {
                    if (AFSecKeyIsEqualToKey((__bridge SecKeyRef)trustChainPublicKey, (__bridge SecKeyRef)pinnedPublicKey)) {
                        trustedPublicKeyCount += 1;
                    }
                }
            }
			
            return trustedPublicKeyCount > 0 && ((self.validatesCertificateChain && trustedPublicKeyCount == [serverCertificates count]) || (!self.validatesCertificateChain && trustedPublicKeyCount >= 1));
        }
    }
    
    return NO;
}


@end

