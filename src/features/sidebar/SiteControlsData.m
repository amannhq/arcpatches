// Chromium keeps installed extensions in "Secure Preferences" (older builds: "Preferences")
// under extensions.settings, and per-site permission exceptions in "Preferences" under
// profile.content_settings.exceptions. Both are JSON files the browser rewrites now and then.
#import "SiteControlsData.h"
#import "Browser.h"

static const NSTimeInterval kRefreshInterval = 4;

@implementation TweakSiteExtension
@end

#pragma mark - JSON helpers

static id typed(id obj, Class cls) { return [obj isKindOfClass:cls] ? obj : nil; }
static NSDictionary *dict(id obj, NSString *key) { return typed(typed(obj, NSDictionary.class)[key], NSDictionary.class); }

static NSDictionary *readJSON(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    @try {
        return typed([NSJSONSerialization JSONObjectWithData:data options:0 error:nil], NSDictionary.class);
    } @catch (__unused NSException *e) { return nil; }
}

// The profile the user last used (Local State's profile.last_used), else "Default".
static NSString *profileDir(void) {
    NSString *root = TweakDiaUserDataDir();
    NSString *last = typed(dict(readJSON([root stringByAppendingPathComponent:@"Local State"]), @"profile")[@"last_used"], NSString.class);
    BOOL isDir = NO;
    if (last.length && ![last containsString:@"/"] && ![last hasPrefix:@"."]) {
        NSString *p = [root stringByAppendingPathComponent:last];
        if ([NSFileManager.defaultManager fileExistsAtPath:p isDirectory:&isDir] && isDir) return p;
    }
    return [root stringByAppendingPathComponent:@"Default"];
}

#pragma mark - Extensions

static BOOL isEnabled(NSDictionary *s) {
    id reasons = s[@"disable_reasons"];
    if ([reasons isKindOfClass:NSArray.class] && [reasons count]) return NO;
    if ([reasons isKindOfClass:NSNumber.class] && [reasons integerValue]) return NO;
    id state = s[@"state"];   // older Chromium: 0 disabled, 1 enabled
    if ([state isKindOfClass:NSNumber.class] && [state integerValue] == 0) return NO;
    return YES;
}

