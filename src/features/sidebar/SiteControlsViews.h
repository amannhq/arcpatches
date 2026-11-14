// The building blocks of the site controls popover (SiteControlsPopover.m).
#import <AppKit/AppKit.h>

// A borderless button with Arc's fills: one at rest, a stronger one fading in under the
// pointer, and ArcFillPressed while the mouse is down.
@interface TweakSiteButton : NSButton
@property (nonatomic, readonly) BOOL hovering, pressed;
@end

// A rounded square with a subtle fill that brightens on hover: one action, one extension.
@interface TweakSiteTile : TweakSiteButton
+ (instancetype)tileWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action;
+ (instancetype)tileWithImage:(NSImage *)image label:(NSString *)label target:(id)target action:(SEL)action;
@property (nonatomic) CGFloat radius;   // default ArcRadiusMedium; half the height makes it round
@end

// A settings row: a round icon, a title and a dimmer subtitle.
@interface TweakSiteRow : TweakSiteButton
+ (instancetype)rowWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle target:(id)target action:(SEL)action;
@end

NSTextField *TweakSiteSectionHeader(NSString *title);
// "Secure" with a lock, or "Not secure" with an open lock, in a capsule.
NSView *TweakSiteSecurityBadge(BOOL secure);
