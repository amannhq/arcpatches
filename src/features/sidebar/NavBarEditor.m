// Dia's URL editor, anchored elsewhere: clicking Dia's URL field opens its editor
// (BoostCommandBar) in a window-level DynamicPopover positioned over the top bar.
// When opened from the sidebar we move that popover so it grows out of the sidebar
// pill instead.
#import "NavBarInternal.h"
#import "Browser.h"
#import "ArcStyle.h"

static __weak NSWindow *gAnchorWindow;
static NSRect gAnchorRect;   // window coordinates
static BOOL gAnchorSeen;
static NSTimeInterval gAnchorTime;
static void (*origPopoverSetFrame)(id, SEL, NSRect);

static NSRect anchoredFrame(NSView *popover, NSRect proposed) {
    NSView *sv = popover.superview;
    NSRect a = [sv convertRect:gAnchorRect fromView:nil];
    CGFloat inset = ArcEditorPopoverInset;   // the popover's top-left sits on the anchor's (covering the pill)
    CGFloat x = NSMinX(a) - inset;
    // From the pill: about 1.55× the sidebar (the pill plus its inset each side), like Arc.
    // A wider anchor (the ⌘T palette) keeps its own width. Never past the window.
    CGFloat editor = MIN(ArcEditorMaxWidth, MAX(ArcEditorMinWidth, (NSWidth(a) + 2 * ArcSidebarInset) * ArcEditorWidthRatio));
    CGFloat w = MIN(MAX(NSWidth(a), editor), NSMaxX(sv.bounds) - x - ArcSpace2);
    CGFloat h = NSHeight(proposed);
    // Drop the space of a hidden bottom toolbar (AI controls hidden by the privacy
    // module), but only while Dia's proposed height still includes it.
    NSView *toolbar = TweakDescendantOfClass(popover, kDiaEditorToolbarClass);
    NSView *root = TweakDescendantOfClass(popover, kDiaEditorRootClass);
    if (toolbar.hidden && root) {
        CGFloat chrome = NSHeight(popover.frame) - NSHeight(root.frame);  // popover padding around the editor
        if (h - chrome >= NSMaxY(toolbar.frame) - 1) h -= NSHeight(toolbar.frame);
    }
    CGFloat y = sv.isFlipped ? NSMinY(a) - inset : NSMaxY(a) + inset - h;
    return NSMakeRect(x, y, w, h);
}

static void hookedPopoverSetFrame(NSView *self, SEL _cmd, NSRect frame) {
    if (gAnchorWindow && self.window == gAnchorWindow && self.superview) frame = anchoredFrame(self, frame);
    origPopoverSetFrame(self, _cmd, frame);
}

static Class popoverClass(void) {
    static Class cls;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cls = TweakFindClass(kDiaPopoverRootPrefix, kDiaPopoverRootSuffix); });
    return cls;
}

static NSView *openPopover(NSWindow *w) {
    Class cls = popoverClass();
    NSView *frame = w.contentView.superview;
    for (NSView *holder in frame.subviews)
        for (NSView *v in holder.subviews)
            if ([v isKindOfClass:cls]) return v;
    return nil;
}

static void clickView(NSView *v) {
    NSWindow *w = v.window;
    NSPoint p = [v convertPoint:NSMakePoint(NSMidX(v.bounds), NSMidY(v.bounds)) toView:nil];
    NSEventType types[] = {NSEventTypeLeftMouseDown, NSEventTypeLeftMouseUp};
    for (int i = 0; i < 2; i++)
        [w sendEvent:[NSEvent mouseEventWithType:types[i] location:p modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime
                                    windowNumber:w.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1]];
}

BOOL TweakNavBarOpenEditor(NSWindow *window, NSRect anchorInWindow) {
    NSView *pane = TweakNavBarFocusedPane(window);
    NSView *bar = TweakChildOfClass(pane, kDiaNavigationBarClass);
    if (!bar) return NO;
    // The field must be on screen to take the click: reveal the bar for a moment.
    TweakNavBarSetRevealed(pane, YES);
    [pane layoutSubtreeIfNeeded];
    NSView *field = TweakDescendantOfClass(bar, kDiaAssistantBarClass);
    if (!field || field.isHiddenOrHasHiddenAncestor) return NO;

    gAnchorWindow = popoverClass() ? window : nil;
    gAnchorRect = anchorInWindow;
    gAnchorSeen = NO;
    gAnchorTime = NSDate.timeIntervalSinceReferenceDate;
    clickView(field);
    TweakNavBarSetRevealed(pane, NO);
    NSView *pop = openPopover(window);
    if (pop && gAnchorWindow) pop.frame = pop.frame;  // re-run through the anchoring hook
    return YES;
}

void TweakNavBarEditorInstall(void) {
    if (popoverClass()) origPopoverSetFrame = (void *)TweakHook(popoverClass(), @selector(setFrame:), (IMP)hookedPopoverSetFrame);
    else NSLog(@"[arcpatches] DynamicPopover root not found; editor opens at the top");
}

void TweakNavBarEditorTick(void) {
    // The anchor lasts for one editing session (or 2 s if the editor never opened).
    NSWindow *w = gAnchorWindow;
    if (!w) return;
    if (openPopover(w)) gAnchorSeen = YES;
    else if (gAnchorSeen || NSDate.timeIntervalSinceReferenceDate - gAnchorTime > 2) {
        gAnchorWindow = nil;
        TweakPaletteEditorClosed(w);
    }
}
