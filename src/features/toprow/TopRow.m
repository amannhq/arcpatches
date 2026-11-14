// Arc's top row in the tab sidebar header: a sidebar toggle right after the window
// buttons (it runs Dia's own Hide/Show Sidebar action), with back, forward and reload
// staying right-aligned (src/features/sidebar). In full screen the window buttons and
// the space they reserve go away, so the row starts with the toggle.
#import "Common.h"
#import "Features.h"
#import "Browser.h"
#import "../sidebar/ChromeButton.h"
#import "FullScreenButtons.h"
#import <objc/runtime.h>

NSString *const TweakKeyHideWindowButtonsInFullScreen = @"arcpatches.hideWindowButtonsInFullScreen";
NSString *const TweakKeySidebarToggleButton = @"arcpatches.sidebarToggleButton";
NSString *const TweakKeyTopRowProfileName = @"arcpatches.topRowProfileName";

static const CGFloat kButtonSize = ArcTopRowButton;   // same as the back/forward/reload buttons
static const CGFloat kGap = 1;              // between the window buttons and the toggle's fill
static const CGFloat kLeadingInset = ArcSpace2;   // until the window buttons' inset is known
static const CGFloat kWindowButtonsEnd = 76;  // x after the window buttons, if they can't be found
static const CGFloat kRightReserve = 3 * ArcTopRowButton + ArcSidebarInset + ArcSpace1;   // the nav buttons and their inset, plus a gap
static const void *kToggleKey = &kToggleKey;
static const void *kInsetKey = &kInsetKey;
static const void *kHidByUsKey = &kHidByUsKey;
static const void *kExitingKey = &kExitingKey;
static const void *kRehideKey = &kRehideKey;   // @[start, count] of recent re-hides
static const void *kGaveUpKey = &kGaveUpKey;
static const void *kProfileHiddenKey = &kProfileHiddenKey;

static void (*origHeaderLayout)(id, SEL);
static NSSize (*origButtonsSize)(id, SEL);
static NSHashTable<NSView *> *gHeaders;
static BOOL gApplying;

#pragma mark - Sidebar toggle

// Dia's own View ▸ Auto-Hide Tabs, found by its shortcut (its action is a generic one).
static void toggleSidebar(NSWindow *window) {
    if (window && !window.isKeyWindow) [window makeKeyWindow];
    if (!TweakPerformMenuShortcut(kDiaToggleSidebarKey, NSEventModifierFlagCommand))
        NSLog(@"[arcpatches] no enabled ⌘%@ menu item; sidebar toggle did nothing", kDiaToggleSidebarKey.uppercaseString);
}

// The same button as back/forward/reload (hover fill, pressed state, no focus ring).
@interface TweakSidebarToggleButton : TweakChromeButton
@end

@implementation TweakSidebarToggleButton
+ (instancetype)toggle {
    TweakSidebarToggleButton *b = [self buttonWithSymbol:@"sidebar.left" label:@"Toggle Sidebar" pointSize:ArcTopRowIcon
                                                  radius:ArcRadiusMedium target:nil action:@selector(tap:)];
    b.target = b;
    return b;
}
- (void)tap:(id)sender { toggleSidebar(self.window); }
@end

#pragma mark - Window buttons in full screen

// Until the exit animation starts: the buttons come back as the window shrinks.
static BOOL isFullScreen(NSWindow *w) {
    return w && (w.styleMask & NSWindowStyleMaskFullScreen) && !objc_getAssociatedObject(w, kExitingKey);
}

static BOOL hidByUs(NSView *buttons) { return [objc_getAssociatedObject(buttons, kHidByUsKey) boolValue]; }

// While hidden by us the buttons also report no width, so the header's stack (or any
// constraint built on their intrinsic size) gives the space back.
static NSSize hookedButtonsSize(NSView *self, SEL _cmd) {
    NSSize s = origButtonsSize(self, _cmd);
    if (hidByUs(self)) s.width = 0;
    return s;
}

