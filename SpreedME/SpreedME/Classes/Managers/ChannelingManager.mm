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

#import "ChannelingManager.h"
#import "ChannelingManager_ObjectiveCPP.h"

#import "JSONKit.h"
#import "ReachabilityManager.h"
#import "SMWebSocketController.h"
#import "SpreedMeTrustedSSLStore.h"
#import "STRandomStringGenerator.h"
#import "UIDevice+Hardware.h"
#import "UsersManager.h"


#pragma mark - Constants and Notifications


const NSTimeInterval kKeepAliveWaitTime = 300.0;
const NSTimeInterval kKeepAliveTimeOut = 7.0;


#pragma mark - Channeling Manager

@interface ChannelingManager () <SMWebSocketControllerDelegate>
{
	BuddyParser *_buddyParser;
	
	NSTimer *_keepAliveTimeoutTimer;
	NSTimer *_keepAliveTimer;
	int64_t _lastAliveMessageTimeStamp; // integer, in miliseconds
	
	SMWebSocketController *_webSocketController;
	
	STByteCount _bytesSent;
	STByteCount _bytesReceived;
	
	STByteCount _bytesSentCurrentWSC;
	STByteCount _bytesReceivedCurrentWSC;
	
	SMChannelingRequest *_lastHelloRequest;
}

@property (nonatomic, strong) NSString *lastUsedServer;
@property (nonatomic, strong) NSString *sessionToken;

@end


@implementation ChannelingManager

#pragma mark - Object Lifecycle

+ (instancetype)sharedInstance
{
	static dispatch_once_t once;
    static ChannelingManager *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}


- (id)init
{
	self = [super init];
	if (self) {
		
		_buddyParser = [[BuddyParser alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
	}
	return self;
}


- (void)dealloc
{
	[_keepAliveTimer invalidate];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark - WebSocket related stuff

- (void)closeConnection
{
	[self updateDataUsageAndSumUpWS:YES];
	
	[_webSocketController closeWebSocket];
	_webSocketController.delegate = nil;
	_webSocketController = nil;
	self.isConnected = NO;
	
	[self stopKeepAliveTimeoutTimer];
	[self stopKeepAliveTimer];
}


- (void)connectToServer:(NSString *)server withToken:(NSString *)token
{
	NSString *serverToConnect = server;
	if ([token length]) {
		serverToConnect = [serverToConnect stringByAppendingFormat:@"?t=%@", token];
	}
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:serverToConnect]];
	
	[self updateDataUsageAndSumUpWS:YES];
	
	_webSocketController = [[SMWebSocketController alloc] init];
	_webSocketController.spreedMeMode = self.spreedMeMode;
	_webSocketController.delegate = self;
	[_webSocketController connectWithURLRequest:request];
}


#pragma mark - Network data usage statistics

- (STByteCount)bytesSent
{
	[self updateDataUsageSentAndSumUpWS:NO];
	STByteCount totalSent = STAddByteCounts(_bytesSent, _bytesSentCurrentWSC);
	return totalSent;
}


- (STByteCount)bytesReceived
{
	[self updateDataUsageReceivedAndSumUpWS:NO];
	STByteCount totalReceived = STAddByteCounts(_bytesReceived, _bytesReceivedCurrentWSC);
	return totalReceived;
}


- (void)updateDataUsageAndSumUpWS:(BOOL)shouldSumUp
{
	[self updateDataUsageReceivedAndSumUpWS:shouldSumUp];
	[self updateDataUsageSentAndSumUpWS:shouldSumUp];
}


- (void)updateDataUsageReceivedAndSumUpWS:(BOOL)shouldSumUp
{
	if (_webSocketController) {
		_bytesReceivedCurrentWSC = _webSocketController.bytesReceived;
	}
	
	if (shouldSumUp) {
		STAddByteCountToByteCount(_bytesReceivedCurrentWSC, &_bytesReceived);
		_bytesReceivedCurrentWSC.bytes = 0;
		_bytesReceivedCurrentWSC.numberOf64BitOverflows = 0;
	}
}


- (void)updateDataUsageSentAndSumUpWS:(BOOL)shouldSumUp
{
	if (_webSocketController) {
		_bytesSentCurrentWSC = _webSocketController.bytesSent;
	}
	
	if (shouldSumUp) {
		STAddByteCountToByteCount(_bytesSentCurrentWSC, &_bytesSent);
		_bytesSentCurrentWSC.bytes = 0;
		_bytesSentCurrentWSC.numberOf64BitOverflows = 0;
	}
}


#pragma mark - SMWebSocketController delegate

- (void)webSocketControllerDidOpen:(SMWebSocketController *)wsController
{
	spreed_me_log("Websocket controller %s did open",  [wsController cDescription]);
	
	SSLCipherSuite currentCipher = [_webSocketController negotiatedCipherSuite];
	char *cipherName = cipherNameForNumber(currentCipher);
	spreed_me_log("Websocket negotiated cipher %s", cipherName);
	free(cipherName);
	
	self.isConnected = YES;
	
	if ([self.observer respondsToSelector:@selector(channelingManagerDidConnectToServer:)]) {
		[self.observer channelingManagerDidConnectToServer:self];
	}
}


- (void)webSocketController:(SMWebSocketController *)wsController didFailWithError:(NSError *)error
{
    _webSocketController.delegate = nil;
    _webSocketController = nil;
	
	if (self.isConnected) {
		self.isConnected = NO;
	}
	
	if ([self.observer respondsToSelector:@selector(channelingManagerDidDisconnectFromServer:)]) {
		[self.observer channelingManagerDidDisconnectFromServer:self];
	}
	
	spreed_me_log("WebsocketController %s did fail with error %s ", [wsController cDescription], [error cDescription]);
}


- (void)webSocketController:(SMWebSocketController *)wsController didReceiveMessage:(id)message
{
	[self signallingHandlerReceiveMessage:message transportType:kWebsocketChannelingServer wrapperId:nil];
}


- (void)webSocketController:(SMWebSocketController *)wsController didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if (wsController == _webSocketController) {
        _webSocketController.delegate = nil;
        _webSocketController = nil;
    } else {
        spreed_me_log("This should not happen. Got delegate message from unknown websocket %s", [wsController cDescription]);
    }
	
	if (self.isConnected) {
		self.isConnected = NO;
	}
	
	if ([self.observer respondsToSelector:@selector(channelingManagerDidDisconnectFromServer:)]) {
		[self.observer channelingManagerDidDisconnectFromServer:self];
	}
	
	spreed_me_log("Websocket %s did close with code %d reason %s wasClean %s ",
				  [wsController cDescription],
				  code,
				  [reason cDescription],
				  wasClean ? [@"YES" cDescription] : [@"NO" cDescription]);
}


