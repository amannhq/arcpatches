// The command bar's typing, inline completion, keys and activation.
#import "CommandBarInternal.h"

@implementation TweakCommandBar (Input)

#pragma mark Querying

- (void)runQuery {
    NSString *q = self.typed ?: @"";
    __weak typeof(self) weakSelf = self;
    [self.sources query:q done:^(NSArray<TweakItem *> *items) {
        typeof(self) s = weakSelf;
        if (![s.typed isEqualToString:q]) return;
        s.shownQuery = q;
        [s showItems:items];
        [s applyCompletionFrom:items];
    }];
}

- (void)showSuggestionsForCurrentPage {
    NSString *q = self.typed ?: @"";
    __weak typeof(self) weakSelf = self;
    [self.sources suggestionsForPage:q max:kMaxRows done:^(NSArray<TweakItem *> *items) {
        typeof(self) s = weakSelf;
        if (![s.typed isEqualToString:q]) return;   // typing took over
        s.shownQuery = q;
        [s showItems:items];
    }];
}

- (void)showItems:(NSArray<TweakItem *> *)items {
    self.results.items = items;
    [self layoutForRows:MIN(kMaxRows, items.count)];
    [self updateFieldIcon];
}

- (void)updateFieldIcon {
    // The palette's search row always shows the magnifying glass; the editor shows the site.
    if (self.mode == TweakCommandBarNewTab) {
        self.fieldIcon.image = ArcSymbol(@"magnifyingglass", ArcPaletteSearchIcon, NSFontWeightRegular, @"Search");
        return;
    }
    TweakItem *top = self.results.selected >= 0 ? self.results.items[self.results.selected] : nil;
    NSImage *img = top ? [self iconForItem:top] : nil;
    // While typing, show the site the field will open: its inline completion, or the address typed.
    if (self.results.selected <= 0) {
        NSString *field = self.field.currentEditor.string.lowercaseString ?: self.field.stringValue.lowercaseString;
        NSString *site = self.completionURL && [field isEqualToString:self.completionText] ? self.completionURL
                       : (TweakLooksLikeAddress(field) ? TweakResolveInput(field) : nil);
        NSImage *favicon = site ? [self.sources faviconFor:site] : nil;
        if (favicon) { self.fieldIcon.image = favicon; return; }
    }
    if (!img || top.kind == TweakItemCommand || top.kind == TweakItemPage)
        img = [NSImage imageWithSystemSymbolName:top ? top.symbol : @"magnifyingglass" accessibilityDescription:nil];
    self.fieldIcon.image = img;
}

// Inline completion: "git" -> "git|hub.com" with the suffix selected.
- (void)applyCompletionFrom:(NSArray<TweakItem *> *)items {
    if (self.suppressCompletion) return;
    NSString *url = nil;
    NSString *host = [self.sources completionFor:self.typed inItems:items url:&url];
    NSText *editor = self.field.currentEditor;
    if (!host || !editor || ![editor.string isEqualToString:self.typed]) return;
    self.completionText = host;
    self.completionURL = url;
    NSString *suffix = [host substringFromIndex:self.typed.length];
    editor.string = [self.typed stringByAppendingString:suffix];
    editor.selectedRange = NSMakeRange(self.typed.length, suffix.length);
    [self updateFieldIcon];
}

- (void)controlTextDidChange:(NSNotification *)n {
    NSString *now = self.field.stringValue;
    // Deleting shouldn't immediately re-complete what was just removed.
    self.suppressCompletion = now.length <= self.typed.length && [self.typed hasPrefix:now];
    self.typed = now;
    [self runQuery];
}

- (BOOL)control:(NSControl *)c textView:(NSTextView *)tv doCommandBySelector:(SEL)sel {
    NSInteger n = self.results.items.count;
    if (sel == @selector(moveDown:) || sel == @selector(moveUp:)) {
        if (!n) return YES;
        NSInteger s = self.results.selected + (sel == @selector(moveDown:) ? 1 : -1);
        self.results.selected = (s + n) % n;
        [self updateFieldIcon];
        return YES;
    }
    if (sel == @selector(insertTab:)) {  // accept the inline completion
        tv.selectedRange = NSMakeRange(tv.string.length, 0);
        self.typed = tv.string;
        [self runQuery];
        return YES;
    }
    if (sel == @selector(insertNewline:)) {
        BOOL newTab = (NSApp.currentEvent.modifierFlags & NSEventModifierFlagCommand) != 0;
        // An inline completion is showing and the top row is still selected: go to it.
        BOOL completed = ![tv.string isEqualToString:self.typed] && self.results.selected == 0;
        // Results for what's typed haven't arrived yet: the listed rows are for older text.
        BOOL stale = ![self.shownQuery isEqualToString:self.typed];
        [self activateRow:completed || stale ? -1 : self.results.selected forceNewTab:newTab];
        return YES;
    }
    if (sel == @selector(cancelOperation:)) { [self close]; return YES; }
    return NO;
}

#pragma mark Activation

- (void)activateRow:(NSInteger)row forceNewTab:(BOOL)forceNewTab {
    NSWindow *w = self.host;
    TweakItem *it = row >= 0 && row < (NSInteger)self.results.items.count ? self.results.items[row] : nil;
    NSString *typedText = self.field.stringValue, *query = self.typed;
    [self close];
    if (!it) {
        // Nothing listed (e.g. ⌘L with the URL untouched): treat the field as an address/search.
        if (!typedText.length) return;
        it = [TweakItem new];
        it.kind = TweakItemURL;
        it.url = TweakResolveURL(typedText) ?: [self.sources searchURLFor:typedText];  // the user's search engine, not Google
    }
    // An inline completion, accepted or not, goes where its page was (keeping http and the port).
    BOOL completion = self.completionURL && [typedText.lowercaseString isEqualToString:self.completionText];
    switch (it.kind) {
        case TweakItemCommand: {
            NSMenuItem *m = it.menuItem;
            dispatch_async(dispatch_get_main_queue(), ^{ [NSApp sendAction:m.action to:m.target from:m]; });
            break;
        }
        case TweakItemTab:
            TweakFocusTab(it.windowId, it.tabId);
            break;
        default: {
            NSString *url = it.url;
            // The URL row reflects what's in the field, including an accepted completion.
            if (it.kind == TweakItemURL && ![typedText isEqualToString:it.title])
                url = TweakResolveURL(typedText) ?: [self.sources searchURLFor:typedText];
            if (it.kind == TweakItemURL && completion) url = self.completionURL;
            // A Search row clicked before its results refreshed searches what's typed now (without the completion).
            if (it.kind == TweakItemSearch && ![query isEqualToString:it.title]) url = [self.sources searchURLFor:query];
            if (!url) return;
            if (self.mode == TweakCommandBarNewTab || forceNewTab) TweakOpenInNewTab(w, url);
            else TweakNavigateWindow(w, url);
        }
    }
}

@end
