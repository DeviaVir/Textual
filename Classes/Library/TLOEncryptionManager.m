/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
        Please see Acknowledgements.pdf for additional information.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Textual and/or "Codeux Software, LLC", nor the 
      names of its contributors may be used to endorse or promote products 
      derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.

 *********************************************************************** */

#import "TextualApplication.h"

#define notEqual		!=

#define _accountNameSeparatorSequence		@"@"

NSString * const TLOEncryptionManagerWillStartGeneratingPrivateKeyNotification = @"TLOEncryptionManagerWillStartGeneratingPrivateKeyNotification";
NSString * const TLOEncryptionManagerDidFinishGeneratingPrivateKeyNotification = @"TLOEncryptionManagerDidFinishGeneratingPrivateKeyNotification";

@interface TLOEncryptionManagerEncodingDecodingObject : NSObject
// Properties that should be manipulated to provide context information
@property (nonatomic, copy) TLOEncryptionManagerEncodingDecodingCallbackBlock encodingCallback;
@property (nonatomic, copy) TLOEncryptionManagerInjectCallbackBlock injectionCallback;
@property (nonatomic, copy) NSString *messageFrom;
@property (nonatomic, copy) NSString *messageTo;
@property (nonatomic, copy) NSString *messageBody; // unencrypted value

// Properties that are assigned by the delegate methods of OTRKit
@property (nonatomic, assign) OTRKitMessageEvent lastEvent;
@end

@implementation TLOEncryptionManager

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
	if ((self = [super init])) {
		[self setupEncryptionManager];

		return self;
	}

	return nil;
}

- (NSString *)pathToStoreEncryptionSecrets
{
	NSString *cachesFolder = [TPCPathInfo applicationSupportFolderPath];

	NSString *dest = [cachesFolder stringByAppendingPathComponent:@"/Encryption Components/"];

	if ([RZFileManager() fileExistsAtPath:dest] == NO) {
		[RZFileManager() createDirectoryAtPath:dest withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	return dest;
}

- (void)setupEncryptionManager
{
	OTRKit *otrKit = [OTRKit sharedInstance];

	[otrKit setDelegate:self];

	[otrKit setupWithDataPath:[self pathToStoreEncryptionSecrets]];

	[self prepareEncryptionComponentPath:[otrKit privateKeyPath]];
	[self prepareEncryptionComponentPath:[otrKit fingerprintsPath]];
	[self prepareEncryptionComponentPath:[otrKit instanceTagsPath]];

	NSURL *componentPathURL = [NSURL fileURLWithPath:[self pathToStoreEncryptionSecrets] isDirectory:YES];

	NSError *attributesChangeError = nil;

	if ([componentPathURL setResourceValue:@(YES) forKey:NSURLIsHiddenKey error:&attributesChangeError] == NO) {
		LogToConsole(@"Failed to hide the folder at the path '%@': %@", componentPathURL, [attributesChangeError localizedDescription]);
	}

	[otrKit setMaximumProtocolSize:[self otrKitProtocolMaximumMessageSize]
					   forProtocol:[self otrKitProtocol]];
}

- (void)prepareEncryptionComponentPath:(NSString *)path
{
	/* Create the path if it does not already exist. */
	if ([RZFileManager() fileExistsAtPath:path] == NO) {
		NSError *writeError = nil;

		if ([NSStringEmptyPlaceholder writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError] == NO) {
			LogToConsole(@"Failed to create base file for encryption component at path: %@", [writeError localizedDescription]);
		}
	}

	/* Files are stored in a location that is accessible to Time Machine
	 which means we must mark the files to not be backed up. */
	NSURL *pathURL = [NSURL fileURLWithPath:path isDirectory:NO];

	NSError *attributesChangeError = nil;

	if ([pathURL setResourceValue:@(YES) forKey:NSURLIsExcludedFromBackupKey error:&attributesChangeError] == NO) {
		LogToConsole(@"Failed to exclude the files at the path '%@' from backup: %@", pathURL, [attributesChangeError localizedDescription]);
	}
}

#pragma mark -
#pragma mark Account Name Information

- (NSString *)accountNameWithUser:(NSString *)nickname onClient:(IRCClient *)client
{
	/* A common theme of this class is an extensive use of asserts. Encryption is very
	 serious so we fail at any hint of a bad input value so that the end user does not
	 suffer by software doing something it should not. */

	NSParameterAssert(client notEqual nil);
	NSParameterAssert(nickname notEqual nil);

	return [NSString stringWithFormat:@"%@%@%@", nickname, _accountNameSeparatorSequence, [client uniqueIdentifier]];
}

- (NSString *)nicknameFromAccountName:(NSString *)accountName
{
	NSParameterAssert(accountName notEqual nil);

	NSRange sequenceRange = [accountName rangeOfString:_accountNameSeparatorSequence options:NSBackwardsSearch];

	NSInteger sliceRange = sequenceRange.location;

	NSAssert((sliceRange > 0), @"Bad accountName value");
	NSAssert((sliceRange notEqual NSNotFound), @"Bad accountName value");

	NSString *nickname = [accountName substringToIndex:sliceRange];

	return nickname;
}

- (IRCClient *)connectionFromAccountName:(NSString *)accountName
{
	NSParameterAssert(accountName notEqual nil);

	NSRange sequenceRange = [accountName rangeOfString:_accountNameSeparatorSequence options:NSBackwardsSearch];

	NSInteger sliceRange = (sequenceRange.location + [_accountNameSeparatorSequence length]);

	NSAssert((sliceRange > 0), @"Bad accountName value");
	NSAssert((sliceRange < [accountName length]), @"Bad accountName value");
	NSAssert((sequenceRange.location notEqual NSNotFound), @"Bad accountName value");

	NSString *clientIdentifier = [accountName substringFromIndex:sliceRange];

	return [worldController() findClientById:clientIdentifier];
}

#pragma mark -
#pragma mark Starting Encryption & Stopping Encryption

- (void)beginConversationWith:(NSString *)messageTo from:(NSString *)messageFrom
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);

	[[OTRKit sharedInstance] initiateEncryptionWithUsername:messageTo
												accountName:messageFrom
												   protocol:[self otrKitProtocol]];
}