- (BOOL)webSocketController:(SMWebSocketController *)wsController shouldTrustServer:(SecTrustRef)serverTrust
{
	BOOL shouldTrust = NO;
	if (_spreedMeMode) {
		shouldTrust = [[SpreedMeTrustedSSLStore sharedTrustedStore] evaluateServerTrust:serverTrust forDomain:[[NSURL URLWithString:self.currentServer] host] shouldValidateDomainName:NO];
	} else {
		shouldTrust = [[TrustedSSLStore sharedTrustedStore] evaluateServerTrust:serverTrust forDomain:[[NSURL URLWithString:self.currentServer] host] shouldValidateDomainName:NO];
	}
	if (!shouldTrust) {
//		SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0); // Take leaf certificate now. //TODO: maybe get root CA
//		SSLCertificate *sslCert = [[SSLCertificate alloc] initWithNativeHandle:certificate];
//		if (sslCert) {
//			[[TrustedSSLStore sharedTrustedStore] proposeUserToSaveCertificate:sslCert];
//		}
	}
	return shouldTrust;
}


#pragma mark - Getting cipher suite

- (SSLCipherSuite)negotiatedCipherSuite
{
	SSLCipherSuite cipherSuite = SSL_NULL_WITH_NULL_NULL;
	
	if (_webSocketController) {
		
		cipherSuite = [_webSocketController negotiatedCipherSuite];
	}
	
	return cipherSuite;
}


#pragma mark - Notifications

- (void)applicationWillResignActive:(NSNotification *)notification
{
	[self stopKeepAliveTimeoutTimer];
	[self stopKeepAliveTimer];
}


#pragma mark - Keep Alive functionality

- (void)startKeepAliveTimer
{
	[self stopKeepAliveTimeoutTimer];
	
	[_keepAliveTimer invalidate];
	_keepAliveTimer = [NSTimer scheduledTimerWithTimeInterval:kKeepAliveWaitTime target:self selector:@selector(sendHeartBeat:) userInfo:nil repeats:NO];
}


- (void)stopKeepAliveTimer
{
	[_keepAliveTimer invalidate];
	_keepAliveTimer = nil;
}


- (void)startKeepAliveTimeoutTimeWithTimeStamp:(int64_t)timeStamp
{
	_lastAliveMessageTimeStamp = timeStamp;
	
	if (!_keepAliveTimeoutTimer) {
		_keepAliveTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kKeepAliveTimeOut target:self selector:@selector(connectionHasSilentlyFailed) userInfo:nil repeats:NO];
	}
}


