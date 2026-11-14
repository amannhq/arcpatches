// Adds an Arc-style URL pill below the tab sidebar header, plus back/forward/
// reload buttons in the header row next to the traffic lights. Clicking the pill
// (or ⌘L) opens Dia's own URL editor (autocomplete, history, tabs, search)
// anchored over the pill instead of the top bar.
#import "SidebarViews.h"
#import "Features.h"
#import "Browser.h"
#import <objc/runtime.h>

static const CGFloat kRowHeight = TWEAK_PILL_HEIGHT + 10;   // pill + 2 top + 8 bottom
static const void *kBarKey = &kBarKey;
static const void *kNavKey = &kNavKey;
static const void *kGapKey = &kGapKey;
static void noteVisibility(NSView *c);

static void (*origLayout)(id, SEL);
static NSHashTable<NSView *> *gContainers;

#pragma mark - Title observation

@interface TweakTitleObserver : NSObject
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) NSHashTable<NSWindow *> *watched;
- (void)watch:(NSWindow *)w;
@end

@implementation TweakTitleObserver
- (instancetype)init {
    if ((self = [super init])) _watched = [NSHashTable weakObjectsHashTable];
    return self;
}
- (void)watch:(NSWindow *)w {
    if (!w || [self.watched containsObject:w] || ![NSStringFromClass(w.class) isEqualToString:kDiaPlatformWindowClass]) return;
    [self.watched addObject:w];
    [w addObserver:self forKeyPath:@"title" options:0 context:NULL];
    __weak typeof(self) weakSelf = self;
    __weak NSWindow *weakWindow = w;
    __block id token = [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:w queue:nil usingBlock:^(__unused NSNotification *n) {
        [weakWindow removeObserver:weakSelf forKeyPath:@"title"];
        [weakSelf.watched removeObject:weakWindow];
        [NSNotificationCenter.defaultCenter removeObserver:token];
        token = nil;  // breaks the token -> block -> token cycle
    }];
}
- (void)observeValueForKeyPath:(NSString *)k ofObject:(id)o change:(NSDictionary *)c context:(void *)ctx {
    // Title often changes just before the URL settles; refresh now and once more shortly after.
    if (self.onChange) self.onChange();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (self.onChange) self.onChange(); });
}
@end

static TweakTitleObserver *gTitleObserver;

#pragma mark - Container layout

static TweakSidebarURLBar *barFor(NSView *container) { return objc_getAssociatedObject(container, kBarKey); }

static NSView *bodyFor(NSView *container, NSView *header) {
    for (NSView *s in container.subviews)
        if (s != header && s != barFor(container) && [NSStringFromClass(s.class) isEqualToString:kDiaFlippedViewClass]) return s;
    return nil;
}

static void applyContainer(NSView *c) {
    NSView *header = TweakChildOfClass(c, kDiaSidebarHeaderClass);
    NSView *body = header ? bodyFor(c, header) : nil;
    if (!header || !body || !c.isFlipped) return;

    CGFloat headerBottom = NSMaxY(header.frame);
    CGFloat H = NSHeight(c.bounds);
    // Remember the gap Dia leaves below the body (captured while unshifted).
    if (NSMinY(body.frame) == headerBottom)
        objc_setAssociatedObject(c, kGapKey, @(H - NSMaxY(body.frame)), OBJC_ASSOCIATION_RETAIN);
    CGFloat gap = [objc_getAssociatedObject(c, kGapKey) doubleValue];

    // Attached even while the sidebar is collapsed, so the top bar stays hidden then.
    BOOL on = TweakSettings.urlBarMode == TweakURLBarModeSidebar;
    TweakSidebarURLBar *bar = barFor(c);
    if (on && !bar) {
        bar = [[TweakSidebarURLBar alloc] initWithFrame:NSZeroRect];
        objc_setAssociatedObject(c, kBarKey, bar, OBJC_ASSOCIATION_RETAIN);
    }
    if (on && bar.superview != c) [c addSubview:bar positioned:NSWindowAbove relativeTo:header];
    if (!on) [bar removeFromSuperview];

    CGFloat top = headerBottom + (on ? kRowHeight : 0);
    NSRect bf = NSMakeRect(NSMinX(body.frame), top, NSWidth(body.frame), MAX(0, H - top - gap));
    if (!NSEqualRects(bf, body.frame)) body.frame = bf;
    if (on) {
        bar.frame = NSMakeRect(0, headerBottom, NSWidth(c.bounds), kRowHeight);
        [bar refresh];
    }

    TweakNavButtons *nav = objc_getAssociatedObject(header, kNavKey);
    BOOL navOn = on && TweakSettings.sidebarShowsNavButtons;
    if (navOn && !nav) {
        nav = [[TweakNavButtons alloc] initWithFrame:NSZeroRect];
        objc_setAssociatedObject(header, kNavKey, nav, OBJC_ASSOCIATION_RETAIN);
    }
    if (navOn) {
        if (nav.superview != header) [header addSubview:nav];
        // Vertically centre on the traffic lights' stack.
        NSView *stack = header.subviews.firstObject;
        CGFloat mid = stack ? NSMidY(stack.frame) : NSHeight(header.bounds) / 2;
        CGFloat w = 3 * TweakChromeTopRowSize, h = TweakChromeTopRowSize;
        nav.frame = NSMakeRect(NSWidth(header.bounds) - w - 8, mid - h / 2, w, h);
    } else {
        [nav removeFromSuperview];
    }
}

