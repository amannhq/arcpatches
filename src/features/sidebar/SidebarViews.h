// Private to the sidebar URL bar: its views (SidebarViews.m), its hover buttons
// (SidebarPillActions.m), its mouse and copy handling (SidebarPillInput.m) and the
// container layout that places them (Sidebar.m).
#import "Common.h"
#import "ChromeButton.h"

@class TweakPillIconButton;

@interface TweakSidebarURLBar : NSView
@property (nonatomic, strong) NSView *pill;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, strong) NSImageView *searchIcon;   // empty state: no page open
@property (nonatomic, strong) TweakPillIconButton *linkButton;    // copy link (hover)
@property (nonatomic, strong) TweakPillIconButton *siteButton;   // site controls (hover); `selected` while its popover is open
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic) BOOL hovering;
@property (nonatomic) NSUInteger feedbackGeneration;
@property (nonatomic) BOOL showingFeedback;   // label reads "Copied"
- (void)updateAppearance:(BOOL)animated;   // fill and hover buttons, after hover or `selected` changes
- (void)refresh;
- (void)forceRefresh;
- (BOOL)openEditor;
@end

// SidebarPillInput.m: clicks, drags, the context menu and "Copied".
@interface TweakSidebarURLBar (Input) <NSDraggingSource>
- (void)showCopiedFeedback;   // "Copied" in the label (and a checkmark), then the host again
- (void)copyLink:(id)sender;   // the clean URL, then "Copied"
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
void TweakSidebarPillRegister(TweakSidebarURLBar *bar);   // for TweakSidebarShowCopiedFeedback (SidebarPillInput.m)
void TweakSidebarOpenSiteControls(NSView *anchor);   // the site controls popover under anchor (SiteControlsPopover.m)
