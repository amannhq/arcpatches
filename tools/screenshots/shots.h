// Shared by the README screenshot renderer (shots.m, shots-sidebar.m, shots-data.m).
#import <AppKit/AppKit.h>

// A rounded square with a white letter: stands in for favicons and extension icons.
NSImage *ShotLetterIcon(NSString *letter, NSInteger color, CGFloat size);
// The favicon fetch-icons.sh saved in build/shot-icons (relative to the working directory,
// the repo root), or a letter tile when it's missing.
NSImage *ShotSiteIcon(NSString *domain, CGFloat size);
// The host of `url`, without "www.".
NSString *ShotHost(NSString *url);
// The translucent dark tint of a glass panel (frame.swift blurs the backdrop behind it).
NSColor *ShotGlassColor(void);
// Writes `v` (and its subviews) as a 2x PNG.
void ShotWritePNG(NSView *v, NSString *path);
// A rounded dark card, like the sidebar or a popover, to hold a render.
NSView *ShotCard(NSSize size, NSColor *fill, CGFloat radius, BOOL border);

NSColor *ShotSidebarColor(void);
// shots-sidebar.m: toprow, pill-rest, pill-hover, pill-empty, sidebar, site-controls.
void ShotSidebar(NSString *dir);
void ShotSiteControls(NSString *dir);
