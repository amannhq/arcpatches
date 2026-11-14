// Shared by the README screenshot renderer (shots.m, shots-sidebar.m, shots-data.m).
#import <AppKit/AppKit.h>

// A rounded square with a white letter: stands in for favicons and extension icons.
NSImage *ShotLetterIcon(NSString *letter, NSInteger color, CGFloat size);
// Writes `v` (and its subviews) as a 2x PNG.
void ShotWritePNG(NSView *v, NSString *path);
// A rounded dark card, like the sidebar or a popover, to hold a render.
NSView *ShotCard(NSSize size, NSColor *fill, CGFloat radius, BOOL border);

NSColor *ShotSidebarColor(void);
// shots-sidebar.m: toprow, pill-rest, pill-hover, pill-empty, sidebar, site-controls.
void ShotSidebar(NSString *dir);
void ShotSiteControls(NSString *dir);
