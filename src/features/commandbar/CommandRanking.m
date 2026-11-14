// Ranking for the command bar: matches every source against what's typed, mixes
// in history, and picks the inline completion.
#import "CommandSourcesInternal.h"
#import "Common.h"

#pragma mark - Matching

// Scores how well `query` matches an item: every word must appear in the title or
// URL; word-prefix and host-prefix hits count more than mid-word hits.
static double matchScore(NSArray<NSString *> *words, NSString *title, NSString *url) {
    NSString *t = title.lowercaseString ?: @"";
    NSString *u = url.lowercaseString ?: @"";
    NSString *host = [NSURL URLWithString:url].host.lowercaseString ?: @"";
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    double score = 0;
    for (NSString *w in words) {
        double best = 0;
        if ([host hasPrefix:w]) best = 4;
        else if ([t hasPrefix:w]) best = 4;
        else if ([t rangeOfString:[@" " stringByAppendingString:w]].location != NSNotFound) best = 3;
        else if ([t containsString:w]) best = 1.5;
        else if ([host containsString:w]) best = 1.5;
        else if ([u containsString:w]) best = 0.8;
        if (best == 0) return 0;
        score += best;
    }
    // A title that is exactly what's typed, or starts with it, wins outright.
    NSString *q = [words componentsJoinedByString:@" "];
    if ([t isEqualToString:q]) score += 4;
    else if ([t hasPrefix:q]) score += 2;
    return score;
}

@implementation TweakCommandSources (Ranking)

#pragma mark - Query

- (void)query:(NSString *)text done:(void (^)(NSArray<TweakItem *> *))done {
    NSString *q = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].lowercaseString;
    NSUInteger gen = ++_generation;
    if (!q.length) {
        // Empty: open tabs, most recent first, like Arc.
        NSArray *tabs = [_tabs subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)8, _tabs.count))];
        done(tabs);
        return;
    }
    NSArray *words = [q componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    words = [words filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
    NSArray *commands = _commands, *pages = _pages, *tabs = _tabs, *bookmarks = _bookmarks;
    NSString *activeURL = _activeURL;
    // _searchTemplate is replaced on each open, so read it here on main, not on the queue.
    NSString *searchURL = [self searchURLFor:text], *engine = [self searchEngineName];
    dispatch_async(_queue, ^{
        if (gen != self->_generation) return;  // typed past; don't scan History for this one
        NSMutableArray<TweakItem *> *all = [NSMutableArray array];
        // Ranking: a command, page or tab that matches by prefix beats history (as in
        // Arc); history is ordered by match plus frecency.
        void (^add)(NSArray<TweakItem *> *, double, double, double) = ^(NSArray<TweakItem *> *list, double minMatch, double weight, double prefixBonus) {
            for (TweakItem *it in list) {
                double m = matchScore(words, it.title, it.kind == TweakItemCommand ? nil : it.url);
                if (m < minMatch) continue;
                // Commands and pages win when you've clearly started typing their name
                // (3+ letters, "set" -> Settings); for "g" or "go" your most visited sites lead.
                double coverage = MIN(1.0, 2.0 * q.length / MAX((NSUInteger)1, it.title.length));
                BOOL named = m >= 4 * words.count && (it.kind == TweakItemTab || q.length >= 3);
                it.score = m * weight + it.frecency + (named ? prefixBonus * coverage : 0);
                [all addObject:it];
            }
        };
        add(commands, 2.5, 1.2, 15.0);
        add(pages, 2.5, 1.2, 14.0);
        add(tabs, 0.8, 1.25, 2.5);
        add(bookmarks, 1.0, 1.1, 1.0);
        NSArray<TweakItem *> *history = [self historyFor:words];
        add(history, 0.8, 1.0, 0);

        // A site that's open in a tab is offered as "Switch to Tab", with its history weight.
        NSMutableDictionary<NSString *, TweakItem *> *historyByURL = [NSMutableDictionary dictionary];
        for (TweakItem *h in history) if (h.url) historyByURL[h.url] = h;
        for (TweakItem *t in all)
            if (t.kind == TweakItemTab && historyByURL[t.url]) t.score = MAX(t.score, historyByURL[t.url].score + 0.5);

        // De-duplicate URLs: an open tab beats a bookmark beats history.
        [all sortUsingComparator:^NSComparisonResult(TweakItem *a, TweakItem *b) { return a.score > b.score ? NSOrderedAscending : a.score < b.score ? NSOrderedDescending : NSOrderedSame; }];
        NSMutableArray<TweakItem *> *ranked = [NSMutableArray array];
        NSMutableSet *urls = [NSMutableSet set];
        NSCountedSet *perSite = [NSCountedSet set], *perTitle = [NSCountedSet set];
        for (TweakItem *it in all) {
            NSString *key = it.url ? [it.url stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]] : it.title;
            if (it.kind == TweakItemTab && [it.url isEqualToString:activeURL]) continue;  // already here
            if ([urls containsObject:key]) continue;
            // At most two history rows per site, so one site can't fill the list.
            NSString *site = [NSURL URLWithString:it.url].host;
            if (it.kind == TweakItemHistory && site && [perSite countForObject:site] >= 2) continue;
            if (it.kind == TweakItemHistory && it.title && [perTitle countForObject:it.title] >= 2) continue;
            if (site) [perSite addObject:site];
            if (it.title) [perTitle addObject:it.title];
            [urls addObject:key];
            [ranked addObject:it];
        }

        // What was typed: as an address, or a search. Second place unless nothing else is strong.
        TweakItem *typed = [TweakItem new];
        if (TweakLooksLikeAddress(q)) {
            typed.kind = TweakItemURL;
            typed.url = TweakResolveInput(text);
            typed.title = text;
            typed.detail = @"Open";
            typed.symbol = @"globe";
        } else {
            typed.kind = TweakItemSearch;
            typed.title = text;
            typed.url = searchURL;
            typed.detail = [@"Search " stringByAppendingString:engine];
            typed.symbol = @"magnifyingglass";
        }
        BOOL strongTop = ranked.count && ((TweakItem *)ranked[0]).score >= 5;
        [ranked insertObject:typed atIndex:strongTop ? 1 : 0];

        NSArray *items = [ranked subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)8, ranked.count))];
        dispatch_async(dispatch_get_main_queue(), ^{ if (gen == self->_generation) done(items); });
    });
}

