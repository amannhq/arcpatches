// Private to the site controls popover: SiteControlsPopover.m builds and presents it,
// SiteControlsActions.m holds what its tiles, rows and menu do.
#import "SiteControlsPopover.h"
#import "SiteControlsData.h"
#import "SidebarViews.h"

// Private methods of the pill (SidebarViews.m, SidebarPillActions.m), sent only after respondsToSelector:.
@interface NSView (TweakSiteControlsPill)
- (void)copyLink:(id)sender;
- (void)updateButtons;
- (void)updateFill;
@end

@interface TweakSiteControls : NSViewController <NSPopoverDelegate, NSSharingServicePickerDelegate>
@property (nonatomic, weak) NSView *anchor;
@property (nonatomic, weak) NSWindow *browserWindow;
@property (nonatomic, copy) NSString *url;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) NSArray<TweakSiteExtension *> *extensions;
@property (nonatomic, strong) NSMenuItem *screenshotItem;
@property (nonatomic, strong) id escapeMonitor;
- (void)closeThen:(void (^)(NSWindow *window, NSString *url))action;
- (NSString *)siteSettingsURL;
- (void)finish;   // after the popover closed: monitors, pressed state, the pill's buttons
@end
