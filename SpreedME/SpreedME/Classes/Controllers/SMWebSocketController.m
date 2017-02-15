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

#import "SMWebSocketController.h"

#import "PocketSocket/PocketSocket/PSWebSocket.h"



@interface SMWebSocketController () <PSWebSocketDelegate>
{
	STByteCount _bytesReceived;
	STByteCount _bytesSent;
	
	STByteCount _bytesReceivedCurrentWS;
	STByteCount _bytesSentCurrentWS;
}

@property (nonatomic, strong) PSWebSocket *webSocket;

@end

@implementation SMWebSocketController

#pragma mark - Object Lifecycle

- (id)init
{
	self = [super init];
	if (self) {
		
	}
	return self;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - WebSocket

- (void)send:(id)message
{
	if (_webSocket) {
		[_webSocket send:message];
	}
}


- (void)closeWebSocket
{
	[self updateDataUsageAndSumUpWS:YES];
	
	[_webSocket close];
	_webSocket.delegate = nil;
	_webSocket = nil;
}


- (void)connectWithURLRequest:(NSURLRequest *)urlRequest
{
	if (urlRequest) {
		[self updateDataUsageAndSumUpWS:YES];
		
		_webSocket = [PSWebSocket clientSocketWithRequest:urlRequest];
		_webSocket.delegate = self;
		[self setupWebSocketBeforeConnecting];
		[_webSocket open];
	} else {
		[self.delegate webSocketController:self
						  didFailWithError:[NSError errorWithDomain:(__bridge NSString *)kCFErrorDomainCFNetwork
															   code:kCFErrorHTTPBadURL
														   userInfo:nil]];
	}
}


- (void)connectWithURL:(NSURL *)serverURL
{
	if (serverURL) {
		NSURLRequest *request = [NSURLRequest requestWithURL:serverURL];
		[self connectWithURLRequest:request];
	} else {
		[self.delegate webSocketController:self
						  didFailWithError:[NSError errorWithDomain:(__bridge NSString *)kCFErrorDomainCFNetwork
															   code:kCFErrorHTTPBadURL
														   userInfo:nil]];
	}
}


- (void)setupWebSocketBeforeConnecting
{
	// Setup security options
	NSMutableDictionary *SSLOptions = [NSMutableDictionary dictionary];
	//	NSString *host = [[NSURL URLWithString:server] host];
	//	[SSLOptions setValue:host forKey:(__bridge id)kCFStreamSSLPeerName];
	
	[SSLOptions setValue:(__bridge id)kCFNull forKey:(__bridge id)kCFStreamSSLPeerName];
	[SSLOptions setValue:[NSNumber numberWithBool:NO] forKey:(__bridge id)kCFStreamSSLValidatesCertificateChain];
	
	
	
	if (_spreedMeMode) {
		// https://developer.apple.com/library/ios/technotes/tn2287/_index.html
//		const extern CFStringRef kCFStreamSocketSecurityLevelTLSv1_2;
//		[SSLOptions setValue:(__bridge id)kCFStreamSocketSecurityLevelTLSv1_2 forKey:(__bridge id)kCFStreamSSLLevel];
		[SSLOptions setValue:(__bridge id)kCFStreamSocketSecurityLevelNegotiatedSSL forKey:(__bridge id)kCFStreamSSLLevel];
	} else {
		[SSLOptions setValue:(__bridge id)kCFStreamSocketSecurityLevelNegotiatedSSL forKey:(__bridge id)kCFStreamSSLLevel];
	}
	
	[_webSocket setSSLOptions:[SSLOptions copy]];
	[_webSocket setStreamProperty:(__bridge CFStringRef)NSStreamNetworkServiceTypeVoIP forKey:NSStreamNetworkServiceType];
	
	if (_spreedMeMode) {
		size_t numCiphers = 20;
		SSLCipherSuite *ciphers = (SSLCipherSuite *)malloc(numCiphers * sizeof(SSLCipherSuite));
		ciphers[0] = TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384;
		ciphers[1] = TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384;
		ciphers[2] = TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256;
		ciphers[3] = TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256;
		ciphers[4] = TLS_DHE_RSA_WITH_AES_128_GCM_SHA256;
		ciphers[5] = TLS_DHE_DSS_WITH_AES_128_GCM_SHA256;
		ciphers[6] = TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384;
		ciphers[7] = TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384;
		ciphers[8] = TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256;
		ciphers[9] = TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256;
		ciphers[10] = TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA;
		ciphers[11] = TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA;
		ciphers[12] = TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA;
		ciphers[13] = TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA;
		ciphers[14] = TLS_DHE_RSA_WITH_AES_256_CBC_SHA256;
		ciphers[15] = TLS_DHE_RSA_WITH_AES_128_CBC_SHA256;
		ciphers[16] = TLS_DHE_RSA_WITH_AES_256_CBC_SHA;
		ciphers[17] = TLS_DHE_RSA_WITH_AES_128_CBC_SHA;
		ciphers[18] = TLS_DHE_DSS_WITH_AES_128_CBC_SHA256;
		ciphers[19] = TLS_DHE_DSS_WITH_AES_256_CBC_SHA;
		
		
		[_webSocket setEnabledCiphers:ciphers count:numCiphers];
		[_webSocket setSSLSetProtocolVersionMin:kTLSProtocol12];
		[_webSocket setShouldUseStrictUserCertificateChecking:YES];
	}
}


#pragma mark - Network data usage statistics

- (STByteCount)bytesSent
{
	[self updateDataUsageSentAndSumUpWS:NO];
	STByteCount totalSent = STAddByteCounts(_bytesSent, _bytesSentCurrentWS);
	return totalSent;
}


- (STByteCount)bytesReceived
{
	[self updateDataUsageReceivedAndSumUpWS:NO];
	STByteCount totalReceived = STAddByteCounts(_bytesReceived, _bytesReceivedCurrentWS);
	return totalReceived;
}


- (void)updateDataUsageAndSumUpWS:(BOOL)shouldSumUp
{
	[self updateDataUsageReceivedAndSumUpWS:shouldSumUp];
	[self updateDataUsageSentAndSumUpWS:shouldSumUp];
}


- (void)updateDataUsageReceivedAndSumUpWS:(BOOL)shouldSumUp
{
	if (_webSocket) {
		PSWebSocketByteCount wsBytesReceivedCount = _webSocket.bytesReceived;
		STByteCount byteCountReceived = { wsBytesReceivedCount.bytes, wsBytesReceivedCount.numberOf64BitOverflows };
		_bytesReceivedCurrentWS = byteCountReceived;
	}
	
	if (shouldSumUp) {
		STAddByteCountToByteCount(_bytesReceivedCurrentWS, &_bytesReceived);
		_bytesReceivedCurrentWS.bytes = 0;
		_bytesReceivedCurrentWS.numberOf64BitOverflows = 0;
	}
}


- (void)updateDataUsageSentAndSumUpWS:(BOOL)shouldSumUp
{
	if (_webSocket) {
		PSWebSocketByteCount wsBytesSentCount = _webSocket.bytesSent;
		STByteCount byteCountSent = { wsBytesSentCount.bytes, wsBytesSentCount.numberOf64BitOverflows };
		_bytesSentCurrentWS = byteCountSent;
	}
	
	if (shouldSumUp) {
		STAddByteCountToByteCount(_bytesSentCurrentWS, &_bytesSent);
		_bytesSentCurrentWS.bytes = 0;
		_bytesSentCurrentWS.numberOf64BitOverflows = 0;
	}
}


- (void)resetByteCount
{
	_bytesReceived = STByteCountMakeZero();
	_bytesReceivedCurrentWS = STByteCountMakeZero();
	_bytesSent = STByteCountMakeZero();
	_bytesSentCurrentWS = STByteCountMakeZero();
	
	[_webSocket resetByteCounts];
}


#pragma mark - PocketSocket delegate

- (void)webSocketDidOpen:(PSWebSocket *)webSocket
{
	if ([self.delegate respondsToSelector:@selector(webSocketControllerDidOpen:)]) {
		[self.delegate webSocketControllerDidOpen:self];
	}
}


- (void)webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if ([self.delegate respondsToSelector:@selector(webSocketController:didFailWithError:)]) {
		[self.delegate webSocketController:self didFailWithError:error];
	}
}


