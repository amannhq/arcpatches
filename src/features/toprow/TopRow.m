// Arc's top row in the tab sidebar header: a sidebar toggle right after the window
// buttons (it runs Dia's own Hide/Show Sidebar action), with back, forward and reload
// staying right-aligned (src/features/sidebar). In full screen the window buttons and
// the space they reserve go away, so the row starts with the toggle.
#import "Common.h"
#import "Features.h"
#import "Browser.h"
#import <objc/runtime.h>

NSString *const TweakKeyHideWindowButtonsInFullScreen = @"arcpatches.hideWindowButtonsInFullScreen";
NSString *const TweakKeySidebarToggleButton = @"arcpatches.sidebarToggleButton";

static const CGFloat kButtonSize = 26;      // same as the back/forward/reload buttons
static const CGFloat kGap = 4;              // between the window buttons and the toggle
static const CGFloat kLeadingInset = 8;     // until the window buttons' inset is known
static const CGFloat kWindowButtonsEnd = 76;  // x after the window buttons, if they can't be found
static const CGFloat kRightReserve = 90;    // the nav buttons' area on the right
static const void *kToggleKey = &kToggleKey;
static const void *kInsetKey = &kInsetKey;
static const void *kHidByUsKey = &kHidByUsKey;
static const void *kExitingKey = &kExitingKey;

static void (*origHeaderLayout)(id, SEL);
static NSSize (*origButtonsSize)(id, SEL);
static NSHashTable<NSView *> *gHeaders;
static BOOL gApplying;

#pragma mark - Sidebar toggle

static NSMenuItem *menuItemWithAction(NSMenu *menu, SEL action) {
    for (NSMenuItem *item in menu.itemArray) {
        if (item.action == action) return item;
        NSMenuItem *hit = item.submenu ? menuItemWithAction(item.submenu, action) : nil;
        if (hit) return hit;
    }
    return nil;
}

// Dia's menu item first (whatever its title or language), then the responder chain.
static void toggleSidebar(NSWindow *window) {
    SEL action = NSSelectorFromString(kDiaToggleSidebarAction);
    NSMenuItem *item = menuItemWithAction(NSApp.mainMenu, action);
    if (item && [NSApp sendAction:item.action to:item.target from:item]) return;
    if (window && !window.isKeyWindow) [window makeKeyWindow];
    if ([NSApp sendAction:action to:nil from:item]) return;
    NSLog(@"[arcpatches] no menu item or responder handles %@; sidebar toggle did nothing", kDiaToggleSidebarAction);
}

@interface TweakSidebarToggleButton : NSButton
@end

@implementation TweakSidebarToggleButton
- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.image = [NSImage imageWithSystemSymbolName:@"sidebar.left" accessibilityDescription:@"Toggle Sidebar"];
    self.imagePosition = NSImageOnly;
    self.bordered = NO;
    self.toolTip = @"Hide or show the sidebar";
    self.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium];
    self.contentTintColor = NSColor.secondaryLabelColor;
    self.target = self;
    self.action = @selector(tap:);
    return self;
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

// Hides only buttons Dia shows, and restores only what it hid: Dia hides them itself
// in some states and must keep doing so.
static void applyWindowButtons(NSView *buttons, BOOL hide) {
    if (hide && !buttons.hidden) {
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
    } else if (!hide && hidByUs(buttons)) {
        objc_setAssociatedObject(buttons, kHidByUsKey, nil, OBJC_ASSOCIATION_RETAIN);
        buttons.hidden = NO;
        [buttons invalidateIntrinsicContentSize];
    }
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
        toggle = [[TweakSidebarToggleButton alloc] initWithFrame:NSZeroRect];
        objc_setAssociatedObject(header, kToggleKey, toggle, OBJC_ASSOCIATION_RETAIN);
    }
    if (toggle.superview != header) [header addSubview:toggle];   // appended: never first

    NSRect bf = buttons ? [buttons convertRect:buttons.bounds toView:header] : NSZeroRect;
    BOOL shown = buttons && !buttons.isHiddenOrHasHiddenAncestor && NSWidth(bf) > 1;
    if (shown) objc_setAssociatedObject(header, kInsetKey, @(NSMinX(bf)), OBJC_ASSOCIATION_RETAIN);
    NSNumber *inset = objc_getAssociatedObject(header, kInsetKey);
    CGFloat x = shown ? NSMaxX(bf) + kGap
              : (!buttons && !isFullScreen(header.window)) ? kWindowButtonsEnd
              : (inset ? inset.doubleValue : kLeadingInset);

    // Vertically centred like the nav buttons: on the header's own first subview.
    NSView *row = header.subviews.firstObject;
    CGFloat mid = row && row != toggle ? NSMidY(row.frame) : NSHeight(header.bounds) / 2;
    NSRect f = NSMakeRect(round(x), round(mid - kButtonSize / 2), kButtonSize, kButtonSize);
    setFrameIfChanged(toggle, f);
    setHiddenIfChanged(toggle, NSMaxX(f) > NSWidth(header.bounds) - kRightReserve);
}

// Re-entrancy guarded: hiding the buttons invalidates the header's layout, and the next
// pass then finds nothing left to change.
static void applyHeader(NSView *header) {
    if (gApplying || !header.window) return;
    gApplying = YES;
    NSView *buttons = TweakDescendantOfClass(header, kDiaWindowStandardButtonsClass);
    if (buttons)
        applyWindowButtons(buttons, [TweakSettings boolForKey:TweakKeyHideWindowButtonsInFullScreen] && isFullScreen(header.window));
    placeToggle(header, buttons);
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
    [NSUserDefaults.standardUserDefaults registerDefaults:@{
        TweakKeyHideWindowButtonsInFullScreen: @YES,
        TweakKeySidebarToggleButton: @YES,
    }];
    Class headerClass = NSClassFromString(kDiaSidebarHeaderClass);
    if (!headerClass) { NSLog(@"[arcpatches] %@ not found; sidebar top row inactive", kDiaSidebarHeaderClass); return; }
    gHeaders = [NSHashTable weakObjectsHashTable];
    Class buttonsClass = NSClassFromString(kDiaWindowStandardButtonsClass);
    if (buttonsClass) origButtonsSize = (void *)TweakHook(buttonsClass, @selector(intrinsicContentSize), (IMP)hookedButtonsSize);
    else NSLog(@"[arcpatches] %@ not found; window buttons stay in full screen", kDiaWindowStandardButtonsClass);
    origHeaderLayout = (void *)TweakHook(headerClass, @selector(layout), (IMP)hookedHeaderLayout);

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    for (NSNotificationName n in @[NSWindowWillEnterFullScreenNotification, NSWindowDidEnterFullScreenNotification,
                                   NSWindowWillExitFullScreenNotification, NSWindowDidExitFullScreenNotification])
        [nc addObserverForName:n object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSWindow *w = note.object;
            BOOL exiting = n == NSWindowWillExitFullScreenNotification;
            objc_setAssociatedObject(w, kExitingKey, exiting ? @YES : nil, OBJC_ASSOCIATION_RETAIN);
            reapplyWindow(w);
        }];
    [nc addObserverForName:TweakSettingsDidChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n) {
        reapplyWindow(nil);
    }];
}

const TweakFeature TweakFeatureTopRow = {"toprow", {TWEAK_BROWSER_DIA}, NULL, installTopRow};
