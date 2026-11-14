// The URL pill's hover buttons: copy link, and site controls. Site controls press
// Dia's own site control center button in the (hidden) top bar of the focused pane,
// and fall back to Chromium's per-site settings page in a new tab.
#import "SidebarViews.h"
#import "NavBarInternal.h"
#import "Browser.h"

#pragma mark - Icon button

// The top row's button (ChromeButton.m) at pill size: same fills, timing and tint.
@implementation TweakPillIconButton

+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action {
    return [self buttonWithSymbol:symbol label:label pointSize:ArcPillIcon radius:ArcRadiusSmall target:target action:action];
}

// While selected (its popover open) the pill keeps it shown, then fades it with the hover.
- (void)setSelected:(BOOL)selected {
    BOOL changed = selected != self.selected;
    [super setSelected:selected];
    NSView *v = self.superview;
    while (v && ![v isKindOfClass:TweakSidebarURLBar.class]) v = v.superview;
    if (changed) [(TweakSidebarURLBar *)v updateAppearance:YES];
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
