// Arc's site controls popover, shown under the URL pill's site-controls button:
// quick actions, the profile's extensions, per-site settings and the connection state.
#import <AppKit/AppKit.h>

// Opens the popover under anchor (the pill's button), or closes it if it is showing there.
void TweakSiteControlsToggle(NSView *anchor);
BOOL TweakSiteControlsIsShownFor(NSView *anchor);   // the button draws itself pressed meanwhile

#pragma mark - SidebarPillActions.m

// Dia's own site control center (its hidden top bar's button), else Chromium's site settings.
void TweakSidebarOpenDiaSiteControls(NSWindow *window);
// "https%3A%2F%2Fexample.com": the origin, percent-encoded as chrome://settings expects.
NSString *TweakSidebarEncodedOrigin(NSString *url);
// Reveals the focused pane's top bar and presses the first element under a view of class
// rootClass (nil: the whole bar) that match accepts. NO if none was found or pressed.
BOOL TweakSidebarPressNavBarElement(NSWindow *window, NSString *rootClass, BOOL (^match)(id element));
