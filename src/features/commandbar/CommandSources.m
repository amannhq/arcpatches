// Result sources for the command bar: Dia's menu commands, chrome:// pages, open
// tabs, bookmarks and the search engine. Ranking is in CommandRanking.m, history
// and favicons in CommandHistory.m.
#import "CommandSourcesInternal.h"
#import "Common.h"

@implementation TweakItem
@end

NSString *TweakShortcutString(NSMenuItem *item) {
    if (!item.keyEquivalent.length) return @"";
    NSMutableString *s = [NSMutableString string];
    NSEventModifierFlags m = item.keyEquivalentModifierMask;
    if (m & NSEventModifierFlagControl) [s appendString:@"⌃"];
    if (m & NSEventModifierFlagOption) [s appendString:@"⌥"];
    if (m & NSEventModifierFlagShift) [s appendString:@"⇧"];
    if (m & NSEventModifierFlagCommand) [s appendString:@"⌘"];
    NSString *k = item.keyEquivalent;
    NSDictionary *names = @{@"\r": @"↩", @"\t": @"⇥", @" ": @"Space", @"\x1b": @"⎋", @"\x7f": @"⌫",
                            [NSString stringWithFormat:@"%C", (unichar)NSLeftArrowFunctionKey]: @"←",
                            [NSString stringWithFormat:@"%C", (unichar)NSRightArrowFunctionKey]: @"→",
                            [NSString stringWithFormat:@"%C", (unichar)NSUpArrowFunctionKey]: @"↑",
                            [NSString stringWithFormat:@"%C", (unichar)NSDownArrowFunctionKey]: @"↓"};
    [s appendString:names[k] ?: k.uppercaseString];
    return s;
}

#pragma mark - Sources

@implementation TweakCommandSources

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("arcpatches.history", DISPATCH_QUEUE_SERIAL);
        _icons = [NSCache new];
    }
    return self;
}

- (void)prepareForWindow:(NSWindow *)window {
    _commands = [self loadCommands];
    _pages = [self loadPages];
    _tabs = [self loadTabs];
    _bookmarks = [self loadBookmarks];
    _searchTemplate = [self loadSearchTemplate];
    _activeURL = TweakURLForWindow(window);
    [_icons removeAllObjects];   // drop remembered misses: sites may have icons by now
    [TweakCommandSources learnSiteIcons];
}

// Every enabled, visible command in Dia's menus, including submenus.
- (NSArray<TweakItem *> *)loadCommands {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSSet *skipMenus = [NSSet setWithArray:@[@"Services", @"Open Recent", @"Help"]];
    __block void (^walk)(NSMenu *, NSString *) = nil;
    void (^__block __weak weakWalk)(NSMenu *, NSString *);
    NSSet *topTitles = [NSSet setWithArray:[NSApp.mainMenu.itemArray valueForKey:@"title"]];
    weakWalk = walk = ^(NSMenu *menu, NSString *path) {
        [menu update];  // runs Dia's validation so isEnabled is current
        for (NSMenuItem *i in menu.itemArray) {
            if (i.isSeparatorItem || i.isHidden || !i.title.length) continue;
            if (i.submenu) {
                if (![skipMenus containsObject:i.title]) weakWalk(i.submenu, i.title);
                continue;
            }
            if (!i.action || !i.isEnabled) continue;
            if (i.action == @selector(makeKeyAndOrderFront:)) continue;  // window list
            NSString *title = [i.title stringByReplacingOccurrencesOfString:@"…" withString:@""];
            if (![topTitles containsObject:path]) title = [NSString stringWithFormat:@"%@ › %@", path, title];
            if ([seen containsObject:title]) continue;
            [seen addObject:title];
            TweakItem *it = [TweakItem new];
            it.kind = TweakItemCommand;
            it.title = title;
            it.detail = TweakShortcutString(i);
            it.menuItem = i;
            it.symbol = [self symbolForCommand:title];
            [out addObject:it];
        }
    };
    for (NSMenuItem *top in NSApp.mainMenu.itemArray)
        if (top.submenu) walk(top.submenu, top.title);
    walk = nil;
    return out;
}