- (void)stopKeepAliveTimeoutTimer
{
	[_keepAliveTimeoutTimer invalidate];
	_keepAliveTimeoutTimer = nil;
}


- (void)connectionHasSilentlyFailed
{
	spreed_me_log("Connection has silently failed %s", [self cDescription]);
	
	[self closeConnection];
	if ([self.observer respondsToSelector:@selector(channelingManagerDidDisconnectFromServer:)]) {
		[self.observer channelingManagerDidDisconnectFromServer:self];
	}
}


#pragma mark - Channeling API calls

- (void)sendStatusWithDisplayName:(NSString *)displayName statusMessage:(NSString *)statusMessage picture:(NSString *)picture
{
    if (!displayName) {
		displayName = @"";
	}
	
	if (!picture) {
		picture = @"";
	}
	
	if (!statusMessage) {
		statusMessage = @"";
	}
	
	NSDictionary *status = @{NSStr(kTypeKey) : NSStr(kStatusKey),
							 NSStr(kStatusKey): @{ NSStr(kTypeKey) : NSStr(kStatusKey),
												   NSStr(kStatusKey): @{@"displayName": displayName,
																		@"buddyPicture" : picture,
																		NSStr(kLCMessageKey) : statusMessage}}};
    
	NSString *jsonStatusResponse = [status JSONString];
	//spreed_me_log("Status request: %s", [jsonStatusResponse cDescription]);
	[self sendMessage:jsonStatusResponse];
}


- (void)sayBye
{
	NSDictionary *bye = @{NSStr(kTypeKey) : NSStr(kByeKey), NSStr(kByeKey): @{}, NSStr(kToKey) : @""};
	NSString *jsonByeResponse = [bye JSONString];
	spreed_me_log("Bye request: %s", [jsonByeResponse cDescription]);
	[self sendMessage:jsonByeResponse];
}


- (void)requestUsersListInCurrentRoom
{
	NSDictionary *userListRequest = @{NSStr(kTypeKey): NSStr(kUsersKey), NSStr(kUsersKey): @[]};
	NSString *jsonGetUsersList = [userListRequest JSONString];
	spreed_me_log("Users list in current room request: %s", [jsonGetUsersList cDescription]);
#warning USER: This shouldn't be sent like this. This is always server call.
	[self sendMessage:jsonGetUsersList type:NSStr(kUsersKey) to:nil];
}


- (void)sendEmptySelf
{
	NSDictionary *emptySelf = @{NSStr(kTypeKey) : NSStr(kSelfKey)};
	NSString *emptySelfString = [emptySelf JSONString];
	spreed_me_log("Empty self request: %s", [emptySelfString cDescription]);
	[self sendMessage:emptySelfString];
}


- (void)sendHeartBeat:(NSTimer *)theTimer
{
	int64_t timeStamp_int = (int64_t)([[NSDate date] timeIntervalSince1970] * 1000.0);
	NSDictionary *aliveRequest = @{NSStr(kTypeKey) : NSStr(kAliveKey), NSStr(kAliveKey) : @(timeStamp_int)};
	NSString *aliveMessage = [aliveRequest JSONString];
	
	spreed_me_log("Heartbeat request: %s", [aliveMessage cDescription]);
	[self startKeepAliveTimeoutTimeWithTimeStamp:timeStamp_int];
	[self sendMessage:aliveMessage type:NSStr(kAliveKey) to:nil];
}


- (void)sendAuthenticationRequestWithUserId:(NSString *)userId nonce:(NSString *)nonce
{
	NSDictionary *authent = @{NSStr(kTypeKey) : NSStr(kAuthenticationKey), NSStr(kAuthenticationKey) : @{ NSStr(kUserIdKey) : userId, NSStr(kNonceKey) : nonce}};
	NSString *authentString = [authent JSONString];
	spreed_me_log("Authentication request: %s", [authentString cDescription]);
	[self sendMessage:authentString type:NSStr(kAuthenticationKey) to:nil];
}


- (void)sendSessionsRequestWithTokenType:(NSString *)tokenType token:(NSString *)token
{
	if (tokenType && token) {
		
		NSDictionary *sessionsRequestDict = @{ NSStr(kTypeKey) : NSStr(kSessionsKey),
											   NSStr(kSessionsKey):
												   @{ NSStr(kTypeKey) : tokenType, NSStr(kTokenKey) : token }
											   };
		NSString *sessionsRequestStr = [sessionsRequestDict JSONString];
		spreed_me_log("Sessions request: %s", [sessionsRequestStr cDescription]);
		
		[self sendMessage:sessionsRequestStr type:NSStr(kSessionsKey) to:nil];
		
	} else {
		spreed_me_log("Empty tokenType or token or both in sessions request!");
	}
}


