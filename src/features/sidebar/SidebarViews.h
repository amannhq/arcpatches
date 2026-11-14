// Private to the sidebar URL bar: its views (SidebarViews.m) and the container
// layout that places them (Sidebar.m).
#import "Common.h"

@interface TweakSidebarURLBar : NSView
@property (nonatomic, strong) NSView *pill;
@property (nonatomic, strong) NSImageView *icon;
@property (nonatomic, strong) NSTextField *label;
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic) BOOL hovering;
- (void)refresh;
- (void)forceRefresh;
- (BOOL)openEditor;
@end

// Back, forward and reload, next to the traffic lights.
@interface TweakNavButtons : NSView
@end
