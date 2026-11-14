// Private to the sidebar URL bar: its views (SidebarViews.m), its hover buttons
// (SidebarPillActions.m) and the container layout that places them (Sidebar.m).
#import "Common.h"

#define TWEAK_PILL_HEIGHT 36   // Arc's sidebar URL bar

// A fill that is white over dark sidebars and black over light ones.
NSColor *TweakPillFill(CGFloat darkAlpha, CGFloat lightAlpha);

@interface TweakSidebarURLBar : NSView
@property (nonatomic, strong) NSView *pill;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, strong) NSButton *linkButton;    // copy link (hover)
@property (nonatomic, strong) NSButton *siteButton;   // site controls (hover)
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic) BOOL hovering;
@property (nonatomic) NSUInteger feedbackGeneration;
@property (nonatomic) BOOL showingFeedback;   // label reads "Copied"
- (void)refresh;
- (void)forceRefresh;
- (BOOL)openEditor;
@end

// Back, forward and reload, next to the traffic lights.
@interface TweakNavButtons : NSView
@end

// SidebarPillActions.m: the square icon buttons shown inside the pill on hover.
@interface TweakPillIconButton : NSButton
+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action;
- (void)setSymbol:(NSString *)symbol;
@end

BOOL TweakSidebarURLIsSite(NSString *url);         // http(s) with a host: has site controls
BOOL TweakSidebarCopyURL(NSWindow *window);        // the active tab's URL to the pasteboard
void TweakSidebarOpenSiteControls(NSView *anchor);   // the site controls popover under anchor (SiteControlsPopover.m)
