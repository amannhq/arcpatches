// The URL pill's hover buttons: copy link, and site controls. Site controls press
// Dia's own site control center button in the (hidden) top bar of the focused pane,
// and fall back to Chromium's per-site settings page in a new tab.
#import "SidebarViews.h"
#import "NavBarInternal.h"
#import "Browser.h"

#pragma mark - Icon button

@interface TweakPillIconButton ()
@property (nonatomic) BOOL hovering;
@end

@implementation TweakPillIconButton

+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action {
    TweakPillIconButton *b = [[self alloc] initWithFrame:NSZeroRect];
    b.bordered = NO;
    b.title = @"";
    b.imagePosition = NSImageOnly;
    b.target = target;
    b.action = action;
    b.toolTip = label;
    b.accessibilityLabel = label;
    b.refusesFirstResponder = YES;   // never take focus from the page
    b.focusRingType = NSFocusRingTypeNone;
    b.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightMedium];
    b.contentTintColor = NSColor.secondaryLabelColor;
    b.wantsLayer = YES;
    b.layer.cornerRadius = 7;
    b.layer.cornerCurve = kCACornerCurveContinuous;
    [b setSymbol:symbol];
    return b;
}

- (void)setSymbol:(NSString *)symbol {
    self.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:self.accessibilityLabel];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseEntered:(NSEvent *)e { self.hovering = YES; [self updateFill]; }
- (void)mouseExited:(NSEvent *)e { self.hovering = NO; [self updateFill]; }
- (void)viewDidHide { [super viewDidHide]; self.hovering = NO; [self updateFill]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateFill]; }

- (void)updateFill {
    NSColor *bg = self.hovering ? TweakPillFill(0.10, 0.06) : NSColor.clearColor;
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.layer.backgroundColor = bg.CGColor;
    }];
}

@end

#pragma mark - Copy link

BOOL TweakSidebarURLIsSite(NSString *url) {
    if (!url.length) return NO;
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSString *scheme = c.scheme.lowercaseString;
    return ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) && c.host.length;
}

BOOL TweakSidebarCopyURL(NSWindow *window) {
    NSString *u = TweakURLForWindow(window);
    if (!u.length || [u isEqualToString:@"about:blank"]) return NO;
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb clearContents];
    BOOL ok = [pb setString:u forType:NSPasteboardTypeString];
    if ([NSURL URLWithString:u]) [pb setString:u forType:NSPasteboardTypeURL];
    return ok;
}

#pragma mark - Site controls

// Dia's button may be an AppKit view or a SwiftUI element (an accessibility child
// with no view of its own); look for both under the navigation bar.
static id findElement(id element, NSString *ident, int depth) {
    if (!element || depth > 14) return nil;
    @try {
        if ([element respondsToSelector:@selector(accessibilityIdentifier)] && [[element accessibilityIdentifier] isEqualToString:ident]) return element;
        if ([element isKindOfClass:NSView.class]) {
            if ([[(NSView *)element identifier] isEqualToString:ident]) return element;
            for (NSView *s in [(NSView *)element subviews]) {
                id hit = findElement(s, ident, depth + 1);
                if (hit) return hit;
            }
        }
        NSArray *children = [element respondsToSelector:@selector(accessibilityChildren)] ? [element accessibilityChildren] : nil;
        for (id child in children) {
            if ([child isKindOfClass:NSView.class]) continue;   // already walked as a subview
            id hit = findElement(child, ident, depth + 1);
            if (hit) return hit;
        }
    } @catch (__unused NSException *e) {}
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

static BOOL pressDiaSiteControls(NSWindow *window) {
    NSView *pane = TweakNavBarFocusedPane(window);
    NSView *bar = TweakChildOfClass(pane, kDiaNavigationBarClass);
    if (!bar) return NO;
    // Like the URL editor: the button must be on screen to anchor what it opens.
    TweakNavBarSetRevealed(pane, YES);
    [pane layoutSubtreeIfNeeded];
    id el = findElement(bar, kDiaSiteControlsIdentifier, 0);
    BOOL pressed = NO;
    if ([el isKindOfClass:NSControl.class] && [(NSControl *)el action] && ![(NSView *)el isHiddenOrHasHiddenAncestor]) {
        NSControl *c = el;
        pressed = [c sendAction:c.action to:c.target];
    } else if ([el isKindOfClass:NSView.class] && ![(NSView *)el isHiddenOrHasHiddenAncestor]) {
        clickView(el);
        pressed = YES;
    } else if ([el respondsToSelector:@selector(accessibilityPerformPress)]) {
        pressed = [el accessibilityPerformPress];
    }
    TweakNavBarSetRevealed(pane, NO);
    return pressed;
}

// "https://example.com:8080", percent-encoded whole, as Chromium's settings page expects.
static NSString *encodedOrigin(NSString *url) {
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSString *host = [c.host containsString:@":"] ? [NSString stringWithFormat:@"[%@]", c.host] : c.host;
    NSString *origin = [NSString stringWithFormat:@"%@://%@", c.scheme.lowercaseString, host];
    if (c.port) origin = [origin stringByAppendingFormat:@":%@", c.port];
    NSCharacterSet *unreserved = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    return [origin stringByAddingPercentEncodingWithAllowedCharacters:unreserved];
}

void TweakSidebarOpenSiteControls(NSWindow *window) {
    NSString *u = TweakURLForWindow(window);
    if (!TweakSidebarURLIsSite(u)) { NSBeep(); return; }
    if (pressDiaSiteControls(window)) return;
    TweakOpenInNewTab(window, [kDiaSiteDetailsURLPrefix stringByAppendingString:encodedOrigin(u)]);
}
