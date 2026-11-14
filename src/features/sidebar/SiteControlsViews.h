// The building blocks of the site controls popover (SiteControlsPopover.m).
#import <AppKit/AppKit.h>

// A rounded square with a subtle fill that brightens on hover: one action, one extension.
@interface TweakSiteTile : NSButton
+ (instancetype)tileWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action;
+ (instancetype)tileWithImage:(NSImage *)image label:(NSString *)label target:(id)target action:(SEL)action;
@property (nonatomic) CGFloat radius;   // default 8; half the height makes it round
@end

// A settings row: a round icon, a title and a dimmer subtitle.
@interface TweakSiteRow : NSButton
+ (instancetype)rowWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle target:(id)target action:(SEL)action;
@end

NSTextField *TweakSiteSectionHeader(NSString *title);
// "Secure" with a lock, or "Not secure" with an open lock, in a capsule.
NSView *TweakSiteSecurityBadge(BOOL secure);
