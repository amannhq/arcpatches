// Private to the sidebar URL bar: its views (SidebarViews.m), its hover buttons
// (SidebarPillActions.m) and the container layout that places them (Sidebar.m).
#import "Common.h"
#import "ChromeButton.h"

#define TWEAK_PILL_HEIGHT 36   // Arc's sidebar URL bar

// A fill that is white over dark sidebars and black over light ones.
NSColor *TweakPillFill(CGFloat darkAlpha, CGFloat lightAlpha);

@class TweakPillIconButton;

@interface TweakSidebarURLBar : NSView
@property (nonatomic, strong) NSView *pill;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, strong) TweakPillIconButton *linkButton;    // copy link (hover)
@property (nonatomic, strong) TweakPillIconButton *siteButton;   // site controls (hover); `selected` while its popover is open
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic) BOOL hovering;
@property (nonatomic) NSUInteger feedbackGeneration;
@property (nonatomic) BOOL showingFeedback;   // label reads "Copied"
- (void)refresh;
- (void)forceRefresh;
- (BOOL)openEditor;
@end

// Back, forward and reload (stop while loading), next to the traffic lights. Back and
// forward dim when Dia has no history that way.
@interface TweakNavButtons : NSView
+ (void)scheduleRefresh;   // re-reads every instance's enabled and loading state, coalesced
@end

// SidebarPillActions.m: the square icon buttons shown inside the pill on hover. The
// same hover, pressed and selected look as the top row, at pill size.
@interface TweakPillIconButton : TweakChromeButton
+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action;
@end

BOOL TweakSidebarURLIsSite(NSString *url);         // http(s) with a host: has site controls
BOOL TweakSidebarCopyURL(NSWindow *window);        // the active tab's URL to the pasteboard
void TweakSidebarOpenSiteControls(NSWindow *window);   // Dia's site control center, else Chromium's site settings
