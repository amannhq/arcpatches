// Window buttons in full screen, Arc style: hidden until the pointer is over the sidebar's
// top row, then they fade in. Minimize stays disabled in full screen, as macOS intends
// (Dia hosts the real buttons in its sidebar, where AppKit no longer disables it).
#import <AppKit/AppKit.h>

// Starts tracking the pointer over `header` (once per header); `changed` runs, outside
// any layout pass, whenever it enters or leaves.
void TweakTopRowTrackHeader(NSView *header, void (^changed)(NSView *header));
BOOL TweakTopRowHeaderHovered(NSView *header);

// Disables or re-enables the window's minimize button. Only re-enables what this disabled.
void TweakTopRowSetMinimizeAllowed(NSWindow *window, BOOL allowed);

// Fades `buttons` in from transparent (no-op under Reduce Motion or when already opaque).
void TweakTopRowFadeIn(NSView *buttons);
