// Hides Dia's per-pane navigation bar (URL + back/forward/reload) and lets the
// web content fill the freed space. The bar can reappear as an overlay when the
// mouse touches the top edge of a pane, and stays while its URL field has focus.
#import "NavBarInternal.h"
#import "Browser.h"

static const CGFloat kRevealEdge = 6;   // px from pane top that triggers reveal
static const CGFloat kKeepMargin = 12;  // extra px below bar before it hides again

static CGFloat gBarHeight = 42;
static NSHashTable<NSView *> *gPanes;
static NSMapTable<NSView *, NSNumber *> *gRevealed;
static void (*origLayout)(id, SEL);

BOOL TweakNavBarShouldHideInWindow(NSWindow *window) {
    switch (TweakSettings.urlBarMode) {
        case TweakURLBarModeTop: return NO;
        case TweakURLBarModeHidden: return YES;
        case TweakURLBarModeSidebar: return TweakSidebarHasURLBar(window);
    }
    return NO;
}

static BOOL isRevealed(NSView *pane) { return [[gRevealed objectForKey:pane] boolValue]; }

static void applyPane(NSView *pane) {
    NSView *bar = TweakChildOfClass(pane, kDiaNavigationBarClass);
    NSView *content = TweakChildOfClass(pane, kDiaGesturalContentClass);
    if (!bar || !content) return;
    NSRect b = pane.bounds;
    if (NSHeight(bar.frame) >= 1) gBarHeight = NSHeight(bar.frame);
    if (!TweakNavBarShouldHideInWindow(pane.window)) {
        bar.hidden = NO;
        return;
    }
    // Content fills the pane; the bar floats above it when revealed.
    NSRect cf = content.frame;
    if (NSMinY(cf) != 0 || NSHeight(cf) != NSHeight(b)) {
        cf.origin.y = 0;
        cf.size.height = NSHeight(b);
        content.frame = cf;
    }
    NSView *info = TweakChildOfClass(pane, kDiaInfoBarClass);
    if (info && NSMinY(info.frame) == gBarHeight) {
        NSRect f = info.frame;
        f.origin.y = 0;
        info.frame = f;
    }
    BOOL show = isRevealed(pane);
    if (bar.hidden == show) bar.hidden = !show;
    // Dia collapses the bar's frame while hidden; restore it for the overlay.
    if (show && (NSHeight(bar.frame) < 1 || NSWidth(bar.frame) != NSWidth(b)))
        bar.frame = NSMakeRect(0, pane.isFlipped ? 0 : NSHeight(b) - gBarHeight, NSWidth(b), gBarHeight);
}

static void hookedLayout(NSView *self, SEL _cmd) {
    origLayout(self, _cmd);
    [gPanes addObject:self];
    applyPane(self);
}

static void (*origContentSetFrame)(id, SEL, NSRect);
static void hookedContentSetFrame(NSView *self, SEL _cmd, NSRect f) {
    NSView *pane = self.superview;
    if ([gPanes containsObject:pane] && TweakNavBarShouldHideInWindow(pane.window)) {
        f.origin.y = 0;
        f.size.height = NSHeight(pane.bounds);
    }
    origContentSetFrame(self, _cmd, f);
}

static void (*origBarSetHidden)(id, SEL, BOOL);
static void hookedBarSetHidden(NSView *self, SEL _cmd, BOOL hidden) {
    NSView *pane = self.superview;
    if (!hidden && [gPanes containsObject:pane] && TweakNavBarShouldHideInWindow(pane.window) && !isRevealed(pane)) hidden = YES;
    origBarSetHidden(self, _cmd, hidden);
}

static BOOL barHasFocus(NSView *bar) {
    id fr = bar.window.firstResponder;
    if (![fr isKindOfClass:NSView.class]) return NO;
    NSView *v = fr;
    if ([fr isKindOfClass:NSText.class] && [(NSText *)fr isFieldEditor]) {
        id d = [(NSTextView *)fr delegate];
        if ([d isKindOfClass:NSView.class]) v = d;
    }
    return [v isDescendantOf:bar];
}

static void updateReveal(void) {
    for (NSView *pane in gPanes.allObjects) {
        if (!pane.window) continue;
        NSView *bar = TweakChildOfClass(pane, kDiaNavigationBarClass);
        if (!bar) continue;
        BOOL want = NO;
        if (TweakNavBarShouldHideInWindow(pane.window) && pane.window.isKeyWindow) {
            if (TweakSettings.revealOnHover) {
                NSPoint p = [pane convertPoint:pane.window.mouseLocationOutsideOfEventStream fromView:nil];
                BOOL inX = p.x >= 0 && p.x <= NSWidth(pane.bounds);
                CGFloat top = pane.isFlipped ? p.y : NSHeight(pane.bounds) - p.y;
                if (inX && top >= -2 && top <= kRevealEdge) want = YES;
                else if (inX && isRevealed(pane) && top >= -2 && top <= gBarHeight + kKeepMargin) want = YES;
            }
            if (barHasFocus(bar)) want = YES;
        }
        if (want != isRevealed(pane)) {
            [gRevealed setObject:@(want) forKey:pane];
            applyPane(pane);
        }
    }
}

static void relayoutAll(void) {
    for (NSView *pane in gPanes.allObjects) {
        [gRevealed setObject:@NO forKey:pane];
        if (!TweakNavBarShouldHideInWindow(pane.window)) {
            // Let Dia's own layout restore the original frames.
            TweakChildOfClass(pane, kDiaNavigationBarClass).hidden = NO;
            [pane.superview setNeedsLayout:YES];
        }
        pane.needsLayout = YES;
    }
}