#pragma mark - STNetworkDataStatisticsController DataSource

- (STByteCount)sentByteCountForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller
{
	return self.bytesSent;
}


- (STByteCount)receivedByteCountForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller
{
	return self.bytesReceived;
}


- (void)resetDataStatisticsForNetworkDataStatisticsController:(STNetworkDataStatisticsController *)controller
{
	_bytesReceived = STByteCountMakeZero();
	_bytesReceivedCurrentWSC = STByteCountMakeZero();
	_bytesSent = STByteCountMakeZero();
	_bytesSentCurrentWSC = STByteCountMakeZero();
	
	[_webSocketController resetByteCount];
}


#pragma mark - Call fuctionality

- (void)sayByeToRecepient:(NSString *)recepientId withReason:(ByeReason)reason
{
	NSDictionary *reasonDic = @{};
	
	switch (reason) {
		case kByeReasonBusy:
			reasonDic = @{NSStr(kByeReasonKey) : NSStr(kByeReasonBusyString)};
			break;
			
		case kByeReasonNoAnswer:
			reasonDic = @{NSStr(kByeReasonKey) : NSStr(kByeReasonNoAnswerString)};
			break;
			
		case kByeReasonNotSpecified:
		default:
			break;
	}
	
	NSDictionary *bye = @{NSStr(kToKey) : recepientId, NSStr(kTypeKey) : NSStr(kByeKey), NSStr(kByeKey): reasonDic};
	NSString *jsonByeResponse = [bye JSONString];
	spreed_me_log("Bye request: %s", [jsonByeResponse cDescription]);
	[self sendMessage:jsonByeResponse type:NSStr(kByeKey) to:recepientId];
}


- (void)sendConferenceRequestMessageTo:(NSString *)conferenceId inRoom:(NSString *)room
{
	NSDictionary *chatMessage = @{NSStr(kTypeKey) : NSStr(kChatKey), NSStr(kChatKey):
									  @{ NSStr(kToKey): conferenceId, NSStr(kTypeKey): NSStr(kChatKey), NSStr(kChatKey):
											 @{NSStr(kMessageKey):[NSNull null], NSStr(kStatusKey) :
												   @{NSStr(kLCTypeKey) : NSStr(kLCConferenceKey), NSStr(kLCIdKey) : room}}}};
	NSString *jsonChatMessage = [chatMessage JSONString];
	spreed_me_log("Conference request: %s", [jsonChatMessage cDescription]);
	[self sendMessage:jsonChatMessage];
}


#pragma mark - Channeling functionality

- (NSString *)getUserAgentString
{
	NSString *userAgentString = nil;
	
	UIDevice *device = [UIDevice currentDevice];
	
	userAgentString = [NSString stringWithFormat:@"%@ - %@", [device platform], device.systemVersion];
	
	return userAgentString;
}


- (NSDictionary *)prepareHelloDictionaryWithRoomName:(NSString *)roomName
								 chanProtocolVersion:(NSString *)version
												 iid:(NSString *)iid
{
	NSMutableDictionary *hello = [NSMutableDictionary dictionary];
	[hello setObject:NSStr(kHelloKey) forKey:NSStr(kTypeKey)];
	
	if (iid.length > 0) {
		[hello setObject:iid forKey:NSStr(kIidKey)];
	}
	
	NSMutableDictionary *internal = [NSMutableDictionary dictionary];
	[internal setObject:version forKey:NSStr(kVersionKey)];
	
	NSString *userAgent = [self getUserAgentString];
	
	[internal setObject:userAgent forKey:NSStr(kUserAgentKey)];
	
	if ([roomName length] > 0) {
		[internal setObject:roomName forKey:NSStr(kIdKey)];
	}
	
	[hello setObject:internal forKey:NSStr(kHelloKey)];
	
	return [NSDictionary dictionaryWithDictionary:hello];
}