- (void)webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)message
{
	if ([self.delegate respondsToSelector:@selector(webSocketController:didReceiveMessage:)]) {
		[self.delegate webSocketController:self didReceiveMessage:message];
	}
	
	if ([self.messageReceiver respondsToSelector:@selector(webSocketController:didReceiveMessage:)]) {
		[self.messageReceiver webSocketController:self didReceiveMessage:message];
	}
}


- (void)webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if ([self.delegate respondsToSelector:@selector(webSocketController:didCloseWithCode:reason:wasClean:)]) {
		[self.delegate webSocketController:self didCloseWithCode:code reason:reason wasClean:wasClean];
	}
}


- (BOOL)webSocket:(PSWebSocket *)webSocket shouldTrustServer:(SecTrustRef)serverTrust
{
	BOOL shouldTrust = NO;
	
	if ([self.delegate respondsToSelector:@selector(webSocketController:shouldTrustServer:)]) {
		shouldTrust = [self.delegate webSocketController:self shouldTrustServer:serverTrust];
	}
	
	return shouldTrust;
}


#pragma mark - Getting websocket cipher suite

- (SSLCipherSuite)negotiatedCipherSuite
{
	return [self negotiatedCipherSuiteFromWebsocket:_webSocket];
}


- (SSLCipherSuite)negotiatedCipherSuiteFromWebsocket:(id)websocket
{
	SSLCipherSuite cipherSuite = SSL_NULL_WITH_NULL_NULL;
	
	// Apple forbids usage of private API :(
	
//	if ([websocket isKindOfClass:[PSWebSocket class]]) {
//		PSWebSocket *pocketSocket = (PSWebSocket *)websocket;
//		
//		// Small hack to get SSL context of NSStream from http://lists.apple.com/archives/Apple-cdsa/2008/Oct/msg00007.html
//		const extern CFStringRef kCFStreamPropertySocketSSLContext;
//		CFDataRef data = (CFDataRef)[pocketSocket copyStreamPropertyForKey:(__bridge id)kCFStreamPropertySocketSSLContext];
//		
//		SSLCipherSuite currentCipher = SSL_NULL_WITH_NULL_NULL;
//		
//		if (data) {
//			// Extract the SSLContextRef from the CFData
//			SSLContextRef sslContext;
//			CFDataGetBytes(data, CFRangeMake(0, sizeof(SSLContextRef)), (UInt8 *)&sslContext);
//			
//			SSLGetNegotiatedCipher(sslContext, &currentCipher);
//			CFRelease(data);
//		}
//		
//		cipherSuite = currentCipher;
//	}
	
	return cipherSuite;
}


@end
