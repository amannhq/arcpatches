// Arc-style new tab: ⌘T (or the sidebar's "New Tab") opens Dia's own URL editor
// centred over the current page instead of creating a tab. A tab is only created
// when you commit; Esc or clicking away creates nothing.
//
// Dia's editor always navigates the current tab, so while the palette is open we
// intercept that load and open the URL in a new tab instead.
#import "CommandBarInternal.h"   // TweakCommandBarContentRect, ArcStyle
#import "Features.h"
#import "Browser.h"
#import <objc/runtime.h>

NSString *const TweakKeyNewTabPalette = @"arcpatches.newTabPalette";

static __weak NSWindow *gPaletteWindow;
static NSTimeInterval gPaletteOpenedAt;
static NSString *gActiveURLAtOpen;

static BOOL paletteEnabled(void) { return TweakCommandBarCurrentStyle() == TweakCommandBarStyleDiaEditor; }

#pragma mark - Redirecting the commit

static id (*origLoad)(id, SEL, NSURL *, id, long, BOOL, BOOL);
static id hookedLoad(id self, SEL _cmd, NSURL *url, id origin, long transition, BOOL fromAddressBar, BOOL typedHttp) {
    NSWindow *w = gPaletteWindow;
    if (w && fromAddressBar && url.absoluteString.length) {
        gPaletteWindow = nil;
        NSString *target = url.absoluteString;
        dispatch_async(dispatch_get_main_queue(), ^{ TweakOpenInNewTab(w, target); });
        return nil;  // the current tab stays where it was
    }
    return origLoad(self, _cmd, url, origin, transition, fromAddressBar, typedHttp);
}

#pragma mark - Opening

BOOL TweakPaletteOpen(NSWindow *window) {
    if (!paletteEnabled() || !window || !origLoad) return NO;
    // Centred over the web content (not the sidebar), its top 30% of the way down: where Arc puts its palette.
    NSRect b = [window convertRectFromScreen:TweakCommandBarContentRect(window)];
    CGFloat width = MIN(ArcPaletteWidth, NSWidth(b) - 2 * ArcPaletteMargin);
    CGFloat top = NSMaxY(b) - NSHeight(b) * ArcPaletteTopFraction;
    NSRect anchor = NSMakeRect(round(NSMidX(b) - width / 2), top - ArcPillHeight, width, ArcPillHeight);
    if (!TweakNavBarOpenEditor(window, anchor)) return NO;

    gPaletteWindow = window;
    gPaletteOpenedAt = NSDate.timeIntervalSinceReferenceDate;
    gActiveURLAtOpen = TweakURLForWindow(window);
    // Start empty, like a new tab (Dia pre-fills the current URL).
    dispatch_async(dispatch_get_main_queue(), ^{
        id fr = window.firstResponder;
        if ([fr isKindOfClass:NSTextView.class]) {
            [fr selectAll:nil];
            [fr deleteBackward:nil];
        }
    });
    return YES;
}

// Called when the editor closes without committing.
void TweakPaletteEditorClosed(NSWindow *window) {
    if (gPaletteWindow == window) gPaletteWindow = nil;
}

#pragma mark - Sidebar "New Tab" row

static void (*origNewTabMouseDown)(id, SEL, NSEvent *);
static void hookedNewTabMouseDown(NSView *self, SEL _cmd, NSEvent *e) {
    if (TweakCommandBarCurrentStyle() == TweakCommandBarStyleNative ? TweakCommandBarShow(self.window, YES) : TweakPaletteOpen(self.window)) return;
    origNewTabMouseDown(self, _cmd, e);
}

void TweakPaletteInstall(void) {
    Class nav = NSClassFromString(kDiaNavigationControllerClass);
    SEL loadSel = @selector(load:initiatorOrigin:transition:fromAddressBar:typedWithHttpScheme:);
    // Without DynamicPopover the editor's close can't be seen, and the next address-bar load would be taken for the palette.
    if (!TweakFindClass(kDiaPopoverRootPrefix, kDiaPopoverRootSuffix)) NSLog(@"[arcpatches] DynamicPopover root not found; new-tab palette inactive");
    else if (nav && class_getInstanceMethod(nav, loadSel)) origLoad = (void *)TweakHook(nav, loadSel, (IMP)hookedLoad);
    else NSLog(@"[arcpatches] navigation load not found; new-tab palette inactive");

    Class row = NSClassFromString(kDiaNewTabCellClass);
    if (row) origNewTabMouseDown = (void *)TweakHook(row, @selector(mouseDown:), (IMP)hookedNewTabMouseDown);
}

BOOL TweakPaletteAvailable(void) { return origLoad != NULL; }