- (void)endConversationWith:(NSString *)messageTo from:(NSString *)messageFrom
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);

	[[OTRKit sharedInstance] disableEncryptionWithUsername:messageTo
											   accountName:messageFrom
												  protocol:[self otrKitProtocol]];
}

#pragma mark -
#pragma mark Socialist Millionaire

- (void)sendSocialistMillionaireProblem:(NSString *)messageTo from:(NSString *)messageFrom secret:(NSString *)problemSecret
{
	[self sendSocialistMillionaireProblem:messageTo from:messageFrom secret:problemSecret question:nil];
}

- (void)sendSocialistMillionaireProblem:(NSString *)messageTo from:(NSString *)messageFrom secret:(NSString *)problemSecret question:(NSString *)problemQuestion
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);
	NSParameterAssert(problemSecret notEqual nil);

	if (problemQuestion == nil) {
		[[OTRKit sharedInstance] initiateSMPForUsername:messageTo
											accountName:messageFrom
											   protocol:[self otrKitProtocol]
												 secret:problemSecret];
	} else {
		[[OTRKit sharedInstance] initiateSMPForUsername:messageTo
											accountName:messageFrom
											   protocol:[self otrKitProtocol]
											   question:problemQuestion
												 secret:problemSecret];
	}
}

- (void)replyToSocialistMillionaireProblem:(NSString *)messageTo from:(NSString *)messageFrom secret:(NSString *)problemSecret
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);
	NSParameterAssert(problemSecret notEqual nil);

	[[OTRKit sharedInstance] respondToSMPForUsername:messageTo
										 accountName:messageFrom
											protocol:[self otrKitProtocol]
											  secret:problemSecret];
}

#pragma mark -
#pragma mark Encryption & Decryption