// Adds or removes the bar; if that changed, the top bar re-evaluates its visibility
// (it depends on whether this window has a sidebar URL bar). Deferred: callers may be
// inside a layout pass.
static void reapplyContainer(NSView *c) {
    BOOL had = barFor(c).superview != nil;
    applyContainer(c);
    if (had != (barFor(c).superview != nil))
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:TweakSettingsDidChangeNotification object:nil];
        });
}

static void hookedLayout(NSView *self, SEL _cmd) {
    origLayout(self, _cmd);
    [gContainers addObject:self];
    reapplyContainer(self);
    noteVisibility(self);
}

static TweakSidebarURLBar *visibleBar(NSWindow *window) {
    for (NSView *c in gContainers.allObjects) {
        TweakSidebarURLBar *bar = barFor(c);
        if (c.window == window && bar.superview && !c.isHiddenOrHasHiddenAncestor && NSWidth(c.frame) > 40) return bar;
    }
    return nil;
}

// Whether the top bar should give way: true while the window's sidebar has the bar,
// also when the sidebar is collapsed (Arc-like: no top bar either way), unless the
// user wants Dia's bar back while the sidebar is hidden.
BOOL TweakSidebarHasURLBar(NSWindow *window) {
    if (TweakSettings.topBarWhenSidebarHidden) return visibleBar(window) != nil;
    for (NSView *c in gContainers.allObjects)
        if (c.window == window && barFor(c).superview) return YES;
    return NO;
}

// With the top bar shown while the sidebar is hidden, it follows the sidebar sliding
// in and out: re-evaluate whenever a container's visibility flips.
static const void *kShownKey = &kShownKey;
static void noteVisibility(NSView *c) {
    if (!TweakSettings.topBarWhenSidebarHidden) return;
    BOOL shown = !c.isHiddenOrHasHiddenAncestor && NSWidth(c.frame) > 40;
    NSNumber *was = objc_getAssociatedObject(c, kShownKey);
    objc_setAssociatedObject(c, kShownKey, @(shown), OBJC_ASSOCIATION_RETAIN);
    if (was && was.boolValue != shown)
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSNotificationCenter.defaultCenter postNotificationName:TweakSettingsDidChangeNotification object:nil];
        });
}

BOOL TweakSidebarFocusURLBar(NSWindow *window) { return [visibleBar(window) openEditor]; }

void TweakSidebarInstall(void) {
    Class cls = TweakFindClass(kDiaSidebarRootPrefix, kDiaSidebarRootSuffix);
    if (!cls) { NSLog(@"[arcpatches] SidebarContainerRootView not found; sidebar URL bar inactive"); return; }
    gContainers = [NSHashTable weakObjectsHashTable];
    origLayout = (void *)TweakHook(cls, @selector(layout), (IMP)hookedLayout);
    // Refresh on navigation-ish events: Dia's window title follows the active tab's
    // page title, and switching windows/tabs changes it too. A slow timer covers
    // pages that change URL without changing title. Also attaches a bar the container's
    // layout couldn't (its header or body not there yet): nothing may lay it out again.
    // Add-only, so a transient hide never flips back to the top bar.
    void (^refreshAll)(void) = ^{
        for (NSView *c in gContainers.allObjects) {
            if (!barFor(c).superview) reapplyContainer(c);
            noteVisibility(c);
            [barFor(c) refresh];
        }
    };
    gTitleObserver = [TweakTitleObserver new];
    gTitleObserver.onChange = refreshAll;
    for (NSNotificationName n in @[NSWindowDidBecomeKeyNotification, NSWindowDidBecomeMainNotification, NSWindowDidUpdateNotification])
        [NSNotificationCenter.defaultCenter addObserverForName:n object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSWindow *w = note.object;
            if (n == NSWindowDidUpdateNotification) { [gTitleObserver watch:w]; return; }
            refreshAll();
        }];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(__unused NSTimer *t) { refreshAll(); }];
    timer.tolerance = 1;
    [NSNotificationCenter.defaultCenter addObserverForName:TweakSettingsDidChangeNotification object:nil queue:nil
                                                usingBlock:^(__unused NSNotification *n) {
        for (NSView *c in gContainers.allObjects) {
            applyContainer(c);
            [barFor(c) forceRefresh];
        }
    }];
}

static void installSidebar(void) {
    TweakNavBarInstall();
    TweakSidebarInstall();
}

const TweakFeature TweakFeatureSidebar = {"sidebar", {TWEAK_BROWSER_DIA}, NULL, installSidebar};