- (void)sayHelloToRoom:(NSString *)roomName
{
    if (roomName) {
        NSString *requestIid = [self generateIid];
        
        _lastHelloRequest = [SMChannelingRequest requestWithIid:requestIid type:NSStr(kHelloKey)];
        
        NSDictionary *hello = [self prepareHelloDictionaryWithRoomName:roomName
                                                   chanProtocolVersion:@"1.3.0"
                                                                   iid:requestIid];
        NSString *jsonHelloResponse = [hello JSONString];
        spreed_me_log("Hello room request: %s", [jsonHelloResponse cDescription]);
        [self sendMessage:jsonHelloResponse];
        [self sendStatusWithDisplayName:[UsersManager defaultManager].currentUser.displayName
                          statusMessage:[UsersManager defaultManager].currentUser.statusMessage
                                picture:[UsersManager defaultManager].currentUser.base64Image];
    } else {
        spreed_me_log("We do not send Hello room request. Room is nil.");
    }
}


#pragma mark - Rooms functionality

- (void)changeRoomTo:(NSString *)newRoomName
{
    [self exitFromCurrentRoom];
	
	SMRoom *newRoom = [[SMRoom alloc] init];
	newRoom.name = newRoomName;
	if ([newRoom.name isEqualToString:DefaultRoomId]) {
		newRoom.displayName = [SMRoom defaultRoomName];
	} else {
		newRoom.displayName = newRoomName;
	}
	
	[self sayHelloToRoom:newRoomName];
}


- (void)exitFromCurrentRoom
{
    SMRoom *exitingRoom = [UsersManager defaultManager].currentUser.room;
    [self sayBye];
    
    [UsersManager defaultManager].currentUser.room = nil;
    [[UsersManager defaultManager] removeRoomUsers];
    
    if (exitingRoom) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LocalUserDidLeaveRoomNotification
                                                            object:self
                                                          userInfo:@{kRoomUserInfoKey : exitingRoom,
                                                                     kRoomLeaveReasonUserInfoKey : kRoomLeaveReasonRoomRoomExit}];
    }
}


- (void)processRoomJoinErrorMessage:(NSDictionary *)errorMessage
{
	NSDictionary *innerMessage = [errorMessage objectForKey:NSStr(kDataKey)];
	
	NSString *iid = [errorMessage objectForKey:NSStr(kIidKey)];
	
	if ([_lastHelloRequest.iid isEqualToString:iid] && [_lastHelloRequest.type isEqualToString:NSStr(kHelloKey)]) {
		
		_lastHelloRequest = nil;
		
		NSString *code = [innerMessage objectForKey:NSStr(kCodeKey)];
		if ([code isEqualToString:NSStr(kErrorRoomCodeDefaultRoomDisabled)]) {
			
			[[NSNotificationCenter defaultCenter] postNotificationName:LocalUserDidReceiveDisabledDefaultRoomErrorNotification
																object:self
															  userInfo:nil];
			
		} else if ([code isEqualToString:NSStr(kErrorRoomCodeAuthorisationRequired)]) {
			spreed_me_log("Room error code: %s", [code cDescription]);
		} else if ([code isEqualToString:NSStr(kErrorRoomCodeAuthorisationNotRequired)]) {
			spreed_me_log("Room error code: %s", [code cDescription]);
		} else if ([code isEqualToString:NSStr(kErrorRoomCodeInvalidCredentials)]) {
			spreed_me_log("Room error code: %s", [code cDescription]);
		} else if ([code isEqualToString:NSStr(kErrorRoomCodeRoomJoinRequiresAccount)]) {
			spreed_me_log("Room error code: %s", [code cDescription]);
		} else {
			spreed_me_log("Unknown error code: %s", [code cDescription]);
		}
	}
}


#pragma mark - General message functionality/peer connection messaging

/*Peer connection messaging
 Now we send some messages from peer connection so just leave it unwrapped in specific method call. This might change in future.*/
- (void)sendMessage:(NSString *)message
{
	[_webSocketController send:message];
}


- (void)sendMessage:(NSString *)message	type:(NSString *)type to:(NSString *)recepientId
{
	[self sendMessage:message
				 type:type
				   to:recepientId
		transportType:kTransportTypeAuto];
}


- (void)sendMessage:(NSString *)message
			   type:(NSString *)type
				 to:(NSString *)recepientId
	  transportType:(ChannelingMessageTransportType)transportType
{
	if (!message) {message = @"";}
	if (!type) {type = @"";}
	if (!recepientId) {recepientId = @"";}
	std::string msg = std::string([message cStringUsingEncoding:NSUTF8StringEncoding]);
	std::string userId = std::string([recepientId cStringUsingEncoding:NSUTF8StringEncoding]);
	std::string type_cpp = std::string([type cStringUsingEncoding:NSUTF8StringEncoding]);
	
	switch (transportType) {
			
		case kWebsocketChannelingServer:
			_signallingHandler->SendMessage(type_cpp, msg);
		break;
			
		case kPeerToPeer:
			_signallingHandler->SendMessage(type_cpp, msg, userId);
		break;
			
		default:
		case kTransportTypeAuto:
			_signallingHandler->SendMessage(type_cpp, msg, userId);
		break;
	}
}