// "__MSG_appName__" → the message from _locales/<locale>/messages.json (keys are case-insensitive).
static NSString *localized(NSString *name, NSString *dir, NSDictionary *manifest) {
    if (![name hasPrefix:@"__MSG_"] || ![name hasSuffix:@"__"] || name.length <= 8) return name;
    NSString *key = [name substringWithRange:NSMakeRange(6, name.length - 8)].lowercaseString;
    NSMutableArray *locales = [NSMutableArray array];
    for (NSString *lang in NSLocale.preferredLanguages) {
        NSString *l = [lang stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
        [locales addObject:l];
        NSString *base = [l componentsSeparatedByString:@"_"].firstObject;
        if (base.length) [locales addObject:base];
    }
    NSString *def = typed(manifest[@"default_locale"], NSString.class);
    if (def.length) [locales addObject:def];
    [locales addObject:@"en"];
    for (NSString *l in locales) {
        if ([l containsString:@"/"] || [l hasPrefix:@"."]) continue;
        NSDictionary *msgs = readJSON([dir stringByAppendingPathComponent:[NSString stringWithFormat:@"_locales/%@/messages.json", l]]);
        for (NSString *k in msgs) {
            if (![k isKindOfClass:NSString.class] || ![k.lowercaseString isEqualToString:key]) continue;
            NSString *m = typed(dict(msgs, k)[@"message"], NSString.class);
            if (m.length) return m;
        }
    }
    return nil;
}

// The smallest PNG icon of at least 32px (crisp at 20pt on Retina), else the largest one.
static NSImage *iconFor(NSDictionary *manifest, NSString *dir) {
    NSDictionary *icons = dict(manifest, @"icons");
    if (!icons.count) {
        NSDictionary *action = dict(manifest, @"action") ?: dict(manifest, @"browser_action");
        icons = typed(action[@"default_icon"], NSDictionary.class);
        NSString *single = typed(action[@"default_icon"], NSString.class);
        if (single.length) icons = @{@"32": single};
    }
    NSString *best = nil, *largest = nil;
    NSInteger bestSize = NSIntegerMax, largestSize = 0;
    for (id key in icons) {
        NSString *path = typed(icons[key], NSString.class);
        NSInteger size = [key respondsToSelector:@selector(integerValue)] ? [key integerValue] : 0;
        if (!path.length) continue;
        if (size >= 32 && size < bestSize) { best = path; bestSize = size; }
        if (size >= largestSize) { largest = path; largestSize = size; }
    }
    NSString *rel = best ?: largest;
    while ([rel hasPrefix:@"/"]) rel = [rel substringFromIndex:1];
    if (!rel.length || [rel containsString:@".."]) return nil;
    return [[NSImage alloc] initWithContentsOfFile:[dir stringByAppendingPathComponent:rel]];
}

static NSArray<TweakSiteExtension *> *loadExtensions(void) {
    NSString *profile = profileDir();
    NSDictionary *secure = dict(dict(readJSON([profile stringByAppendingPathComponent:@"Secure Preferences"]), @"extensions"), @"settings");
    NSDictionary *plain = dict(dict(readJSON([profile stringByAppendingPathComponent:@"Preferences"]), @"extensions"), @"settings");
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:plain ?: @{}];
    [settings addEntriesFromDictionary:secure ?: @{}];

    NSMutableArray *out = [NSMutableArray array];
    for (NSString *extId in settings) {
        NSDictionary *s = typed(settings[extId], NSDictionary.class);
        if (![extId isKindOfClass:NSString.class] || !s || !isEnabled(s)) continue;
        NSInteger location = [typed(s[@"location"], NSNumber.class) integerValue];
        if (location == 5 || location == 10) continue;   // component: built into the browser
        NSString *path = typed(s[@"path"], NSString.class);
        if (!path.length || [path hasPrefix:@"/Applications/"]) continue;
        NSString *dir = path.isAbsolutePath ? path   // unpacked
            : [[profile stringByAppendingPathComponent:@"Extensions"] stringByAppendingPathComponent:path];
        NSDictionary *manifest = dict(s, @"manifest") ?: readJSON([dir stringByAppendingPathComponent:@"manifest.json"]);
        if (!manifest || manifest[@"theme"] || manifest[@"app"]) continue;   // themes and apps have no tile
        TweakSiteExtension *e = [TweakSiteExtension new];
        e.identifier = extId;
        e.name = localized(typed(manifest[@"name"], NSString.class), dir, manifest) ?: extId;
        e.icon = iconFor(manifest, dir);
        [out addObject:e];
    }
    [out sortUsingComparator:^NSComparisonResult(TweakSiteExtension *a, TweakSiteExtension *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    return out;
}

NSArray<TweakSiteExtension *> *TweakSiteExtensions(void (^done)(NSArray<TweakSiteExtension *> *)) {
    static NSArray *cache;
    static NSDate *loadedAt;
    static BOOL loading;
    if (!loading && (!loadedAt || -loadedAt.timeIntervalSinceNow > kRefreshInterval)) {
        loading = YES;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSArray *list = nil;
            @try { list = loadExtensions(); } @catch (__unused NSException *e) { list = @[]; }
            dispatch_async(dispatch_get_main_queue(), ^{
                cache = list;
                loadedAt = [NSDate date];
                loading = NO;
                if (done) done(list);
            });
        });
    }
    return cache ?: @[];
}

#pragma mark - Permissions

NSArray<NSDictionary *> *TweakSitePermissions(NSString *url) {
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSString *scheme = c.scheme.lowercaseString, *host = c.host.lowercaseString;
    if (!host.length) return @[];
    NSInteger port = c.port ? c.port.integerValue : ([scheme isEqualToString:@"https"] ? 443 : 80);
    NSString *origin = [NSString stringWithFormat:@"%@://%@", scheme, host];
    NSArray *keys = @[[NSString stringWithFormat:@"%@:%ld,*", origin, (long)port], [origin stringByAppendingString:@",*"]];

    NSDictionary *prefs = readJSON([profileDir() stringByAppendingPathComponent:@"Preferences"]);
    NSDictionary *exceptions = dict(dict(dict(prefs, @"profile"), @"content_settings"), @"exceptions");
    NSArray *types = @[@[@"notifications", @"Notifications", @"bell"],
                       @[@"geolocation", @"Location", @"location"],
                       @[@"media_stream_camera", @"Camera", @"video"],
                       @[@"media_stream_mic", @"Microphone", @"mic"],
                       @[@"popups", @"Pop-ups and redirects", @"arrow.up.forward.app"],
                       @[@"clipboard", @"Clipboard", @"doc.on.clipboard"]];
    NSArray *states = @[@"", @"Allowed", @"Blocked", @"Ask"];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSArray *t in types) {
        NSDictionary *byPattern = dict(exceptions, t[0]);
        for (NSString *key in keys) {
            NSInteger setting = [typed(dict(byPattern, key)[@"setting"], NSNumber.class) integerValue];
            if (setting < 1 || setting > 3) continue;
            [rows addObject:@{@"title": t[1], @"symbol": t[2], @"state": states[setting]}];
            break;
        }
    }
    return rows;
}
