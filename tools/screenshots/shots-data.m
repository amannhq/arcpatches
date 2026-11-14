// Demo stand-ins for SiteControlsData.m (left out of the screenshot build), so the site
// controls popover shows generic extensions and permissions, never the user's profile.
#import "shots.h"
#import "../../src/features/sidebar/SiteControlsData.h"

@implementation TweakSiteExtension
@end

NSArray<TweakSiteExtension *> *TweakSiteExtensions(void (^done)(NSArray<TweakSiteExtension *> *)) {
    NSArray *demo = @[@[@"P", @"Password manager"], @[@"A", @"Ad blocker"], @[@"R", @"Reader view"],
                      @[@"N", @"Notes"], @[@"T", @"Translate"]];
    NSMutableArray *list = [NSMutableArray array];
    for (NSUInteger i = 0; i < demo.count; i++) {
        TweakSiteExtension *e = [TweakSiteExtension new];
        e.identifier = [NSString stringWithFormat:@"demo%lu", (unsigned long)i];
        e.name = demo[i][1];
        e.icon = ShotLetterIcon(demo[i][0], (NSInteger)i + 3, 20);
        [list addObject:e];
    }
    return list;
}

NSArray<NSDictionary *> *TweakSitePermissions(NSString *url) {
    return @[@{@"title": @"Notifications", @"symbol": @"bell", @"state": @"Allowed"}];
}
