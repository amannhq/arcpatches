// Writes ~/Library/Application Support/arcpatches/health.json at launch: which of
// Dia's internals each feature relies on are still present. The companion app
// shows this so a Dia update that breaks a feature doesn't go unnoticed.
#import "Common.h"
#import "Browser.h"
#import <objc/runtime.h>

#ifndef ARCPATCHES_VERSION
#define ARCPATCHES_VERSION "dev"
#endif

NSString *TweakPatchVersion(void) { return @ARCPATCHES_VERSION; }

static BOOL hasMethod(NSString *cls, SEL sel) {
    Class c = NSClassFromString(cls);
    return c && class_getInstanceMethod(c, sel);
}

// Dia's scripting bridge; valueForKey: throws if the key isn't there (yet).
static BOOL hasScriptingWindows(void) {
    if ([NSApp respondsToSelector:NSSelectorFromString(@"appleScriptWindows")]) return YES;
    @try { return [NSApp valueForKey:@"appleScriptWindows"] != nil; }
    @catch (__unused NSException *e) { return NO; }
}

void TweakHealthWrite(void) {
    NSDictionary *checks = @{
        @"URL bar hiding": @(NSClassFromString(kDiaContentPaneClass) && NSClassFromString(kDiaNavigationBarClass)),
        @"Sidebar URL bar": @(TweakFindClass(kDiaSidebarRootPrefix, kDiaSidebarRootSuffix) != nil),
        @"Settings pane": @(hasMethod(kDiaPreferencesListClass, @selector(tableView:viewForTableColumn:row:))),
        @"Command bar": @(hasScriptingWindows()),
        @"Tab sorting": @(TweakTabsAvailable()),
        @"New tab without a tab": @(hasMethod(kDiaNavigationControllerClass, @selector(load:initiatorOrigin:transition:fromAddressBar:typedWithHttpScheme:))),
        @"Dia editor anchoring": @(TweakFindClass(kDiaPopoverRootPrefix, kDiaPopoverRootSuffix) != nil),
        @"Web engine blocking": @(hasMethod(kDiaAppConfigurationClass, @selector(argv))),
        @"Hide AI features": @(NSClassFromString(kDiaSidebarFooterClass) && NSClassFromString(kDiaEditorToolbarClass)),
        @"On-device AI off": @(hasMethod(kDiaAIServiceClass, @selector(initialize:callback:))),
    };
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSDictionary *report = @{
        @"patchVersion": TweakPatchVersion(),
        @"diaVersion": info[@"CFBundleShortVersionString"] ?: @"?",
        @"diaBuild": info[@"CFBundleVersion"] ?: @"?",
        @"date": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"checks": checks,
    };
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *json = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    [json writeToFile:[dir stringByAppendingPathComponent:@"health.json"] atomically:YES];
}

// Background mode (no menu bar app): when Dia Arc quits, kick the companion's
// launchd job so a pending patch or Dia update happens right away.
void TweakKickCompanionOnQuit(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n) {
        NSString *agent = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents/dev.amannhq.arcpatches.watch.plist"];
        if (![NSFileManager.defaultManager fileExistsAtPath:agent]) return;
        NSTask *t = [NSTask new];
        t.executableURL = [NSURL fileURLWithPath:@"/bin/launchctl"];
        t.arguments = @[@"kickstart", [NSString stringWithFormat:@"gui/%u/dev.amannhq.arcpatches.watch", getuid()]];
        [t launchAndReturnError:nil];
    }];
}