- (void)decryptMessage:(NSString *)messageBody from:(NSString *)messageFrom to:(NSString *)messageTo decodingCallback:(TLOEncryptionManagerEncodingDecodingCallbackBlock)decodingCallback
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);
	NSParameterAssert(messageBody notEqual nil);

	TLOEncryptionManagerEncodingDecodingObject *messageObject = [TLOEncryptionManagerEncodingDecodingObject new];

	[messageObject setMessageTo:messageTo];
	[messageObject setMessageFrom:messageFrom];
	[messageObject setMessageBody:messageBody];

	[messageObject setEncodingCallback:decodingCallback];

	[[OTRKit sharedInstance] decodeMessage:messageBody
								  username:messageFrom
							   accountName:messageTo
								  protocol:[self otrKitProtocol]
									   tag:messageObject];
}

- (void)encryptMessage:(NSString *)messageBody from:(NSString *)messageFrom to:(NSString *)messageTo encodingCallback:(TLOEncryptionManagerEncodingDecodingCallbackBlock)encodingCallback injectionCallback:(TLOEncryptionManagerInjectCallbackBlock)injectionCallback
{
	NSParameterAssert(messageTo notEqual nil);
	NSParameterAssert(messageFrom notEqual nil);
	NSParameterAssert(messageBody notEqual nil);

	TLOEncryptionManagerEncodingDecodingObject *messageObject = [TLOEncryptionManagerEncodingDecodingObject new];

	[messageObject setMessageTo:messageTo];
	[messageObject setMessageFrom:messageFrom];
	[messageObject setMessageBody:messageBody];

	[messageObject setEncodingCallback:encodingCallback];
	[messageObject setInjectionCallback:injectionCallback];

	[[OTRKit sharedInstance] encodeMessage:messageBody
									  tlvs:nil
								  username:messageTo
							   accountName:messageFrom
								  protocol:[self otrKitProtocol]
									   tag:messageObject];
}

#pragma mark -
#pragma mark Helper Methods

- (void)performBlockInRelationToAccountName:(NSString *)accountName block:(void (^)(NSString *nickname, IRCClient *client, IRCChannel *channel))block
{
	[self performBlockOnMainThread:^{
		NSString *nickname = [self nicknameFromAccountName:accountName];

		IRCClient *client = [self connectionFromAccountName:accountName];

		if (client == nil) {
			LogToConsole(@"-connectionFromAccountName: returned a nil value, failing");
		} else {
			IRCChannel *channel = [client findChannelOrCreate:nickname isPrivateMessage:YES];

			block(nickname, client, channel);
		}
	}];
}

- (NSString *)localizedStringForEvent:(OTRKitMessageEvent)event
{
	NSString *localeKey = nil;

#define _dv(event, localInt)		case (event): { localeKey = (localInt); break; }

	switch (event) {
			_dv(OTRKitMessageEventEncryptionRequired,				@"01")
			_dv(OTRKitMessageEventEncryptionError,					@"02")
			_dv(OTRKitMessageEventConnectionEnded,					@"03")
			_dv(OTRKitMessageEventSetupError,						@"04")
			_dv(OTRKitMessageEventMessageReflected,					@"05")
			_dv(OTRKitMessageEventMessageResent,					@"06")
			_dv(OTRKitMessageEventReceivedMessageNotInPrivate,		@"07")
			_dv(OTRKitMessageEventReceivedMessageUnreadable,		@"08")
			_dv(OTRKitMessageEventReceivedMessageMalformed,			@"09")
			_dv(OTRKitMessageEventLogHeartbeatReceived,				@"10")
			_dv(OTRKitMessageEventLogHeartbeatSent,					@"11")
			_dv(OTRKitMessageEventReceivedMessageGeneralError,		@"12")
			_dv(OTRKitMessageEventReceivedMessageUnencrypted,		@"13")
			_dv(OTRKitMessageEventReceivedMessageUnrecognized,		@"14")
			_dv(OTRKitMessageEventReceivedMessageForOtherInstance,	@"15")

		default:
		{
			break;
		}
	}

#undef _dv

	if (localeKey) {
		localeKey = [NSString stringWithFormat:@"BasicLanguage[1254][%@]", localeKey];
	}

	if (localeKey) {
		return TXTLS(localeKey);
	} else {
		return nil;
	}
}