- (NSString *)symbolForCommand:(NSString *)t {
    NSDictionary *map = @{@"Settings": @"gearshape", @"New Window": @"macwindow.badge.plus", @"New Tab": @"plus.square",
                          @"Close Tab": @"xmark.square", @"Reopen Closed Tab": @"arrow.uturn.backward.square",
                          @"Print": @"printer", @"Copy URL": @"link", @"Find": @"magnifyingglass", @"Reload": @"arrow.clockwise",
                          @"Downloads": @"arrow.down.circle", @"History": @"clock", @"Bookmarks": @"bookmark",
                          @"Extensions": @"puzzlepiece.extension", @"Quit Dia": @"power", @"Zoom In": @"plus.magnifyingglass",
                          @"Zoom Out": @"minus.magnifyingglass", @"Developer Tools": @"hammer", @"Task Manager": @"chart.bar"};
    for (NSString *k in map) if ([t hasPrefix:k]) return map[k];
    return @"command";
}

- (NSArray<TweakItem *> *)loadPages {
    NSArray *pages = @[
        @[@"Chrome Flags", @"chrome://flags", @"flag"],
        @[@"Extensions", @"chrome://extensions", @"puzzlepiece.extension"],
        @[@"Downloads", @"chrome://downloads", @"arrow.down.circle"],
        @[@"History", @"chrome://history", @"clock"],
        @[@"Bookmarks", @"chrome://bookmarks", @"bookmark"],
        @[@"Passwords", @"chrome://password-manager", @"key"],
        @[@"Clear Browsing Data", @"chrome://settings/clearBrowserData", @"trash"],
        @[@"Privacy and Security", @"chrome://settings/privacy", @"hand.raised"],
        @[@"Site Settings", @"chrome://settings/content", @"slider.horizontal.3"],
        @[@"Cookies and Site Data", @"chrome://settings/cookies", @"circle.hexagongrid"],
        @[@"Search Engines", @"chrome://settings/searchEngines", @"magnifyingglass"],
        @[@"Autofill and Addresses", @"chrome://settings/addresses", @"person.text.rectangle"],
        @[@"Payment Methods", @"chrome://settings/payments", @"creditcard"],
        @[@"Version", @"chrome://version", @"info.circle"],
        @[@"GPU", @"chrome://gpu", @"cpu"],
        @[@"Inspect Devices", @"chrome://inspect", @"hammer"],
        @[@"Net Internals", @"chrome://net-internals", @"network"],
    ];
    NSMutableArray *out = [NSMutableArray array];
    for (NSArray *p in pages) {
        TweakItem *it = [TweakItem new];
        it.kind = TweakItemPage;
        it.title = p[0];
        it.url = p[1];
        it.detail = p[1];
        it.symbol = p[2];
        [out addObject:it];
    }
    return out;
}

- (NSArray<TweakItem *> *)loadTabs {
    NSMutableArray *out = [NSMutableArray array];
    @try {
        for (id sw in [NSApp valueForKey:@"appleScriptWindows"]) {
            NSString *wid = [sw valueForKey:@"windowId"];
            for (id tab in [sw valueForKey:@"appleScriptTabs"]) {
                NSString *url = [tab valueForKey:@"URL"];
                if (![url isKindOfClass:NSString.class] || !url.length || [url hasPrefix:@"dia://"]) continue;
                TweakItem *it = [TweakItem new];
                it.kind = TweakItemTab;
                it.title = [tab valueForKey:@"title"] ?: url;
                it.url = url;
                it.detail = @"Switch to Tab";
                it.tabId = [tab valueForKey:@"tabId"];
                it.windowId = wid;
                it.symbol = @"square.on.square";
                it.frecency = 3.0;  // open tabs are usually what you're looking for
                [out addObject:it];
            }
        }
    } @catch (__unused NSException *e) {}
    return out;
}

