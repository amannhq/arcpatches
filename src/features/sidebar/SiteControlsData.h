// What the site controls popover shows that comes from the browser profile on disk:
// installed extensions and the page's per-site permission exceptions. Read-only; every
// JSON level is type-checked, so a malformed or missing file just yields nothing.
#import <AppKit/AppKit.h>

@interface TweakSiteExtension : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSImage *icon;   // nil: the caller draws a generic one
@end

// The last parsed list (possibly empty), and a refresh if it is older than a few seconds.
// done runs on the main queue only when a refresh actually happened.
NSArray<TweakSiteExtension *> *TweakSiteExtensions(void (^done)(NSArray<TweakSiteExtension *> *));

// Rows for the permissions this site has an exception for: {title, symbol, state},
// state being "Allowed", "Blocked" or "Ask". Read from the profile's Preferences.
NSArray<NSDictionary *> *TweakSitePermissions(NSString *url);