- (BOOL)eventIsErrornous:(OTRKitMessageEvent)event
{
	switch (event) {
		case OTRKitMessageEventEncryptionError:
		case OTRKitMessageEventReceivedMessageGeneralError:
		case OTRKitMessageEventReceivedMessageMalformed:
		case OTRKitMessageEventReceivedMessageNotInPrivate:
		case OTRKitMessageEventReceivedMessageUnreadable:
		case OTRKitMessageEventReceivedMessageUnrecognized:
		{
			return YES;
		}
		default:
		{
			return NO;
		}
	}
}

- (void)presentMessage:(NSString *)message withAccountName:(NSString *)accountName
{
	[self performBlockInRelationToAccountName:accountName block:^(NSString *nickname, IRCClient *client, IRCChannel *channel) {
		[client print:channel
				 type:TVCLogLineOffTheRecordEncryptionStatusType
			 nickname:nil
		  messageBody:message
			  command:TVCLogLineDefaultRawCommandValue];
	}];
}

- (void)presentErrorMessage:(NSString *)errorMessage withAccountName:(NSString *)accountName
{
	[self presentMessage:errorMessage withAccountName:accountName];
}

#pragma mark -
#pragma mark Off-the-Record Kit Delegate

- (void)setEncryptionPolicy:(OTRKitPolicy)policy
{
	[[OTRKit sharedInstance] setOtrPolicy:policy];
}

- (NSString *)otrKitProtocol
{
	return @"prpl-irc";
}

- (int)otrKitProtocolMaximumMessageSize
{
	return 400; // Chosen by fair dice roll.
}

- (NSString *)maybeInsertProperNegotationMessge:(NSString *)message
{
	static NSRegularExpression *boundryRegex = nil;

	if (boundryRegex == nil) {
		NSString *boundryMatch = [NSString stringWithFormat:
			@"\\?OTRv?([0-9]+)\\?\n<b>(.*)</b> has requested an "
			@"<a href=\"https://otr.cypherpunks.ca/\">Off-the-Record "
			@"private conversation</a>.  However, you do not have a plugin "
			@"to support that.\nSee <a href=\"https://otr.cypherpunks.ca/\">"
			@"https://otr.cypherpunks.ca/</a> for more information."];

		boundryRegex = [NSRegularExpression regularExpressionWithPattern:boundryMatch options:0 error:NULL];
	}

	NSUInteger numMatches = [boundryRegex numberOfMatchesInString:message options:0 range:[message range]];

	if (numMatches == 1) {
		NSArray *messageComponents = [message componentsSeparatedByString:NSStringNewlinePlaceholder];

		return [NSString stringWithFormat:@"%@ %@", messageComponents[0], TXTLS(@"BasicLanguage[1255]")];
	} else {
		return message;
	}
}

- (void)otrKit:(OTRKit *)otrKit injectMessage:(NSString *)message username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag
{
	message = [self maybeInsertProperNegotationMessge:message];

	if (tag) {
		if ([tag isKindOfClass:[TLOEncryptionManagerEncodingDecodingObject class]]) {
			TLOEncryptionManagerEncodingDecodingObject *messageObject = tag;

			if ([messageObject injectionCallback]) {
				[messageObject injectionCallback](message);

				return; // Do not continue after callback block...
			}
		}
	}


	[self performBlockInRelationToAccountName:username block:^(NSString *nickname, IRCClient *client, IRCChannel *channel) {
		[client send:IRCPrivateCommandIndex("privmsg"), [channel name], message, nil];
	}];
}

- (void)otrKit:(OTRKit *)otrKit encodedMessage:(NSString *)encodedMessage wasEncrypted:(BOOL)wasEncrypted username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag error:(NSError *)error
{
	if (tag) {
		if ([tag isKindOfClass:[TLOEncryptionManagerEncodingDecodingObject class]]) {
			TLOEncryptionManagerEncodingDecodingObject *messageObject = tag;

			if ([tag encodingCallback]) {
				[tag encodingCallback]([messageObject messageBody], wasEncrypted);
			}
		}
	}
}

