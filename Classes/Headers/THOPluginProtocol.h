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

/* All THOPluginProtocol messages are called within the primary class of a plugin and
 no where else. The primary class can be defined in the Info.plist of your bundle. The
 primary class acts similiar to an application delegate whereas it is responsible for 
 the lifetime management of your plugin. */

/* Each plugin has access to the global variables [self worldController] and 
 [self masterController] which both have unrestricted access to every component of 
 Textual. There is no need to store pointers in your plugin for these. They are always
 available just by calling the above mentioned method names. */

#pragma mark -
#pragma mark Localization

/* TPILocalizedString allows a plugin to use localized text within the plugin itself
 using Textual's own API. TPILocalizedString takes a two paramaters and that is the
 key to look inside the .strings file for and the formatting values.  */
/* This call expects the localized strings to be inside the filename "BasicLanguage.strings"
 Any other name will not work unless the actual Cocoa APIs for accessing localized strings
 is used in place of these. */
#define TPIBundleFromClass()				[NSBundle bundleForClass:[self class]]

#define TPILocalizedString(k, ...)		TXLocalizedStringAlternative(TPIBundleFromClass(), k, ##__VA_ARGS__)

@protocol THOPluginProtocol <NSObject>

@optional

#pragma mark -
#pragma mark Subscribed Events 

/*!
 * @return An NSArray containing a lowercase list of commands that this plugin 
 * will support as user input from the main text field.
 *
 * @warning If a plugin tries to add a command already built into Textual onto 
 * this list, it will not work.
 *
 * @warning It is possible, but unlikely, that another plugin the end user has 
 * loaded is subscribed to the same command. When that occurs, each plugin 
 * subscribed to the command will be informed of when the command is performed.
 *
 * @warning To avoid conflicts, a plugin cannot subscribe to a command already 
 * defined by a script. If a script and a plugin both share the same command, then 
 * neither will be executed and an error will be printed to the OS X console.
 *
 * @warning If a command is a number (0-9), then insert it into the array as an NSString.
 */
- (NSArray *)subscribedUserInputCommands;

/*!
 * @return An NSArray containing a lowercase list of commands that this plugin 
 * will support as server input.
 *
 * @warning If a raw numeric (a number) is being asked for, then insert it into 
 * the array as an NSString.
 */
- (NSArray *)subscribedServerInputCommands;

/*!
 * This method is invoked when a subscribed user input command requires processing 
 * because the end user has used it.
 *
 * @param client The client responsible for the event
 * @param commandString The name of the command used by the end user
 * @param messageString Data that follows commandString
 */
- (void)userInputCommandInvokedOnClient:(IRCClient *)client commandString:(NSString *)commandString messageString:(NSString *)messageString;

/*!
 * This method is invoked when a subscribed server input command requires processing 
 * when data is received.
 *
 * The dictionaries sent as part of this method are guaranteed to always contain the 
 * same key pair. When a specific key does not have a value, NSNull is used as its value.
*
 * @param client The client responsible for the event
 * @param senderDict A dictionary which contains information related to the sender
 * @param messageDict A dictionary which contains information related to the incoming data
 */
- (void)didReceiveServerInputOnClient:(IRCClient *)client senderInformation:(NSDictionary *)senderDict messageInformation:(NSDictionary *)messageDict;

#pragma mark -
#pragma mark Initialization

/*!
 * This method is invoked very early on. It occurs once the principal class of 
 * the plugin has been allocated and is guaranteed to be the first call home that
 * a plugin will receive from Textual.
 */
- (void)pluginLoadedIntoMemory;

/*!
 * This method is invoked when the plugin is being unloaded during application 
 * termination.
 */
- (void)pluginWillBeUnloadedFromMemory;

#pragma mark -
#pragma mark Preferences Pane

/*!
 * @return The NSView used by the Preferences dialog to allow configuration of 
 * the plugin.
 * 
 * A width of 567 pixels and a minimum height of 406 pixels will be enforced for 
 * the returned view.
 */
- (NSView *)pluginPreferencesPaneView;

