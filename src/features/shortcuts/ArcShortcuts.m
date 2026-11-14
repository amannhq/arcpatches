// Arc's own shortcuts, on by default (Settings › ArcPatches › Arc shortcuts): ⌘⇧C copies
// the page's URL without tracking parameters, ⌘⇧⌥C copies it as a Markdown link and ⌘S
// shows or hides the sidebar. Each is checked against Dia's menu before it acts: if Dia
// gives the same keys to a different command, the shortcut stays unbound (and says so in
// the log and in Settings) until that command is remapped in Dia's Keyboard Shortcuts.
// Not included: Arc's ⌘⇧K (clear unpinned tabs). Dia has no menu command or selector for
// it, only the sidebar's "Close all unpinned tabs" button.
#import "Common.h"
#import "CleanURL.h"
#import "ArcStyle.h"

static const NSEventModifierFlags kMods = NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift | NSEventModifierFlagCommand;
typedef BOOL (*TweakArcAction)(NSWindow *);   // NO: nothing done, the key goes on to Dia
static const CGFloat kToastTop = 52;   // clear of the window controls

#pragma mark - "Copied"

@interface TweakCopiedBadge : NSView
@end

@implementation TweakCopiedBadge
- (NSView *)hitTest:(NSPoint)point { return nil; }   // never takes clicks from the page
- (BOOL)wantsUpdateLayer { return YES; }
// A panel's near-opaque wash, not a translucent fill: it has to read over any page.
- (void)updateLayer {
    self.layer.backgroundColor = ArcPanelTint().CGColor;
    self.layer.borderColor = ArcPanelBorder().CGColor;
}
@end

// Only when the window shows no sidebar URL pill to confirm in: a small chip near the
// top of the window that fades out on its own.
static void showToast(NSWindow *w, NSString *message) {
    NSView *host = w.contentView;
    if (!host) return;
    for (NSView *v in host.subviews.copy)
        if ([v isKindOfClass:TweakCopiedBadge.class]) [v removeFromSuperview];
    NSTextField *label = [NSTextField labelWithString:message];
    label.font = ArcFontChip();
    label.textColor = NSColor.labelColor;
    NSSize text = label.fittingSize;
    NSSize size = NSMakeSize(ceil(text.width) + 2 * ArcSpace3, ceil(text.height) + 2 * ArcSpace2);
    NSRect frame = NSMakeRect(round(NSMidX(host.bounds) - size.width / 2),
                              host.isFlipped ? kToastTop : NSMaxY(host.bounds) - kToastTop - size.height, size.width, size.height);
    TweakCopiedBadge *badge = [[TweakCopiedBadge alloc] initWithFrame:frame];
    badge.wantsLayer = YES;
    badge.layer.borderWidth = 1;
    ArcRound(badge.layer, ArcRadiusMedium);
    label.frame = NSMakeRect(ArcSpace3, round((size.height - text.height) / 2), ceil(text.width), ceil(text.height));
    [badge addSubview:label];
    badge.alphaValue = 0;
    [host addSubview:badge positioned:NSWindowAbove relativeTo:nil];
    ArcAnimate(ArcDurationFast, YES, ^(__unused NSAnimationContext *ctx) { badge.animator.alphaValue = 1; }, nil);
    __weak TweakCopiedBadge *weakBadge = badge;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ArcFeedbackHold * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!weakBadge.superview) return;
        ArcAnimate(ArcDurationMedium, NO, ^(__unused NSAnimationContext *ctx) { weakBadge.animator.alphaValue = 0; },
                   ^{ [weakBadge removeFromSuperview]; });
    });
    NSAccessibilityPostNotificationWithUserInfo(NSApp, NSAccessibilityAnnouncementRequestedNotification,
                                                @{NSAccessibilityAnnouncementKey: message});
}

#pragma mark - Actions

BOOL TweakCopyPageLink(NSWindow *w, BOOL markdown) {
    NSString *url = TweakLiveURLForWindow(w), *title = nil;
    if (!url.length || [url isEqualToString:@"about:blank"]) return NO;
    url = TweakCleanURL(url);
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    if (!markdown) {
        BOOL ok = [pb setString:url forType:NSPasteboardTypeString];
        if ([NSURL URLWithString:url]) [pb setString:url forType:NSPasteboardTypeURL];
        return ok;
    }
    @try {
        id t = [TweakActiveTabForWindow(w) valueForKey:@"title"];
        if ([t isKindOfClass:NSString.class]) title = t;
    } @catch (__unused NSException *e) {}
    return [pb setString:TweakMarkdownLink(title, url) forType:NSPasteboardTypeString];
}

// Confirms in the sidebar's URL pill, where Arc does, else with a toast.
static BOOL copyAndConfirm(NSWindow *w, BOOL markdown) {
    if (!TweakCopyPageLink(w, markdown)) return NO;
    if (!TweakSidebarShowCopiedFeedback(w)) showToast(w, markdown ? @"Copied as Markdown" : @"Copied");
    return YES;
}

static BOOL copyCleanURL(NSWindow *w) { return copyAndConfirm(w, NO); }
static BOOL copyMarkdownLink(NSWindow *w) { return copyAndConfirm(w, YES); }