- (NSArray<TweakItem *> *)loadBookmarks {
    NSData *data = [NSData dataWithContentsOfFile:[TweakCommandProfileDir() stringByAppendingPathComponent:@"Bookmarks"]];
    NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    NSMutableArray *out = [NSMutableArray array];
    __block void (^walk)(NSDictionary *) = nil;
    void (^__block __weak weakWalk)(NSDictionary *);
    weakWalk = walk = ^(NSDictionary *node) {
        if ([node[@"type"] isEqual:@"url"] && [node[@"url"] isKindOfClass:NSString.class]) {
            TweakItem *it = [TweakItem new];
            it.kind = TweakItemBookmark;
            it.title = node[@"name"];
            it.url = node[@"url"];
            it.detail = node[@"url"];
            it.symbol = @"bookmark";
            it.frecency = 1.0;
            [out addObject:it];
        }
        for (NSDictionary *c in node[@"children"]) if ([c isKindOfClass:NSDictionary.class]) weakWalk(c);
    };
    for (NSDictionary *root in [json[@"roots"] allValues]) if ([root isKindOfClass:NSDictionary.class]) walk(root);
    walk = nil;
    return out;
}

// Dia's default search engine, from the profile's Preferences + Web Data.
- (NSString *)loadSearchTemplate {
    NSString *fallback = @"https://www.google.com/search?q={searchTerms}";
    NSData *prefs = [NSData dataWithContentsOfFile:[TweakCommandProfileDir() stringByAppendingPathComponent:@"Preferences"]];
    NSDictionary *p = prefs ? [NSJSONSerialization JSONObjectWithData:prefs options:0 error:nil] : nil;
    NSString *guid = p[@"default_search_provider"][@"guid"];
    if (![guid isKindOfClass:NSString.class]) return fallback;
    __block NSString *url = nil;
    [self sqlite:@"Web Data" query:@"SELECT url FROM keywords WHERE sync_guid = ?1 LIMIT 1" bind:@[guid] row:^(sqlite3_stmt *s) {
        url = @((const char *)sqlite3_column_text(s, 0) ?: "");
    }];
    return url.length ? url : fallback;
}

- (NSString *)searchURLFor:(NSString *)text {
    NSMutableCharacterSet *allowed = [NSCharacterSet.URLQueryAllowedCharacterSet mutableCopy];
    [allowed removeCharactersInString:@"&=+?#"];
    // nil for a lone surrogate (lossy UTF-8 conversion returns nil too); replacing with nil would throw.
    NSString *q = [text stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
    NSString *u = [_searchTemplate ?: @"https://www.google.com/search?q={searchTerms}" stringByReplacingOccurrencesOfString:@"{searchTerms}" withString:q];
    u = [u stringByReplacingOccurrencesOfString:@"{google:baseURL}" withString:@"https://www.google.com/"];
    // Drop the remaining Chromium-only placeholders ({google:RLZ} etc.).
    NSRegularExpression *ph = [NSRegularExpression regularExpressionWithPattern:@"\\{[^}]*\\}" options:0 error:nil];
    u = [ph stringByReplacingMatchesInString:u options:0 range:NSMakeRange(0, u.length) withTemplate:@""];
    while ([u hasSuffix:@"&"]) u = [u substringToIndex:u.length - 1];
    return u;
}

- (NSString *)searchEngineName {
    NSString *host = [NSURL URLWithString:[self searchURLFor:@"x"]].host;
    for (NSString *n in @[@"Google", @"DuckDuckGo", @"Bing", @"Brave", @"Ecosia", @"Kagi", @"Perplexity", @"Startpage"])
        if ([host.lowercaseString containsString:n.lowercaseString]) return n;
    return host ?: @"the web";
}

@end