/*!
 * @return An NSString which is used by the Preferences dialog to create a new 
 * entry in the navigation list.
 */
- (NSString *)pluginPreferencesPaneMenuItemName;

#pragma mark -
#pragma mark Renderer Events

/*!
 * This method is invoked when a message has been added to the Document Object Model (DOM)
 * of logController
 *
 * Depending on the type of message added, the set of keys available within the messageInfo
 * dictionary will vary. See the set of THOPluginProtocolDidPostNewMessage* constants in
 * the THOPluginProtocol.h header for a list of possible values.
 *
 * @warning It is NOT recommended to do any heavy work when isThemeReload or isHistoryReload
 * is YES as these events have thousands of messages being processed at the same time.
 * 
 * @warning This method is invoked on an asynchronous background dispatch queue. Not the 
 * main thread. It is extremely important to remember this because WebKit will throw an
 * exception if it is not interacted with on the main thread.
 *
 * @param logController The view responsible for the event
 * @param messageInfo A dictionary which contains information about the message
 * @param isThemeReload Whether or not the message was posted as part of a theme reload
 * @param isHistoryReload Whether or not the message was posted as part of playback on application start
*/
- (void)didPostNewMessageForViewController:(TVCLogController *)logController
							   messageInfo:(NSDictionary *)messageInfo
							 isThemeReload:(BOOL)isThemeReload
						   isHistoryReload:(BOOL)isHistoryReload;

/*!
 * The unique hash of the message which can be used to access the message.
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageLineNumberAttribute;

/*!
 * The nickname of the person and/or server responsible for producing the message.
 * This value may be empty. Not every event on IRC will have a sender value.
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageSenderNicknameAttribute;

/*!
 * Integer representation of TVCLogLineType
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageLineTypeAttribute;

/*!
 * Integer representation of TVCLogLineMemberType
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageMemberTypeAttribute;

/*!
 * Date & time shown left of the message in the chat view.
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageReceivedAtTimeAttribute;

/*!
 * Array of ranges (NSRange) of text in the message body believed to be a URL. 
 * 
 * Each entry in this array is another array containing two indexes. First index (0) is 
 * the range in THOPluginProtocolDidPostNewMessageMessageBodyAttribute that the URL was at. 
 * The second index (1) is the URL that was found. The URL may differ from the value in the 
 * range as URL schemes may have been appended. For example, the text at the given range may 
 * be "www.example.com" whereas the entry at index 1 is "http://www.example.com"
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageListOfHyperlinksAttribute;

/*!
 * List of users from the channel that appear in the message;
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageListOfUsersAttribute;

/*!
 * The contents of the message visible to the end user, minus any formatting.
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageMessageBodyAttribute;

/*!
 * Whether or not a highlight word was matched in the message body.
 */
TEXTUAL_EXTERN NSString * const THOPluginProtocolDidPostNewMessageKeywordMatchFoundAttribute;

#pragma mark -

/*!
 * This method is invoked prior to a message being converted to its HTML equivalent.
 *
 * This gives a plugin the chance to modify the text that will be displayed for a certain
 * message by replacing one or more segments of it.
 *
 * Returning nil or a string with zero length from this method will indicate that there is
 * no interest in modifying newMessage.
 *
 * There is no way to inform the renderer that you do not want a specific value of newMessage
 * shown to the end user. Use the intercept* methods for this purpose.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method does not 
 * stop for the first result returned which means that value being passed may have been 
 * modified by a plugin above the one being talked to.
 *
 * @warning Under no circumstances should you insert HTML at this point. Doing so will result 
 * in undefined behavior.
 * 
 * @return The original and/or modified copy of newMessage
 *
 * @param newMessage An unedited copy of the message being rendered
 * @param viewController The view responsible for the event
 * @param lineType The line type of the message being rendered
 * @param viewController The member type of the message being rendered
 */
- (NSString *)willRenderMessage:(NSString *)newMessage
			  forViewController:(TVCLogController *)viewController
					   lineType:(TVCLogLineType)lineType
					 memberType:(TVCLogLineMemberType)memberType;

