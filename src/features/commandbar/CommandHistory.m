// The command bar's reads from the profile's databases: history, and favicons
// (with ArcPatches's own copy of them).
#import "CommandSourcesInternal.h"
#import "Common.h"
#import "Browser.h"

// The last-used profile's folder (Local State → profile.last_used), else Default.
NSString *TweakCommandProfileDir(void) {
    NSString *root = TweakDiaUserDataDir();
    NSData *data = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"Local State"]];
    id state = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    id profile = [state isKindOfClass:NSDictionary.class] ? state[@"profile"] : nil;
    id last = [profile isKindOfClass:NSDictionary.class] ? profile[@"last_used"] : nil;
    BOOL isDir = NO;
    if ([last isKindOfClass:NSString.class] && [last length] && ![last hasPrefix:@"."] && ![last containsString:@"/"] &&
        [NSFileManager.defaultManager fileExistsAtPath:[root stringByAppendingPathComponent:last] isDirectory:&isDir] && isDir)
        return [root stringByAppendingPathComponent:last];
    return [root stringByAppendingPathComponent:@"Default"];
}

@implementation TweakCommandSources (HistoryQueries)

#pragma mark - SQLite (read-only, never locks Dia's databases)

- (void)sqlite:(NSString *)file query:(NSString *)sql bind:(NSArray *)args row:(void (^)(sqlite3_stmt *))row {
    NSString *path = [TweakCommandProfileDir() stringByAppendingPathComponent:file];
    NSString *uri = [NSString stringWithFormat:@"file:%@?immutable=1", [path stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet]];
    sqlite3 *db = NULL;
    if (sqlite3_open_v2(uri.UTF8String, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, NULL) != SQLITE_OK) { sqlite3_close(db); return; }
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, sql.UTF8String, -1, &st, NULL) == SQLITE_OK) {
        for (int i = 0; i < (int)args.count; i++) {
            if ([args[i] isKindOfClass:NSNumber.class]) sqlite3_bind_int64(st, i + 1, [args[i] longLongValue]);
            else sqlite3_bind_text(st, i + 1, [args[i] UTF8String], -1, SQLITE_TRANSIENT);
        }
        while (sqlite3_step(st) == SQLITE_ROW) row(st);
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
}

static NSString *likeEscape(NSString *s) {
    return [[[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"]
            stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
}

- (NSArray<TweakItem *> *)historyFor:(NSArray<NSString *> *)words {
    if (!words.count) return @[];
    // Every word must appear in the URL or title; rank by typed count, visits, recency.
    NSMutableString *where = [NSMutableString stringWithString:@"hidden = 0"];
    NSMutableArray *args = [NSMutableArray array];
    for (NSString *w in words) {
        // SQLite's LIKE folds ASCII case only, so non-ASCII words also try their upper and capitalized forms.
        NSArray *forms = [w canBeConvertedToEncoding:NSASCIIStringEncoding] ? @[w] : @[w, w.uppercaseString, w.capitalizedString];
        NSMutableString *any = [NSMutableString string];
        for (NSString *f in forms) {
            [args addObject:[NSString stringWithFormat:@"%%%@%%", likeEscape(f)]];
            [any appendFormat:@"%@url LIKE ?%lu ESCAPE '\\' OR title LIKE ?%lu ESCAPE '\\'", any.length ? @" OR " : @"", (unsigned long)args.count, (unsigned long)args.count];
        }
        [where appendFormat:@" AND (%@)", any];
    }
    NSString *sql = [NSString stringWithFormat:@"SELECT url, title, visit_count, typed_count, last_visit_time FROM urls WHERE %@ "
                     "ORDER BY typed_count * 2 + visit_count DESC, last_visit_time DESC LIMIT 80", where];
    NSMutableArray *out = [NSMutableArray array];
    // Chromium time: microseconds since 1601-01-01.
    double nowChrome = (NSDate.date.timeIntervalSince1970 + 11644473600.0) * 1e6;
    [self sqlite:@"History" query:sql bind:args row:^(sqlite3_stmt *s) {
        TweakItem *it = [TweakItem new];
        it.kind = TweakItemHistory;
        it.url = @((const char *)sqlite3_column_text(s, 0) ?: "");
        NSString *title = @((const char *)sqlite3_column_text(s, 1) ?: "");
        it.title = title.length ? title : it.url;
        it.detail = it.url;
        it.symbol = @"globe";
        double visits = sqlite3_column_int(s, 2), typed = sqlite3_column_int(s, 3);
        double ageDays = MAX(0, (nowChrome - sqlite3_column_int64(s, 4)) / 8.64e10);
        // Log-scaled and uncapped, so a site visited thousands of times clearly outranks
        // one visited dozens of times (typing "g" should give the Google you always use).
        it.frecency = log2(visits + 1) * 0.6 + log2(typed + 1) * 0.8 + 1.5 / (1 + ageDays / 7.0);
        [out addObject:it];
    }];
    return out;
}

@end

@implementation TweakCommandSources (History)

#pragma mark - Favicons

// Dia's Chromium forgets which page used which favicon after a day or two, and drops
// the images too. So ArcPatches keeps its own copy of each site's icon, saved from
// Chromium's database while the site was recent, and falls back to it.
static NSString *siteKey(NSURL *u) {
    NSString *host = u.host.lowercaseString;
    if (!host.length) return nil;
    if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    return u.port ? [NSString stringWithFormat:@"%@_%@", host, u.port] : host;
}

static NSString *siteIconPath(NSString *site) {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches/site-icons"];
    return [dir stringByAppendingPathComponent:[site stringByAppendingPathExtension:@"png"]];
}

static dispatch_queue_t learnQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("arcpatches.site-icons", DISPATCH_QUEUE_SERIAL); });
    return q;
}

