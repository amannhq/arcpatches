// Window buttons in full screen, the way Arc does it: the sidebar's top row never shows
// them. When the pointer reaches the top edge of the screen, a title strip slides down
// across the top of the window with close, minimize (disabled, as macOS intends in full
// screen) and full screen, then slides away once the pointer leaves it.
#import <AppKit/AppKit.h>

// Starts or stops watching `window` for the pointer at the top edge.
void TweakFullScreenStripSetActive(NSWindow *window, BOOL active);

// Disables or re-enables the window's own minimize button. Only re-enables what this disabled.
void TweakTopRowSetMinimizeAllowed(NSWindow *window, BOOL allowed);