#pragma mark -

/*!
 * @return A URL that can be shown as an inline image in relation to resource or nil to ignore.
 *
 * @discussion The return value must be a valid URL for an image file if non-nil. 
 * Textual validates the return value by attempting to create an instance of NSURL 
 * with it. If NSURL returns a nil object, then it is certain that a plugin returned 
 * a bad value.
 *
 * Textual uses the first non-nil, valid URL returned by any plugin. It does not
 * chain the responses similar to other methods defined by the THOPluginProtocol
 * protocol.
 *
 * @param resource A URL that was detected in a message being rendered.
 */
- (NSString *)processInlineMediaContentURL:(NSString *)resource;

#pragma mark -
#pragma mark Input Manipulation

/*!
 * This method allows a plugin to modify and/or completely ignore incoming data from
 * the server before any action can be taken on it by Textual.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method 
 * does not stop for the first result returned which means that value being passed may 
 * have been modified by a plugin above the one being talked to.
 *
 * @warning Textual does not perform validation against the instance of IRCMessage that 
 * is returned which means that if Textual tries to access specific information which has
 * been improperly modified or removed, the entire application may crash.
 * 
 * @return The original and/or modified copy of IRCMessage or nil to prevent the data from being processed altogether.
 *
 * @param input An instance of IRCMessage which is the container class for parsed incoming data
 * @param client The client responsible for the event
 */
- (IRCMessage *)interceptServerInput:(IRCMessage *)input for:(IRCClient *)client;

/*!
 * This method allows a plugin to modify and/or completely ignore text entered into the
 * main text field of Textual by the end user. This method is invoked once the user has
 * hit return on the text field to submit whatever its value may be.
 *
 * @warning This method is invoked on each plugin in the order loaded. This method
 * does not stop for the first result returned which means that value being passed may
 * have been modified by a plugin above the one being talked to.
 * 
 * @return The original and/or modified copy of input or nil to prevent the data from being processed altogether.
 * 
 * @param input Depending on whether the value of the text field was submitted 
    programmatically or by the user directly interacting with it, this value can be an 
    instance of NSString or NSAttributedString.
 * @param client The client responsible for the event
 */
- (id)interceptUserInput:(id)input command:(NSString *)command;

#pragma mark -
#pragma mark Reserved Calls

/* The behavior of this method call is undefined. It exists for internal
 purposes for the plugins packaged with Textual by default. It is not
 recommended to use it, or try to understand it. */
- (NSDictionary *)pluginOutputDisplayRules;

#pragma mark -
#pragma mark Deprecated

/* Even though these methods are deprecated, they will still function 
 as they always have. They will however be removed in a future release. */
- (void)pluginLoadedIntoMemory:(IRCWorld *)world TEXTUAL_DEPRECATED("Use -pluginLoadedIntoMemory instead");
- (void)pluginUnloadedFromMemory TEXTUAL_DEPRECATED("Use -pluginWillBeUnloadedFromMemory instead");

- (NSArray *)pluginSupportsUserInputCommands TEXTUAL_DEPRECATED("Use -subscribedUserInputCommands instead");
- (NSArray *)pluginSupportsServerInputCommands TEXTUAL_DEPRECATED("Use -subscribedServerInputCommands instead");

- (NSView *)preferencesView TEXTUAL_DEPRECATED("Use -pluginPreferencesPaneView instead");
- (NSString *)preferencesMenuItemName TEXTUAL_DEPRECATED("Use -pluginPreferencesPaneMenuItemName instead");

- (void)messageSentByUser:(IRCClient *)client
				  message:(NSString *)messageString
				  command:(NSString *)commandString TEXTUAL_DEPRECATED("Use -userInputCommandInvokedOnClient:commandString:messageString: instead");

- (void)messageReceivedByServer:(IRCClient *)client
						 sender:(NSDictionary *)senderDict
						message:(NSDictionary *)messageDict TEXTUAL_DEPRECATED("Use -didReceiveServerInputOnClient:senderInformation:messageInformation: instead");
@end
