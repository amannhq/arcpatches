// A pinned tab's live address. Dia's scripting reports a pinned tab's saved URL (its
// home), not the page it has navigated to, and nothing else on the tab exposes the live
// one. Dia's own Copy URL command does use the live page, so for pinned tabs this runs
// it with the general pasteboard swapped for a private one: the user's clipboard is
// never touched, and any "Copied" toast Dia shows for it is put away at once.
#import "Common.h"
#import "Browser.h"
#import <objc/runtime.h>

static const NSTimeInterval kCacheFor = 1.0;
static NSPasteboard *gCapture;
static BOOL gDisabled;   // set if Dia ever wrote the real clipboard despite the swap
static NSPasteboard *capturedGeneral(id self, SEL _cmd) { return gCapture; }

static NSMenuItem *itemWithAction(NSMenu *menu, SEL action, NSMenu **owner) {
    for (NSMenuItem *i in menu.itemArray) {
        if (i.action == action) { *owner = menu; return i; }
        NSMenuItem *hit = i.submenu ? itemWithAction(i.submenu, action, owner) : nil;
        if (hit) return hit;
    }
    return nil;
}

static NSSet<NSWindow *> *visibleToasts(void) {
    NSMutableSet *set = [NSMutableSet set];
    for (NSWindow *w in NSApp.windows)
        if (w.isVisible && [NSStringFromClass(w.class) containsString:@"Toast"]) [set addObject:w];
    return set;
}

// Runs Dia's Copy URL into a private pasteboard and returns what it wrote, or nil.
static NSString *capture(void) {
    NSMenu *owner = nil;
    NSMenuItem *item = itemWithAction(NSApp.mainMenu, NSSelectorFromString(kDiaCopyURLAction), &owner);
    if (!item || !owner) return nil;
    [owner update];
    if (!item.isEnabled) return nil;

    if (gDisabled) return nil;
    NSSet *toastsBefore = visibleToasts();
    NSInteger generalCount = NSPasteboard.generalPasteboard.changeCount;
    gCapture = [NSPasteboard pasteboardWithUniqueName];
    [gCapture clearContents];
    Method general = class_getClassMethod(NSPasteboard.class, @selector(generalPasteboard));
    IMP original = method_setImplementation(general, (IMP)capturedGeneral);
    @try {
        [owner performActionForItemAtIndex:[owner indexOfItem:item]];
    } @catch (__unused NSException *e) {
    } @finally {
        method_setImplementation(general, original);
    }
    NSString *url = [gCapture stringForType:NSPasteboardTypeURL] ?: [gCapture stringForType:NSPasteboardTypeString];
    [gCapture releaseGlobally];
    gCapture = nil;
    if (NSPasteboard.generalPasteboard.changeCount != generalCount) {
        gDisabled = YES;   // Dia didn't go through +generalPasteboard: never touch the clipboard again
        NSLog(@"[arcpatches] Copy URL wrote the clipboard directly; live URLs for pinned tabs are off this session");
        return nil;
    }

    // A toast that appeared for this copy would claim the user copied something.
    void (^hideNew)(void) = ^{
        for (NSWindow *w in visibleToasts())
            if (![toastsBefore containsObject:w]) [w orderOut:nil];
    };
    hideNew();
    dispatch_async(dispatch_get_main_queue(), hideNew);
    return [url hasPrefix:@"http"] || [url containsString:@"://"] ? url : nil;
}

NSString *TweakLiveURLForPinnedTab(NSWindow *window) {
    // Copy URL acts on the key window's focused tab.
    if (!window || window != NSApp.keyWindow || !NSThread.isMainThread) return nil;
    static __weak NSWindow *cachedWindow;
    static NSString *cachedURL;
    static NSTimeInterval cachedAt;
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (cachedWindow == window && now - cachedAt < kCacheFor) return cachedURL;
    cachedURL = capture();
    cachedWindow = window;
    cachedAt = now;
    return cachedURL;
}