- (void)processMessageDict:(NSDictionary *)message transportType:(ChannelingMessageTransportType)transportType wrapperId:(NSString *)wrapperId
{
	NSString *type = [[message objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTypeKey)];
	spreed_me_log("Received message of type: %s", [type cDescription]);
	if ([type isEqualToString:NSStr(kSelfKey)])
	{
		[self receivedSelfMessage:message]; // note: we pass the message with outer structure
	}
	else if ([type isEqualToString:NSStr(kChatKey)])
	{
		[self receivedChatMessage:message transportType:transportType]; // note: we pass the message with outer structure
	}
	else if ([type isEqualToString:NSStr(kUsersKey)])
	{
		[self gotBuddyList:[message objectForKey:NSStr(kDataKey)]];
	}
	else if ([type isEqualToString:NSStr(kLeftKey)])
	{
		[self leftBuddy:[message objectForKey:NSStr(kDataKey)]];
	}
	else if ([type isEqualToString:NSStr(kJoinedKey)])
	{
		[self joinedBuddy:[message objectForKey:NSStr(kDataKey)]];
	}
	else if ([type isEqualToString:NSStr(kByeKey)])
	{
		[self receivedByeMessage:message]; // note: we pass the message with outer structure
	}
	else if ([type isEqualToString:NSStr(kStatusKey)])
	{
		[self updateBuddy:[message objectForKey:NSStr(kDataKey)]];
	}
	else if ([type isEqualToString:NSStr(kAliveKey)])
	{
		[self receivedAliveMessage:[message objectForKey:NSStr(kDataKey)]];
	}
	else if ([type isEqualToString:NSStr(kScreenShareKey)])
	{
		[self receivedScreenshareMessage:[message objectForKey:NSStr(kDataKey)] from:[message objectForKey:NSStr(kFromKey)]];
	}
	else if ([type isEqualToString:NSStr(kSessionsKey)])
	{
		[self receivedSessionsMessage:message]; // note: we pass the message with outer structure
	}
	else if ([type isEqualToString:NSStr(kErrorKey)])
	{
		[self receivedErrorMessage:message];
	}
	else if ([type isEqualToString:NSStr(kWelcomeKey)])
	{
		[self receivedWelcomeMessage:message];
	}
	else
	{
//		spreed_me_log("Unknown message type in ChannelingManager: %s", [type cDescription]);
	}
}


- (void)messageReceived:(id)message transportType:(ChannelingMessageTransportType)transportType wrapperId:(NSString *)wrapperId
{
	if ([message isKindOfClass:[NSString class]])
	{
		id serverResponse = [((NSString *)message) objectFromJSONString];
		
		if ([serverResponse isKindOfClass:[NSDictionary class]]) {
			[self processMessageDict:serverResponse transportType:transportType wrapperId:wrapperId];
		} else {
			spreed_me_log("Channeling message is not an object!");
		}
	} else {
		spreed_me_log("We have received channeling message which is not NSString. %s", [message cDescription]);
	}
}


- (void)signallingHandlerReceiveMessage:(id)message transportType:(ChannelingMessageTransportType)transportType wrapperId:(NSString *)wrapperId
{
	//TODO: we should probably check if this is a message from server and not p2p
	[self startKeepAliveTimer]; // we have received some message so server connection is alive. This call will restart timer.
	
	if ([message isKindOfClass:[NSString class]])
    {
		BOOL shouldPassToSignallinHandler = YES;
		
		NSDictionary *dict = [message objectFromJSONString];
		if (dict && [dict isKindOfClass:[NSDictionary class]]) {
			if ([dict objectForKey:NSStr(kAttestationTokenKey)]) {
				
				spreed_me_log("Attestation available message %s", [[[dict objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTypeKey)] cDescription]);
				
				if ([self shouldCheckUpUserFromAttestationTokenMessage:dict]) {
				
					NSString *from = [dict objectForKey:NSStr(kFromKey)];
					NSString *attToken = [dict objectForKey:NSStr(kAttestationTokenKey)];

					[self.usersManagementHandler channelingManager:self
							hasReceivedMessageWithAttestationToken:@{ NSStr(kIdKey) : from, NSStr(kAttestationTokenKey) :attToken }];
				}
			}
			
			shouldPassToSignallinHandler = [self shouldPassMessageToSignallingHandler:dict];
		}
		
		if (shouldPassToSignallinHandler) {
			// In this case message still can return to channeling manager!
			std::string msg = std::string([message cStringUsingEncoding:NSUTF8StringEncoding]);
			_signallingHandler->ReceiveMessage(msg, kWebsocketChannelingServer, std::string());
		} else {
			[self processMessageDict:dict transportType:transportType wrapperId:wrapperId];
		}
		
	} else {
		spreed_me_log("Signalling handler was going to receive message which is not String! Error!");
	}
}