// Dia re-showing the buttons on every pass would make hiding them a layout loop across
// passes: after a few re-hides within a second, leave that view to Dia.
static BOOL gaveUp(NSView *buttons) {
    if (!hidByUs(buttons)) return NO;   // first hide, or Dia hid them meanwhile
    NSArray *s = objc_getAssociatedObject(buttons, kRehideKey) ?: @[@0, @0];
    NSTimeInterval now = NSDate.timeIntervalSinceReferenceDate, start = [s[0] doubleValue];
    NSInteger count = now - start < 1 ? [s[1] integerValue] + 1 : 1;
    objc_setAssociatedObject(buttons, kRehideKey, @[@(count == 1 ? now : start), @(count)], OBJC_ASSOCIATION_RETAIN);
    if (count <= 5) return NO;
    NSLog(@"[arcpatches] Dia keeps showing the window buttons in full screen; leaving them");
    objc_setAssociatedObject(buttons, kGaveUpKey, @YES, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(buttons, kHidByUsKey, nil, OBJC_ASSOCIATION_RETAIN);
    [buttons invalidateIntrinsicContentSize];
    return YES;
}

// Hides only buttons Dia shows, and restores only what it hid: Dia hides them itself
// in some states and must keep doing so.
static void applyWindowButtons(NSView *buttons, BOOL hide) {
    if (hide && objc_getAssociatedObject(buttons, kGaveUpKey)) return;
    if (hide && !buttons.hidden && !gaveUp(buttons)) {
        objc_setAssociatedObject(buttons, kHidByUsKey, @YES, OBJC_ASSOCIATION_RETAIN);
        buttons.hidden = YES;
        [buttons invalidateIntrinsicContentSize];
        static BOOL logged;
        NSStackView *stack = (NSStackView *)buttons.superview;
        BOOL detaches = [stack isKindOfClass:NSStackView.class] && [stack.arrangedSubviews containsObject:buttons] && stack.detachesHiddenViews;
        if (!detaches && !logged) {
            logged = YES;
            NSLog(@"[arcpatches] window buttons aren't in a stack view that detaches hidden views; relying on zero width");
        }
    }
    if (hide) return;
    objc_setAssociatedObject(buttons, kGaveUpKey, nil, OBJC_ASSOCIATION_RETAIN);   // next full screen tries again
    if (hidByUs(buttons)) {
        objc_setAssociatedObject(buttons, kHidByUsKey, nil, OBJC_ASSOCIATION_RETAIN);
        buttons.hidden = NO;
        [buttons invalidateIntrinsicContentSize];
    }
}

#pragma mark - Profile name

// Arc's top row has no space name, and Dia's would sit under the nav buttons. Hidden
// with alpha, not `hidden`, so Dia's own layout of the row is unchanged; restored only
// where we hid it.
static void collectProfileViews(NSView *v, NSMutableArray *out, int depth) {
    if (depth > 6) return;
    for (NSView *s in v.subviews) {
        if ([NSStringFromClass(s.class) hasSuffix:kDiaProfileIndicatorSuffix]) [out addObject:s];
        else collectProfileViews(s, out, depth + 1);
    }
}

static void applyProfileName(NSView *header) {
    BOOL hide = ![TweakSettings boolForKey:TweakKeyTopRowProfileName];
    NSMutableArray *views = [NSMutableArray array];
    collectProfileViews(header, views, 0);
    for (NSView *v in views) {
        BOOL ours = [objc_getAssociatedObject(v, kProfileHiddenKey) boolValue];
        if (hide && v.alphaValue > 0) {
            v.alphaValue = 0;
            objc_setAssociatedObject(v, kProfileHiddenKey, @YES, OBJC_ASSOCIATION_RETAIN);
        } else if (!hide && ours) {
            v.alphaValue = 1;
            objc_setAssociatedObject(v, kProfileHiddenKey, nil, OBJC_ASSOCIATION_RETAIN);
        }
    }
}

// Hidden by alpha it would still take clicks meant for the nav buttons on top of it.
static NSView *(*origProfileHitTest)(id, SEL, NSPoint);
static NSView *hookedProfileHitTest(NSView *self, SEL _cmd, NSPoint p) {
    if ([objc_getAssociatedObject(self, kProfileHiddenKey) boolValue]) return nil;
    return origProfileHitTest(self, _cmd, p);
}

#pragma mark - Header layout

static void setFrameIfChanged(NSView *v, NSRect f) { if (!NSEqualRects(v.frame, f)) v.frame = f; }
static void setHiddenIfChanged(NSView *v, BOOL h) { if (v.hidden != h) v.hidden = h; }

static void placeToggle(NSView *header, NSView *buttons) {
    NSButton *toggle = objc_getAssociatedObject(header, kToggleKey);
    // Not while the header is still empty: the nav buttons centre on its first subview.
    if (![TweakSettings boolForKey:TweakKeySidebarToggleButton] || !header.subviews.count) {
        [toggle removeFromSuperview];
        return;
    }
    if (!toggle) {
        toggle = [TweakSidebarToggleButton toggle];
        objc_setAssociatedObject(header, kToggleKey, toggle, OBJC_ASSOCIATION_RETAIN);
    }
    if (toggle.superview != header) [header addSubview:toggle];   // appended: never first

    NSRect bf = buttons ? [buttons convertRect:buttons.bounds toView:header] : NSZeroRect;
    BOOL shown = buttons && !buttons.isHiddenOrHasHiddenAncestor && NSWidth(bf) > 1;
    if (shown) objc_setAssociatedObject(header, kInsetKey, @(NSMinX(bf)), OBJC_ASSOCIATION_RETAIN);
    NSNumber *inset = objc_getAssociatedObject(header, kInsetKey);
    // In full screen the toggle starts the row, its hover square on the URL pill's edge.
    CGFloat x = shown ? NSMaxX(bf) + kGap
              : isFullScreen(header.window) ? ArcSidebarInset
              : !buttons ? kWindowButtonsEnd
              : (inset ? inset.doubleValue : kLeadingInset);

    // Vertically centred like the nav buttons: on the header's own first subview.
    NSView *row = header.subviews.firstObject;
    CGFloat mid = row && row != toggle ? NSMidY(row.frame) : NSHeight(header.bounds) / 2;
    NSRect f = NSMakeRect(round(x), round(mid - kButtonSize / 2), kButtonSize, kButtonSize);
    setFrameIfChanged(toggle, f);
    // Back/forward/reload are placed during the sidebar's layout, before Dia settles this
    // row: put them on the toggle's line here, after it has.
    for (NSView *v in header.subviews) {
        if (![NSStringFromClass(v.class) isEqualToString:@"TweakNavButtons"]) continue;
        NSRect nf = v.frame;
        nf.origin.y = NSMinY(f);
        setFrameIfChanged(v, nf);
    }
    setHiddenIfChanged(toggle, NSMaxX(f) > NSWidth(header.bounds) - kRightReserve);
}

// Re-entrancy guarded: hiding the buttons invalidates the header's layout, and the next
// pass then finds nothing left to change.
static void applyHeader(NSView *header) {
    if (gApplying || !header.window) return;
    gApplying = YES;
    NSView *buttons = TweakDescendantOfClass(header, kDiaWindowStandardButtonsClass);
    BOOL full = isFullScreen(header.window);
    TweakTopRowSetMinimizeAllowed(header.window, !full);
    // In full screen they live in the title strip that slides down from the top edge
    // (FullScreenButtons.m), never in this row: as in Arc.
    BOOL strip = full && [TweakSettings boolForKey:TweakKeyHideWindowButtonsInFullScreen];
    TweakFullScreenStripSetActive(header.window, strip);
    if (buttons) applyWindowButtons(buttons, strip);
    placeToggle(header, buttons);
    applyProfileName(header);
    TweakDownloadsReplace(header);
    gApplying = NO;
}

static void hookedHeaderLayout(NSView *self, SEL _cmd) {
    origHeaderLayout(self, _cmd);
    [gHeaders addObject:self];
    applyHeader(self);
}

// Outside any layout pass: now, and again once AppKit's full-screen animation
// (which moves the title bar and its buttons) has settled.
static void reapplyWindow(NSWindow *w) {
    void (^apply)(void) = ^{
        for (NSView *h in gHeaders.allObjects) {
            if (w && h.window != w) continue;
            applyHeader(h);
            h.needsLayout = YES;
        }
    };
    dispatch_async(dispatch_get_main_queue(), apply);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), apply);
}

