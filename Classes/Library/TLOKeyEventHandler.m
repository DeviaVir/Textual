/* ********************************************************************* 
                  _____         _               _
                 |_   _|____  _| |_ _   _  __ _| |
                   | |/ _ \ \/ / __| | | |/ _` | |
                   | |  __/>  <| |_| |_| | (_| | |
                   |_|\___/_/\_\\__|\__,_|\__,_|_|

 Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
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

#import <objc/objc-runtime.h>

@interface TLOKeyEventHandler ()
@property (nonatomic, strong) NSMutableDictionary *codeHandlerMap;
@property (nonatomic, strong) NSMutableDictionary *characterHandlerMap;
@end

@implementation TLOKeyEventHandler

- (instancetype)init
{
	if ((self = [super init])) {
		self.codeHandlerMap = [NSMutableDictionary new];
		self.characterHandlerMap = [NSMutableDictionary new];
	}
	
	return self;
}

- (void)registerSelector:(SEL)selector key:(NSInteger)code modifiers:(NSUInteger)mods
{
	NSNumber *modsKey = @(mods);
	
	NSMutableDictionary *map = self.codeHandlerMap[modsKey];
	
	if (NSObjectIsEmpty(map)) {
		map = [NSMutableDictionary dictionary];
		
		self.codeHandlerMap[modsKey] = map;
	}
	
	map[@(code)] = NSStringFromSelector(selector);
}

- (void)registerSelector:(SEL)selector character:(UniChar)c modifiers:(NSUInteger)mods
{
	NSNumber *modsKey = @(mods);
	
	NSMutableDictionary *map = self.characterHandlerMap[modsKey];
	
	if (NSObjectIsEmpty(map)) {
		map = [NSMutableDictionary dictionary];
		
		self.characterHandlerMap[modsKey] = map;
	}
	
	map[@(c)] = NSStringFromSelector(selector);
}

- (void)registerSelector:(SEL)selector characters:(NSRange)characterRange modifiers:(NSUInteger)mods
{
	NSNumber *modsKey = @(mods);
	
	NSMutableDictionary *map = self.characterHandlerMap[modsKey];
	
	if (NSObjectIsEmpty(map)) {
		map = [NSMutableDictionary dictionary];
		
		self.characterHandlerMap[modsKey] = map;
	}
	
	NSInteger from = characterRange.location;
	
	NSInteger to = NSMaxRange(characterRange);
	
	for (NSInteger i = from; i < to; ++i) {
		map[@(i)] = NSStringFromSelector(selector);
	}
}

- (BOOL)processKeyEvent:(NSEvent *)e
{
	NSTextInputContext *im = [NSTextInputContext currentInputContext];

	if (im && [[im client] markedRange].length > 0) {
		return NO;
	}
	
	NSUInteger m = ([e modifierFlags] & (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask));
	
	NSNumber *modsKey = @(m);
	
	NSMutableDictionary *codeMap = self.codeHandlerMap[modsKey];
	
	if (codeMap) {
		NSString *selectorName = codeMap[@([e keyCode])];

		if (selectorName) {
			objc_msgSend(self.target, NSSelectorFromString(selectorName), e);
			
			return YES;
		}
	}
	
	NSMutableDictionary *characterMap = self.characterHandlerMap[modsKey];
	
	if (characterMap) {
		NSString *str = [[e charactersIgnoringModifiers] lowercaseString];
		
		if (NSObjectIsNotEmpty(str)) {
			NSString *selectorName = characterMap[@([str characterAtIndex:0])];
			
			if (selectorName) {
				objc_msgSend(self.target, NSSelectorFromString(selectorName), e);
				
				return YES;
			}
		}
	}
	
	return NO;
}

@end
