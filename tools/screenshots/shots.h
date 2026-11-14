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

// shots-sidebar.m's parts, for the settings stills and animations (shots-settings.m, shots-anim.m).
@class TweakNavButtons, TweakSidebarURLBar;
typedef struct { BOOL lights, toggle, nav, profile; } ShotTopRowOptions;
extern const ShotTopRowOptions ShotTopRowDefault;
static const CGFloat ShotSidebarWidth = 240, ShotRowHeight = 40;   // a typical sidebar; the top row and the pill row
void ShotAddWindowButtons(NSView *parent, CGFloat x, CGFloat midY, CGFloat spacing, BOOL minimize);
TweakNavButtons *ShotAddTopRow(NSView *parent, CGFloat y, ShotTopRowOptions o);
typedef NS_ENUM(NSInteger, ShotPillState) { ShotPillRest, ShotPillHover, ShotPillEmpty };
// `label` defaults to the host; `buttons` NO is the hover buttons turned off in Settings.
TweakSidebarURLBar *ShotPill(ShotPillState state, CGFloat y, NSString *label, BOOL buttons);
void ShotAddFavourites(NSView *parent, CGFloat y);   // two rows of 44, ArcSpace2 apart

// shots-sidebar.m: toprow, pill-rest, pill-hover, pill-empty, sidebar, site-controls.
void ShotSidebar(NSString *dir);
void ShotSiteControls(NSString *dir);

// shots.m: the ⌘T palette (row `highlighted` lit) and the ⌘L editor, as panels.
NSView *ShotPalette(NSInteger highlighted, NSInteger rows);   // the first `rows` of the demo results
NSView *ShotEditor(void);
// shots-settings.m: one before/after still per visible setting, in `dir`.
void ShotSettings(NSString *dir);
// shots-anim.m: 30-fps frame sequences of the microinteractions, in `dir`/<name>/.
void ShotAnimations(NSString *dir);
// shots-settings.m: a window crop (sidebar on glass, a generic page), and the full-screen top
// row with its title strip at `stripOffset` (-ArcFullScreenStripHeight hidden … 0 shown).
NSView *ShotWindowCrop(CGFloat width, CGFloat height, NSView **sidebarOut, NSView **pageOut);
NSView *ShotFullScreenRow(BOOL hideButtons, CGFloat stripOffset);