#pragma mark - Table

static NSString *settingsKey(NSString *actionId) { return [@"arcpatches.arcShortcut." stringByAppendingString:actionId]; }

// {id, key, mods, same, title, detail, run}. "same": Dia's selectors for this very action,
// whose menu items may keep the keys without counting as a conflict.
static NSArray<NSDictionary *> *actions(void) {
    static NSArray *all;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSEventModifierFlags cs = NSEventModifierFlagCommand | NSEventModifierFlagShift;
        all = @[
            @{@"id": @"copyURL", @"key": @"c", @"mods": @(cs), @"same": @[@"copyCurrentURL:"],
              @"title": @"Copy URL", @"detail": @"Without tracking parameters such as utm_source, fbclid and gclid.",
              @"run": [NSValue valueWithPointer:copyCleanURL]},
            @{@"id": @"copyMarkdown", @"key": @"c", @"mods": @(cs | NSEventModifierFlagOption), @"same": @[@"copyCurrentURLAsMarkdown:"],
              @"title": @"Copy URL as Markdown", @"detail": @"Copies [page title](URL), tracking parameters removed.",
              @"run": [NSValue valueWithPointer:copyMarkdownLink]},
        ];
        NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
        for (NSDictionary *a in all) defaults[settingsKey(a[@"id"])] = @YES;
        [NSUserDefaults.standardUserDefaults registerDefaults:defaults];
    });
    return all;
}

static NSString *display(NSDictionary *a) { return TweakShortcutDisplay(@{@"mods": a[@"mods"], @"chars": a[@"key"]}); }

#pragma mark - Conflicts with Dia's menu

// The visible menu item holding these keys. Hidden items lose their key equivalents.
static NSMenuItem *itemWithKeys(NSMenu *menu, NSString *key, NSEventModifierFlags mods) {
    for (NSMenuItem *i in menu.itemArray) {
        if (i.hidden || i.separatorItem) continue;
        NSString *k = i.keyEquivalent, *lower = k.lowercaseString;
        NSEventModifierFlags m = (i.keyEquivalentModifierMask & kMods) | (![lower isEqualToString:k] ? NSEventModifierFlagShift : 0);
        if (k.length == 1 && m == mods && [lower isEqualToString:key]) return i;
        NSMenuItem *hit = i.submenu ? itemWithKeys(i.submenu, key, mods) : nil;
        if (hit) return hit;
    }
    return nil;
}

// The menu command that already owns the shortcut's keys, unless it's Dia's version of the same action.
// Checked on every use: Dia rebuilds its menus' key equivalents when its bindings change.
static NSMenuItem *conflictFor(NSDictionary *a) {
    NSMenuItem *i = itemWithKeys(NSApp.mainMenu, a[@"key"], [a[@"mods"] unsignedIntegerValue]);
    if (!i || (i.action && [a[@"same"] containsObject:NSStringFromSelector(i.action)])) return nil;
    return i;
}

static void logConflict(NSDictionary *a, NSMenuItem *item) {
    static NSMutableSet *logged;
    if (!logged) logged = [NSMutableSet set];
    if ([logged containsObject:a[@"id"]]) return;
    [logged addObject:a[@"id"]];
    NSLog(@"[arcpatches] %@ (%@) not bound: Dia's menu uses it for “%@” (%@)", a[@"title"], display(a), item.title,
          item.action ? NSStringFromSelector(item.action) : @"no action");
}

#pragma mark - Public

NSArray<NSDictionary *> *TweakArcShortcutSettings(void) {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *a in actions()) {
        NSMenuItem *c = conflictFor(a);
        NSString *detail = c ? [NSString stringWithFormat:@"%@ Not active: Dia uses %@ for “%@”. Change that in Dia's Keyboard Shortcuts settings to use it here.",
                                a[@"detail"], display(a), c.title] : a[@"detail"];
        [rows addObject:@{@"key": settingsKey(a[@"id"]), @"title": [NSString stringWithFormat:@"%@  %@", a[@"title"], display(a)], @"detail": detail}];
    }
    return rows;
}

BOOL TweakArcShortcutsHandle(NSEvent *e, NSWindow *w) {
    NSEventModifierFlags mods = e.modifierFlags & kMods;
    NSString *key = e.charactersIgnoringModifiers.lowercaseString;
    for (NSDictionary *a in actions()) {
        if ([a[@"mods"] unsignedIntegerValue] != mods || ![a[@"key"] isEqualToString:key]) continue;
        if (![TweakSettings boolForKey:settingsKey(a[@"id"])]) return NO;
        NSMenuItem *c = conflictFor(a);
        if (c) { logConflict(a, c); return NO; }
        if (e.isARepeat) return YES;   // held keys act once, and the repeats don't reach Dia either
        return ((TweakArcAction)[a[@"run"] pointerValue])(w);
    }
    return NO;
}

// Logs conflicts once Dia's menu has been built, without waiting for a key press.
void TweakArcShortcutsInstall(void) {
    actions();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        for (NSDictionary *a in actions()) {
            NSMenuItem *c = [TweakSettings boolForKey:settingsKey(a[@"id"])] ? conflictFor(a) : nil;
            if (c) logConflict(a, c);
        }
    });
}