- (BOOL)shouldPassMessageToSignallingHandler:(NSDictionary *)message
{
	BOOL answer = YES;
	
	NSString *type = [[message objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTypeKey)];

	if ([type isEqualToString:NSStr(kSelfKey)]		||
		[type isEqualToString:NSStr(kChatKey)]		||
		[type isEqualToString:NSStr(kUsersKey)]		||
		[type isEqualToString:NSStr(kLeftKey)]		||
		[type isEqualToString:NSStr(kJoinedKey)]	||
		[type isEqualToString:NSStr(kByeKey)]		||
		[type isEqualToString:NSStr(kStatusKey)]	||
		[type isEqualToString:NSStr(kAliveKey)]		||
		[type isEqualToString:NSStr(kScreenShareKey)]||
		[type isEqualToString:NSStr(kSessionsKey)])
	{
		answer = NO;
	}
	
	return answer;
}


- (BOOL)shouldCheckUpUserFromAttestationTokenMessage:(NSDictionary *)message
{
	BOOL answer = NO;

	NSString *messageType = [[message objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kTypeKey)];
	
	if ([messageType isEqualToString:NSStr(kChatKey)] ||
		[messageType isEqualToString:NSStr(kOfferKey)] ||
		[messageType isEqualToString:NSStr(kAnswerKey)])
	{
		answer = YES;
	}
	
	return answer;
}


- (NSString *)generateIid
{
	return [STRandomStringGenerator randomStringWithLength:20];
}


#pragma mark - Parsing stuff

- (void)gotBuddyList:(NSDictionary *)jsonBuddyDict
{
	if ([jsonBuddyDict isKindOfClass:[NSDictionary class]]) {
		[self.usersManagementHandler channelingManager:self
							   hasReceivedSessionsList:jsonBuddyDict];
	} else {
		spreed_me_log("Unexpected 'Users' message format!");
	}
}


- (void)joinedBuddy:(NSDictionary *)joinedBuddy
{
	if (joinedBuddy) {
		[self.usersManagementHandler channelingManager:self hasReceivedUserSessionJoinedEvent:joinedBuddy];
	}
}


- (void)leftBuddy:(NSDictionary *)leftBuddy
{
	if (leftBuddy) {
		[self.usersManagementHandler channelingManager:self hasReceivedUserSessionLeftEvent:leftBuddy];
	}
}


- (void)updateBuddy:(NSDictionary *)updatedBuddy
{
	if (updatedBuddy) {
		[self.usersManagementHandler channelingManager:self hasReceivedUserSessionStatusEvent:updatedBuddy];
	}
}


- (void)receivedAliveMessage:(NSDictionary *)aliveMessage
{
	if ([aliveMessage isKindOfClass:[NSDictionary class]])
	{
		// Alive message comes without data wrapper
		int64_t timeStamp = [[aliveMessage objectForKey:NSStr(kAliveKey)] longLongValue]; // int64_t is long long
		if (_lastAliveMessageTimeStamp != timeStamp) {
			spreed_me_log("_lastAliveMessageTimeStamp (%lld) != timeStamp (%lld). This means we have received strange alive message!", _lastAliveMessageTimeStamp, timeStamp);
		}
	} else {
		spreed_me_log("Incorrect alive message: %s", [aliveMessage cDescription]);
	}
}


- (void)receivedChatMessage:(NSDictionary *)chatMessage transportType:(ChannelingMessageTransportType)transportType
{
	if ([chatMessage isKindOfClass:[NSDictionary class]])
	{
		if ([self.observer respondsToSelector:@selector(channelingManager:didReceiveChatMessage:transportType:)]) {
			[self.observer channelingManager:self didReceiveChatMessage:chatMessage transportType:transportType];
		}
		
	} else {
		spreed_me_log("Incorrect chat message: %s", [chatMessage cDescription]);
	}
}


