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

#import "STByteCount.h"

@class SMWebSocketController;

@protocol SMWebSocketMessagesReceiver <NSObject>
@required
- (void)webSocketController:(SMWebSocketController *)wsController didReceiveMessage:(id)message;

@end

@protocol SMWebSocketControllerDelegate <NSObject>
@required
- (void)webSocketControllerDidOpen:(SMWebSocketController *)wsController;
- (void)webSocketController:(SMWebSocketController *)wsController didFailWithError:(NSError *)error;
- (void)webSocketController:(SMWebSocketController *)wsController didReceiveMessage:(id)message;
- (void)webSocketController:(SMWebSocketController *)wsController didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@optional
- (BOOL)webSocketController:(SMWebSocketController *)wsController shouldTrustServer:(SecTrustRef)serverTrust;

@end


@interface SMWebSocketController : NSObject

@property (nonatomic, weak) id<SMWebSocketMessagesReceiver> messageReceiver;
@property (nonatomic, weak) id<SMWebSocketControllerDelegate> delegate;

@property (nonatomic, readwrite) BOOL spreedMeMode;

@property (nonatomic, readonly, copy) NSString *currentServer;

@property (nonatomic, readonly) STByteCount bytesSent;
@property (nonatomic, readonly) STByteCount bytesReceived;


- (void)send:(id)message;

- (void)closeWebSocket;
- (void)connectWithURL:(NSURL *)serverURL;
- (void)connectWithURLRequest:(NSURLRequest *)urlRequest;
- (void)setupWebSocketBeforeConnecting; // Exposed here only for subclussing purposes. Shouldn't be called directly!

- (SSLCipherSuite)negotiatedCipherSuite;

- (void)resetByteCount;


@end