#pragma mark - Install

static void installTopRow(void) {
    TweakDownloadsInstall();
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        TweakKeyHideWindowButtonsInFullScreen: @YES,
        TweakKeySidebarToggleButton: @YES,
        TweakKeyTopRowProfileName: @NO,
    }];
    Class headerClass = NSClassFromString(kDiaSidebarHeaderClass);
    if (!headerClass) { NSLog(@"[arcpatches] %@ not found; sidebar top row inactive", kDiaSidebarHeaderClass); return; }
    gHeaders = [NSHashTable weakObjectsHashTable];
    Class buttonsClass = NSClassFromString(kDiaWindowStandardButtonsClass);
    if (buttonsClass) origButtonsSize = (void *)TweakHook(buttonsClass, @selector(intrinsicContentSize), (IMP)hookedButtonsSize);
    else NSLog(@"[arcpatches] %@ not found; window buttons stay in full screen", kDiaWindowStandardButtonsClass);
    origHeaderLayout = (void *)TweakHook(headerClass, @selector(layout), (IMP)hookedHeaderLayout);
    Class profileClass = TweakFindClass(kDiaSidebarRootPrefix, kDiaProfileIndicatorSuffix);
    if (profileClass) origProfileHitTest = (void *)TweakHook(profileClass, @selector(hitTest:), (IMP)hookedProfileHitTest);
    else NSLog(@"[arcpatches] %@ not found; profile name stays in the top row", kDiaProfileIndicatorSuffix);

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    for (NSNotificationName n in @[NSWindowWillEnterFullScreenNotification, NSWindowDidEnterFullScreenNotification,
                                   NSWindowWillExitFullScreenNotification, NSWindowDidExitFullScreenNotification])
        [nc addObserverForName:n object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSWindow *w = note.object;
            BOOL exiting = n == NSWindowWillExitFullScreenNotification;
            id token = exiting ? [NSObject new] : nil;
            objc_setAssociatedObject(w, kExitingKey, token, OBJC_ASSOCIATION_RETAIN);
            reapplyWindow(w);
            // A failed exit has no notification (only the delegate's windowDidFailToExitFullScreen:,
            // which is Dia's): if no DidExit came, the window stayed in full screen.
            if (!exiting) return;
            __weak NSWindow *weakWindow = w;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSWindow *sw = weakWindow;
                if (!sw || objc_getAssociatedObject(sw, kExitingKey) != token) return;
                objc_setAssociatedObject(sw, kExitingKey, nil, OBJC_ASSOCIATION_RETAIN);
                reapplyWindow(sw);
            });
        }];
    [nc addObserverForName:TweakSettingsDidChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n) {
        reapplyWindow(nil);
    }];
}

const TweakFeature TweakFeatureTopRow = {"toprow", {TWEAK_BROWSER_DIA}, NULL, installTopRow};