- (void)receivedByeMessage:(NSDictionary *)byeMessage
{
	NSString *to = [[byeMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kToKey)];
	NSString *from = [byeMessage objectForKey:NSStr(kFromKey)];
	
	NSString *reason = nil;
	
	NSDictionary *byeInternalDict = [[byeMessage objectForKey:NSStr(kDataKey)] objectForKey:NSStr(kByeKey)];
	if (byeInternalDict && [byeInternalDict isKindOfClass:[NSDictionary class]]) {
		reason = [byeInternalDict objectForKey:NSStr(kByeReasonKey)];
	}
	
	NSDictionary *userInfo = nil;
	
	userInfo = @{ByeFromNotificationUserInfoKey : from, ByeToNotificationUserInfoKey : to};
	
	if (reason && [reason isKindOfClass:[NSString class]]) {
		userInfo = @{ByeFromNotificationUserInfoKey : from, ByeToNotificationUserInfoKey : to, ByeReasonNotificationUserInfoKey : reason};
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ByeMessageReceivedNotification
														object:self
													  userInfo:userInfo];
	
	spreed_me_log("Received Bye message"/*: /n %s", [byeMessage cDescription]*/);
}


- (void)receivedScreenshareMessage:(NSDictionary *)screenshareMessage from:(NSString *)from
{
	NSDictionary *innerDict = [screenshareMessage objectForKey:NSStr(kScreenShareKey)];
	NSString *screenshareToken = [innerDict objectForKey:NSStr(kLCIdKey)];
	
	NSDictionary *userInfo = @{kScreenSharingUserSessionIdInfoKey : from, kScreenSharingTokenInfoKey : screenshareToken};
	
	[[NSNotificationCenter defaultCenter] postNotificationName:RemoteUserHasStartedScreenSharingNotification object:self userInfo:userInfo];
}


- (void)receivedSelfMessage:(NSDictionary *)selfMessage
{
	if ([self.observer respondsToSelector:@selector(channelingManager:didReceiveSelf:)]) {
		[self.observer channelingManager:self didReceiveSelf:selfMessage];
	}
}


// This method expects full message with outer structure (Data, Type, A, Iid, ...)
- (void)receivedSessionsMessage:(NSDictionary *)sessionsMessage
{
	NSDictionary *innerMessage = [sessionsMessage objectForKey:NSStr(kDataKey)];
	
	[self.usersManagementHandler channelingManager:self hasReceivedSessionsList:innerMessage];
}


// This method expects full message with outer structure (Data, Type, A, Iid, ...)
- (void)receivedErrorMessage:(NSDictionary *)errorMessage
{
	NSString *iid = [errorMessage objectForKey:NSStr(kIidKey)];
	
	spreed_me_log("Received error message: %s", [errorMessage cDescription]);
	
	if ([_lastHelloRequest.iid isEqualToString:iid] && [_lastHelloRequest.type isEqualToString:NSStr(kHelloKey)]) {
		[self processRoomJoinErrorMessage:errorMessage];
	}
}


// This method expects full message with outer structure (Data, Type, A, Iid, ...)
- (void)receivedWelcomeMessage:(NSDictionary *)message
{
	// Iid should be always present in 'Welcome' message.
	NSString *iid = [message objectForKey:NSStr(kIidKey)];
	
	if ([_lastHelloRequest.iid isEqualToString:iid] && [_lastHelloRequest.type isEqualToString:NSStr(kHelloKey)]) {
		
		_lastHelloRequest = nil; // clean up last request
		
		NSDictionary *innerMessage = [message objectForKey:NSStr(kDataKey)];
		
		NSDictionary *roomDict = [innerMessage objectForKey:NSStr(kRoomKey)];
		if (roomDict) {
			
			SMRoom *room = [SMRoom new];
			room.name = [roomDict objectForKey:NSStr(kNameKey)];
			room.displayName = room.name;
			
			[UsersManager defaultManager].currentUser.room = room;
			[[UsersManager defaultManager] saveCurrentUser];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:LocalUserDidJoinRoomNotification
																object:nil
															  userInfo:@{kRoomUserInfoKey : room}];
			
			NSArray *users = [innerMessage objectForKey:NSStr(kUsersKey)];
			if (users) {
				// simulate users as in 'Users' request
				[self.usersManagementHandler channelingManager:self
									   hasReceivedSessionsList:@{NSStr(kTypeKey): NSStr(kUsersKey),
																 NSStr(kUsersKey) : users}];
			}
		} else {
			spreed_me_log("There is no Room dictionary in Welcome message!");
		}
	} else {
		spreed_me_log("This is unregistered welcome message. This can happen if we send 2 change room requests and the second change room request is sent faster than receiving response to first.");
	}
}


@end
