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

@interface TDCHighlightListSheet ()
@property (nonatomic, copy) NSArray *highlightList;
@property (nonatomic, weak) IBOutlet NSTextField *headerTitleTextField;
@property (nonatomic, weak) IBOutlet TVCBasicTableView *highlightListTable;

- (IBAction)onClearList:(id)sender;
@end

@implementation TDCHighlightListSheet

- (instancetype)init
{
    if ((self = [super init])) {
		[RZMainBundle() loadNibNamed:@"TDCHighlightListSheet" owner:self topLevelObjects:nil];
    }
    
    return self;
}

- (void)releaseTableViewDataSourceBeforeSheetClosure
{
	[self.highlightListTable setDelegate:nil];
	[self.highlightListTable setDataSource:nil];
}

- (void)show
{
	IRCClient *currentNetwork = [worldController() findClientById:self.clientID];

	NSString *network = [currentNetwork altNetworkName];

	NSString *headerTitle = [NSString stringWithFormat:[self.headerTitleTextField stringValue], network];

	[self.headerTitleTextField setStringValue:headerTitle];

	[self.highlightListTable setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
	
    [self startSheet];
	[self reloadTable];
}

- (void)onClearList:(id)sender
{
	IRCClient *currentNetwork = [worldController() findClientById:self.clientID];
	
	[currentNetwork setCachedHighlights:@[]];

    [self reloadTable];
}

#pragma mark -
#pragma mark NSTableView Delegate

- (void)reloadTable
{
	IRCClient *currentNetwork = [worldController() findClientById:self.clientID];

	[self setHighlightList:[currentNetwork cachedHighlights]];
	
    [self.highlightListTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)sender
{
	return [self.highlightList count];
}

- (CGFloat)tableView:(NSTableView *)aTableView heightOfRow:(NSInteger)row
{
	NSTableColumn *tableColumn = [aTableView tableColumnWithIdentifier:@"messageContents"];

	NSTableCellView *cellView = (id)[self tableView:aTableView viewForTableColumn:tableColumn row:row];

	NSCell *cellViewTextFieldCell = [[cellView textField] cell];

	NSSize matchedSize = [cellViewTextFieldCell cellSizeForBounds:NSMakeRect(0, 0, [tableColumn width], CGFLOAT_MAX)];

	return MAX(matchedSize.height, [aTableView rowHeight]);
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSTableCellView *result = [tableView makeViewWithIdentifier:[tableColumn identifier] owner:self];

	NSArray *item = self.highlightList[row];

	NSString *stringValue = nil;

	if ([[tableColumn identifier] isEqualToString:@"channelName"]) {
		stringValue = item[0];
	} else if ([[tableColumn identifier] isEqualToString:@"timeValue"]) {
		NSInteger timeInterval = [item integerAtIndex:1];

		NSString *timestring = TXHumanReadableTimeInterval([NSDate secondsSinceUnixTimestamp:timeInterval], YES, 0);

		stringValue = BLS(1216, timestring);
	} else {
		stringValue = item[2];
	}

	[[result textField] setStringValue:stringValue];

	return result;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)note
{
	[self releaseTableViewDataSourceBeforeSheetClosure];

	if ([self.delegate respondsToSelector:@selector(highlightListSheetWillClose:)]) {
		[self.delegate highlightListSheetWillClose:self];
	}
}

@end