// Saves the largest current icon of every site Chromium still links (in the background).
+ (void)learnSiteIcons {
    dispatch_async(learnQueue(), ^{
        TweakCommandSources *s = [TweakCommandSources new];
        NSMutableDictionary<NSString *, NSData *> *best = [NSMutableDictionary dictionary];
        [s sqlite:@"Favicons" query:@"SELECT m.page_url, b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id "
                                     "WHERE length(b.image_data) > 0 ORDER BY m.id, b.width" bind:@[] row:^(sqlite3_stmt *st) {
            NSString *key = siteKey([NSURL URLWithString:@((const char *)sqlite3_column_text(st, 0) ?: "")]);
            if (key) best[key] = [NSData dataWithBytes:sqlite3_column_blob(st, 1) length:sqlite3_column_bytes(st, 1)];
        }];
        NSFileManager *fm = NSFileManager.defaultManager;
        if (best.count) [fm createDirectoryAtPath:siteIconPath(@"x").stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        [best enumerateKeysAndObjectsUsingBlock:^(NSString *site, NSData *png, BOOL *stop) {
            NSString *path = siteIconPath(site);
            if (![[NSData dataWithContentsOfFile:path] isEqualToData:png]) [png writeToFile:path atomically:YES];
        }];
    });
}

- (NSImage *)faviconFor:(NSString *)url {
    if (!url.length) return nil;
    id cached = [_icons objectForKey:url];
    if (cached) return cached == NSNull.null ? nil : cached;
    NSURL *u = [NSURL URLWithString:url];
    NSString *host = u.port ? [NSString stringWithFormat:@"%@:%@", u.host, u.port] : u.host;
    // The page itself, then any page on the same host, while Chromium still has them.
    __block NSData *png = nil;
    [self sqlite:@"Favicons" query:@"SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id = m.icon_id "
                                    "WHERE (m.page_url = ?1 OR m.page_url LIKE ?2) AND length(b.image_data) > 0 ORDER BY (m.page_url = ?1) DESC, b.width DESC LIMIT 1"
            bind:@[url, [NSString stringWithFormat:@"%%://%@/%%", host ?: @"-"]] row:^(sqlite3_stmt *s) {
        png = [NSData dataWithBytes:sqlite3_column_blob(s, 0) length:sqlite3_column_bytes(s, 0)];
    }];
    // Otherwise the icon saved from an earlier visit.
    NSString *site = siteKey(u);
    if (!png.length && site) png = [NSData dataWithContentsOfFile:siteIconPath(site)];
    NSImage *img = png.length ? [[NSImage alloc] initWithData:png] : nil;
    [_icons setObject:img ?: (id)NSNull.null forKey:url];
    return img;
}

@end

void TweakSiteIconsInstall(void) {
    // Chromium keeps a site's favicon only a day or two after the last visit: save often.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [TweakCommandSources learnSiteIcons]; });
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:15 * 60 repeats:YES block:^(__unused NSTimer *timer) { [TweakCommandSources learnSiteIcons]; }];
    t.tolerance = 60;
}
