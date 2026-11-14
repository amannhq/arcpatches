// Demo stand-ins for SiteControlsData.m (left out of the screenshot build), so the site
// controls popover shows well-known public extensions and permissions, never the user's profile.
#import "shots.h"
#import "../../src/features/sidebar/SiteControlsData.h"

@implementation TweakSiteExtension
@end

NSArray<TweakSiteExtension *> *TweakSiteExtensions(void (^done)(NSArray<TweakSiteExtension *> *)) {
    // Each extension's icon is its project site's favicon.
    NSArray *demo = @[@[@"1password.com", @"1Password"], @[@"ublockorigin.com", @"uBlock Origin"],
                      @[@"grammarly.com", @"Grammarly"], @[@"react.dev", @"React Developer Tools"]];
    NSMutableArray *list = [NSMutableArray array];
    for (NSUInteger i = 0; i < demo.count; i++) {
        TweakSiteExtension *e = [TweakSiteExtension new];
        e.identifier = [NSString stringWithFormat:@"demo%lu", (unsigned long)i];
        e.name = demo[i][1];
        e.icon = ShotSiteIcon(demo[i][0], 20);
        [list addObject:e];
    }
    return list;
}

NSArray<NSDictionary *> *TweakSitePermissions(NSString *url) {
    return @[@{@"title": @"Notifications", @"symbol": @"bell", @"state": @"Allowed"}];
}
