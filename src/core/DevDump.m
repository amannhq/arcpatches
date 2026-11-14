// Developer aid: writes every window's view tree to
// ~/Library/Application Support/arcpatches/views.txt (and menus.txt) when another process posts the
// distributed notification below. Read-only: nothing in the browser changes.
// Off unless developer tools are on (then relaunch the browser):
//   defaults write company.thebrowser.dia arcpatches.devTools -bool YES
//   swift -e 'import Foundation; DistributedNotificationCenter.default().postNotificationName(.init("dev.amannhq.arcpatches.dump"), object: nil, userInfo: nil, deliverImmediately: true)'
#import "Common.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const kDumpNotification = @"dev.amannhq.arcpatches.dump";

static void dumpView(NSView *v, NSMutableString *out, int depth) {
    if (depth > 40) return;
    NSRect f = v.frame;
    [out appendFormat:@"%*s%@ (%.0f,%.0f %.0fx%.0f)%@%@%@%@\n", depth * 2, "", NSStringFromClass(v.class),
        f.origin.x, f.origin.y, f.size.width, f.size.height,
        v.hidden ? @" hidden" : @"", v.alphaValue < 1 ? [NSString stringWithFormat:@" alpha=%.2f", v.alphaValue] : @"",
        v.trackingAreas.count ? [NSString stringWithFormat:@" tracking=%lu", (unsigned long)v.trackingAreas.count] : @"",
        [v isKindOfClass:NSTextField.class] ? [NSString stringWithFormat:@" \"%@\"", [(NSTextField *)v stringValue]]
            : [v isKindOfClass:NSTextView.class] ? [NSString stringWithFormat:@" text=\"%@\"", [[(NSTextView *)v string] substringToIndex:MIN((NSUInteger)200, [(NSTextView *)v string].length)]] : @""];
    // Where a page's live URL might be kept: probe a few likely keys, read-only.
    for (NSString *k in @[@"url", @"URL", @"webContentURL", @"currentURL", @"displayURL"]) {
        @try {
            if (![v respondsToSelector:NSSelectorFromString(k)]) continue;
            id val = [v valueForKey:k];
            if (val) [out appendFormat:@"%*s  %@=%@\n", depth * 2, "", k, val];
        } @catch (__unused NSException *e) {}
    }
    if ([v respondsToSelector:@selector(hovering)]) {
        NSPoint p = [v convertPoint:v.window.mouseLocationOutsideOfEventStream fromView:nil];
        [out appendFormat:@"%*s  hovering=%d pointer=%@\n", depth * 2, "", ((BOOL (*)(id, SEL))objc_msgSend)(v, @selector(hovering)), NSStringFromPoint(p)];
    }
    for (NSView *s in v.subviews) dumpView(s, out, depth + 1);
}

static void dumpAll(void) {
    NSMutableString *out = [NSMutableString string];
    for (NSWindow *w in NSApp.windows) {
        if (!w.isVisible) continue;
        [out appendFormat:@"=== %@ \"%@\" key=%d fullscreen=%d frame=%@\n", NSStringFromClass(w.class), w.title, w.isKeyWindow,
            (w.styleMask & NSWindowStyleMaskFullScreen) != 0, NSStringFromRect(w.frame)];
        if (w.contentView.superview) dumpView(w.contentView.superview, out, 0);
    }
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [out writeToFile:[dir stringByAppendingPathComponent:@"views.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void dumpMenu(NSMenu *menu, NSMutableString *out, int depth) {
    for (NSMenuItem *i in menu.itemArray) {
        if (i.isSeparatorItem) continue;
        NSString *mods = [NSString stringWithFormat:@"%@%@%@%@",
            i.keyEquivalentModifierMask & NSEventModifierFlagControl ? @"⌃" : @"", i.keyEquivalentModifierMask & NSEventModifierFlagOption ? @"⌥" : @"",
            i.keyEquivalentModifierMask & NSEventModifierFlagShift ? @"⇧" : @"", i.keyEquivalentModifierMask & NSEventModifierFlagCommand ? @"⌘" : @""];
        [out appendFormat:@"%*s%@%@%@ [%@]\n", depth * 2, "", i.title, i.keyEquivalent.length ? [@"  " stringByAppendingString:mods] : @"",
            i.keyEquivalent.uppercaseString, i.action ? NSStringFromSelector(i.action) : @"-"];
        if (i.submenu && depth < 4) dumpMenu(i.submenu, out, depth + 1);
    }
}


// Every zero-argument method whose name mentions a URL on the key window's active
// scripting tab, with its value: where a pinned tab's live address might be kept.
static void dumpActiveTab(void) {
    NSMutableString *out = [NSMutableString string];
    id tab = TweakActiveTabForWindow(NSApp.keyWindow ?: NSApp.mainWindow ?: NSApp.windows.firstObject);
    for (Class c = [tab class]; c && c != NSObject.class; c = class_getSuperclass(c)) {
        [out appendFormat:@"class %@\n", NSStringFromClass(c)];
        unsigned n = 0;
        Method *ms = class_copyMethodList(c, &n);
        for (unsigned i = 0; i < n; i++) {
            SEL sel = method_getName(ms[i]);
            NSString *name = NSStringFromSelector(sel);
            if ([name containsString:@":"] || [name rangeOfString:@"url" options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
            const char *ret = method_copyReturnType(ms[i]);
            BOOL object = ret && ret[0] == '@';
            free((void *)ret);
            id val = nil;
            if (object) @try { val = ((id (*)(id, SEL))objc_msgSend)(tab, sel); } @catch (__unused NSException *e) {}
            [out appendFormat:@"  %@ = %@\n", name, object ? val : @"(not an object)"];
        }
        free(ms);
    }
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
    [out writeToFile:[dir stringByAppendingPathComponent:@"tab.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@interface TweakDevDumpObserver : NSObject
@end
@implementation TweakDevDumpObserver
- (void)dump:(NSNotification *)n {
    dispatch_async(dispatch_get_main_queue(), ^{
        dumpAll();
        dumpActiveTab();
        NSMutableString *menus = [NSMutableString string];
        dumpMenu(NSApp.mainMenu, menus, 0);
        NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
        [menus writeToFile:[dir stringByAppendingPathComponent:@"menus.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
}
@end

static TweakDevDumpObserver *gDumpObserver;

void TweakDevDumpInstall(void) {
    // A background app's distributed notifications are held until it's active, unless
    // the observer asks for immediate delivery.
    gDumpObserver = [TweakDevDumpObserver new];
    [NSDistributedNotificationCenter.defaultCenter addObserver:gDumpObserver selector:@selector(dump:) name:kDumpNotification object:nil
                                            suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
}
