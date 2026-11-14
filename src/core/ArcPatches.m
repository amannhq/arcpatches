// arcpatches entry point: finds which supported browser this is, then installs the
// features that support it (early hooks now, the rest once AppKit is up).
#import "Common.h"
#import "Features.h"
#import "Browser.h"
#import "Browsers.h"
#include <stdlib.h>

// In install order.
static const TweakFeature *const kFeatures[] = {
    &TweakFeaturePrivacy, &TweakFeaturePerformance, &TweakFeatureTabs,
    &TweakFeatureSidebar, &TweakFeaturePreferences, &TweakFeatureCommandBar, &TweakFeatureShortcuts,
    &TweakFeatureTopRow,
};
static const size_t kFeatureCount = sizeof kFeatures / sizeof kFeatures[0];

// The browsers this build knows (Browsers.m), by bundle id. Dia Arc keeps Dia's.
static NSString *detectBrowser(void) {
    return TweakBrowserIdForBundleId(NSBundle.mainBundle.bundleIdentifier);
}

static BOOL anyFeatureActive(void) {
    for (size_t i = 0; i < kFeatureCount; i++)
        if (TweakFeatureActive(kFeatures[i])) return YES;
    return NO;
}

static void installKeyMonitor(void) {
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *e) {
        // Only ⌘⌃⌥⇧: Caps Lock and Fn must not break the equality checks below.
        NSEventModifierFlags mods = e.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl |
                                                       NSEventModifierFlagOption | NSEventModifierFlagShift);
        NSString *key = e.charactersIgnoringModifiers.lowercaseString;
        BOOL sidebar = TweakFeatureActive(&TweakFeatureSidebar), commandBar = TweakFeatureActive(&TweakFeatureCommandBar);
        if (TweakFeatureActive(&TweakFeatureShortcuts) && TweakShortcutsHandle(e)) return nil;
        if (sidebar && mods == (NSEventModifierFlagControl | NSEventModifierFlagCommand) && [key isEqualToString:@"u"]) {
            [TweakSettings toggleHiding];
            return nil;
        }
        NSWindow *w = e.window ?: NSApp.keyWindow;
        BOOL native = TweakCommandBarCurrentStyle() == TweakCommandBarStyleNative;
        if (commandBar && mods == NSEventModifierFlagCommand && [key isEqualToString:@"t"] && (native ? TweakCommandBarShow(w, YES) : TweakPaletteOpen(w)))
            return nil;
        if (commandBar && mods == NSEventModifierFlagCommand && [key isEqualToString:@"l"] && native && TweakCommandBarShow(w, NO))
            return nil;
        if (sidebar && mods == NSEventModifierFlagCommand && [key isEqualToString:@"l"] &&
            TweakSettings.urlBarMode == TweakURLBarModeSidebar && TweakSettings.cmdLFocusesSidebar &&
            TweakSidebarFocusURLBar(e.window ?: NSApp.keyWindow))
            return nil;
        return e;
    }];
}

// The app menu shows "Dia Arc". CFBundleName stays "Dia" (it names the profile folder),
// so the title is set here instead.
static void showPatchedName(void) {
    NSString *title = [TweakBrowserDisplayName(TweakRunningBrowser()) stringByAppendingString:@" \u2726"];
    NSMenu *appMenu = NSApp.mainMenu.itemArray.firstObject.submenu;
    if (appMenu && ![appMenu.title isEqualToString:title]) appMenu.title = title;
}

__attribute__((constructor)) static void init(void) {
    // Don't leak into Chromium helper processes.
    unsetenv("DYLD_INSERT_LIBRARIES");
    NSString *browser = detectBrowser();
    if (!browser) { NSLog(@"[arcpatches] %@ is not a supported browser; nothing installed", NSBundle.mainBundle.bundleIdentifier); return; }
    TweakSetRunningBrowser(browser);
    if (!anyFeatureActive()) { NSLog(@"[arcpatches] no feature supports %@ yet; nothing installed", browser); return; }
    // Privacy's URLSession hooks must exist before the browser creates its sessions;
    // Tabs must see its browsers and tabs as they're created.
    for (size_t i = 0; i < kFeatureCount; i++)
        if (kFeatures[i]->early && TweakFeatureActive(kFeatures[i])) kFeatures[i]->early();
    dispatch_async(dispatch_get_main_queue(), ^{
        for (size_t i = 0; i < kFeatureCount; i++)
            if (kFeatures[i]->install && TweakFeatureActive(kFeatures[i])) kFeatures[i]->install();
        installKeyMonitor();
        TweakDevDumpInstall();
        showPatchedName();
        if ([browser isEqualToString:kDiaBrowserID]) TweakHandoffInstall();   // the companion's handoff opens Dia only
        [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *n) { showPatchedName(); }];
        NSLog(@"[arcpatches] installed");
        TweakHealthWrite();
        TweakKickCompanionOnQuit();
    });
}