- (void)otrKit:(OTRKit *)otrKit decodedMessage:(NSString *)decodedMessage wasEncrypted:(BOOL)wasEncrypted tlvs:(NSArray *)tlvs username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag
{
	if (tag) {
		if ([tag isKindOfClass:[TLOEncryptionManagerEncodingDecodingObject class]]) {
			TLOEncryptionManagerEncodingDecodingObject *messageObject = tag;

			if ([messageObject encodingCallback]) {
				[messageObject encodingCallback](decodedMessage, wasEncrypted);
			}
		}
	}
}

- (void)otrKit:(OTRKit *)otrKit updateMessageState:(OTRKitMessageState)messageState username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol
{
	[self performBlockInRelationToAccountName:username block:^(NSString *nickname, IRCClient *client, IRCChannel *channel) {
		[channel setEncryptionState:messageState];
	}];

	NSString *statusChangedMessage = nil;

	if (messageState ==  OTRKitMessageStateEncrypted) {
		BOOL isVerified = [[OTRKit sharedInstance] activeFingerprintIsVerifiedForUsername:username
																			  accountName:accountName
																				 protocol:[self otrKitProtocol]];

		if (isVerified) {
			statusChangedMessage = @"BasicLanguage[1253][02]";
		} else {
			statusChangedMessage = @"BasicLanguage[1253][01]";
		}
	} else if (messageState == OTRKitMessageStateFinished ||
			   messageState == OTRKitMessageStatePlaintext)
	{
		statusChangedMessage = @"BasicLanguage[1256]";
	}

	if (statusChangedMessage) {
		[self presentMessage:TXTLS(statusChangedMessage) withAccountName:username];
	}
}

- (BOOL)otrKit:(OTRKit *)otrKit isUsernameLoggedIn:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol
{
	__block BOOL userIsActive = NO;

	[self performBlockInRelationToAccountName:username block:^(NSString *nickname, IRCClient *client, IRCChannel *channel) {
		userIsActive = [channel isActive];
	}];

	return userIsActive;
}

- (void)otrKit:(OTRKit *)otrKit showFingerprintConfirmationForTheirHash:(NSString *)theirHash ourHash:(NSString *)ourHash username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol
{
	LogToConsole(@"-");
}

- (void)otrKit:(OTRKit *)otrKit handleSMPEvent:(OTRKitSMPEvent)event progress:(double)progress question:(NSString *)question username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol
{
	LogToConsole(@"-");
}

- (void)otrKit:(OTRKit *)otrKit handleMessageEvent:(OTRKitMessageEvent)event message:(NSString *)message username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol tag:(id)tag error:(NSError *)error
{
	if (tag) {
		if ([tag isKindOfClass:[TLOEncryptionManagerEncodingDecodingObject class]]) {
			TLOEncryptionManagerEncodingDecodingObject *messageObject = tag;

			[messageObject setLastEvent:event];

			if ([self eventIsErrornous:event]) {
				[self presentErrorMessage:[self localizedStringForEvent:event] withAccountName:username];
			}
		}
	}
}

- (void)otrKit:(OTRKit *)otrKit receivedSymmetricKey:(NSData *)symmetricKey forUse:(NSUInteger)use useData:(NSData *)useData username:(NSString *)username accountName:(NSString *)accountName protocol:(NSString *)protocol
{
	;
}

- (void)otrKit:(OTRKit *)otrKit willStartGeneratingPrivateKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol
{
	;
}

- (void)otrKit:(OTRKit *)otrKit didFinishGeneratingPrivateKeyForAccountName:(NSString *)accountName protocol:(NSString *)protocol error:(NSError *)error
{
	;
}

@end

#pragma mark -
#pragma mark Dummy Class

@implementation TLOEncryptionManagerEncodingDecodingObject
@end