NSView *TweakNavBarFocusedPane(NSWindow *window) {
    NSView *fallback = nil;
    id fr = window.firstResponder;
    for (NSView *pane in gPanes.allObjects) {
        if (pane.window != window || pane.isHiddenOrHasHiddenAncestor) continue;
        if ([fr isKindOfClass:NSView.class] && [(NSView *)fr isDescendantOf:pane]) return pane;
        if (!fallback) fallback = pane;
    }
    return fallback;
}

void TweakNavBarSetRevealed(NSView *pane, BOOL revealed) {
    [gRevealed setObject:@(revealed) forKey:pane];
    applyPane(pane);
}

// Dia's own (hidden) back, forward and reload buttons of the window's focused pane.
static NSArray<NSControl *> *diaNavControls(NSWindow *window) {
    NSView *bar = TweakChildOfClass(TweakNavBarFocusedPane(window), kDiaNavigationBarClass);
    NSMutableArray<NSControl *> *controls = [NSMutableArray array];
    for (NSView *row in bar.subviews)
        for (NSView *v in row.subviews)
            if ([NSStringFromClass(v.class) containsString:kDiaInteractiveIconControlName] && [v isKindOfClass:NSControl.class])
                [controls addObject:(NSControl *)v];
    return controls;
}

TweakNavState TweakNavBarState(NSWindow *window) {
    TweakNavState s = {YES, YES, NO, NO};
    NSArray<NSControl *> *c = diaNavControls(window);
    if (c.count < 3) return s;
    // Reload is never disabled: all three off means Dia parked the bar, not real state.
    if (c[0].isEnabled || c[1].isEnabled || c[2].isEnabled) {
        s.canGoBack = c[0].isEnabled;
        s.canGoForward = c[1].isEnabled;
        s.known = YES;
    }
    if (!c[2].action) return s;   // only Dia's own control can stop a load
    @try {
        s.loading = [[TweakActiveTabForWindow(window) valueForKey:kDiaTabLoadingKey] boolValue];
    } @catch (__unused NSException *e) {
        static BOOL logged;
        if (!logged) { logged = YES; NSLog(@"[arcpatches] tab has no %@; reload never shows stop", kDiaTabLoadingKey); }
    }
    return s;
}

void TweakNavBarPerform(NSWindow *window, NSInteger index) {
    // Prefer Dia's own (hidden) buttons so behaviour matches the stock bar; while
    // loading, Dia's reload control is its stop control.
    NSArray<NSControl *> *controls = diaNavControls(window);
    if (index < (NSInteger)controls.count && controls[index].action) {
        [controls[index] sendAction:controls[index].action to:controls[index].target];
        return;
    }
    if (index < 2) {
        // Walk this window's responder chain (NSApp's would use whatever window is key).
        SEL sel = NSSelectorFromString(index == 0 ? @"navigateTabBack:" : @"navigateTabForward:");
        NSView *web = TweakDescendantOfClass(TweakNavBarFocusedPane(window), kDiaWebContentsHostClass);
        for (NSResponder *r = web ?: window.firstResponder; r; r = r.nextResponder)
            if ([r respondsToSelector:sel]) { [NSApp sendAction:sel to:r from:nil]; return; }
        for (id t in @[window, (id)window.delegate ?: NSNull.null, window.windowController ?: NSNull.null, (id)NSApp.delegate ?: NSNull.null])
            if ([t respondsToSelector:sel]) { [NSApp sendAction:sel to:t from:nil]; return; }
        NSLog(@"[arcpatches] no target for %@", NSStringFromSelector(sel));
    } else {
        NSString *url = TweakURLForWindow(window);
        if (url) TweakNavigateWindow(window, url);
    }
}

void TweakNavBarInstall(void) {
    Class cls = NSClassFromString(kDiaContentPaneClass);
    if (!cls) { NSLog(@"[arcpatches] %@ not found; URL bar hiding inactive", kDiaContentPaneClass); return; }
    gPanes = [NSHashTable weakObjectsHashTable];
    gRevealed = [NSMapTable weakToStrongObjectsMapTable];
    origLayout = (void *)TweakHook(cls, @selector(layout), (IMP)hookedLayout);
    TweakNavBarEditorInstall();
    // Dia moves the bar and content outside layout passes (e.g. animating back after
    // Esc in its URL editor); correct those moves as they happen.
    Class content = NSClassFromString(kDiaGesturalContentClass);
    if (content) origContentSetFrame = (void *)TweakHook(content, @selector(setFrame:), (IMP)hookedContentSetFrame);
    Class barCls = NSClassFromString(kDiaNavigationBarClass);
    if (barCls) origBarSetHidden = (void *)TweakHook(barCls, @selector(setHidden:), (IMP)hookedBarSetHidden);

    // Hover reveal follows the mouse; a slow timer catches the pointer leaving the
    // window and focus changes.
    [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved | NSEventMaskMouseExited handler:^NSEvent *(NSEvent *e) {
        if (TweakSettings.urlBarMode != TweakURLBarModeTop) updateReveal();
        return e;
    }];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(__unused NSTimer *t) {
        if (TweakSettings.urlBarMode != TweakURLBarModeTop) updateReveal();
        TweakNavBarEditorTick();
    }];
    timer.tolerance = 0.25;
    [NSNotificationCenter.defaultCenter addObserverForName:TweakSettingsDidChangeNotification object:nil queue:nil
                                                usingBlock:^(__unused NSNotification *n) { relayoutAll(); }];
}