- (NSString *)completionFor:(NSString *)text inItems:(NSArray<TweakItem *> *)items url:(NSString **)url {
    NSString *q = text.lowercaseString;
    if (!q.length || [q rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) return nil;
    for (TweakItem *it in items) {
        if (it.kind != TweakItemHistory && it.kind != TweakItemTab && it.kind != TweakItemBookmark) continue;
        NSURLComponents *c = [NSURLComponents componentsWithString:it.url];
        NSString *host = c.host.lowercaseString;
        if (!host.length || !c.scheme.length) break;
        NSString *site = [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
        if (c.port) site = [site stringByAppendingFormat:@":%@", c.port];
        if (site.length > q.length && [site hasPrefix:q]) {
            // The site's root, keeping http and the port: "homeassistant.local" alone would become https.
            *url = [NSString stringWithFormat:@"%@://%@%@/", c.scheme.lowercaseString, host, c.port ? [@":" stringByAppendingString:c.port.stringValue] : @""];
            return site;
        }
        break;  // only complete from the top-ranked page
    }
    return nil;
}

#pragma mark - Before typing (⌘L)

static NSString *trimmedKey(NSString *url) { return [url stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]; }

static BOOL onSite(NSString *url, NSString *site) {
    NSString *h = [NSURL URLWithString:url].host.lowercaseString;
    return h && ([h isEqualToString:site] || [h hasSuffix:[@"." stringByAppendingString:site]]);
}

- (void)suggestionsForPage:(NSString *)url max:(NSUInteger)max done:(void (^)(NSArray<TweakItem *> *))done {
    NSUInteger gen = ++_generation;
    NSMutableArray<TweakItem *> *items = [NSMutableArray array];
    // The page you're on, under its tab's title.
    TweakItem *page = [TweakItem new];
    page.kind = TweakItemHistory;
    page.url = url;
    page.symbol = @"globe";
    for (TweakItem *t in _tabs) if ([t.url isEqualToString:url]) { page.title = t.title; break; }
    page.title = page.title.length ? page.title : url;
    [items addObject:page];

    // Then the site's root, keeping http and the port.
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSString *host = c.host.lowercaseString;
    if (!host.length || !c.scheme.length) { done(items); return; }
    NSString *site = [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
    NSString *port = c.port ? [@":" stringByAppendingString:c.port.stringValue] : @"";
    NSString *rootURL = [NSString stringWithFormat:@"%@://%@%@/", c.scheme.lowercaseString, host, port];
    if (![trimmedKey(rootURL) isEqualToString:trimmedKey(url)]) {
        TweakItem *root = [TweakItem new];
        root.kind = TweakItemHistory;
        root.url = rootURL;
        root.title = [site stringByAppendingString:port];
        root.symbol = @"globe";
        [items addObject:root];
    }

    // Then other open tabs and history on the same site, most visited first.
    NSArray<TweakItem *> *tabs = _tabs;
    dispatch_async(_queue, ^{
        if (gen != self->_generation) return;
        NSMutableArray<TweakItem *> *more = [NSMutableArray array];
        for (TweakItem *t in tabs) if (onSite(t.url, site)) [more addObject:t];
        for (TweakItem *h in [self historyFor:@[site]]) if (onSite(h.url, site)) [more addObject:h];
        NSMutableSet *seen = [NSMutableSet set];
        for (TweakItem *it in items) [seen addObject:trimmedKey(it.url)];
        for (TweakItem *it in more) {
            if (items.count >= max) break;
            if ([seen containsObject:trimmedKey(it.url)]) continue;
            [seen addObject:trimmedKey(it.url)];
            [items addObject:it];
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (gen == self->_generation) done(items); });
    });
}

@end
