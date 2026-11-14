#import "Browsers.h"
#import "../browsers/dia/Browser.h"
#import "../browsers/ardia/Browser.h"
#import "../browsers/chrome/Browser.h"

// id → {bundle id, display name}. Original Arc (company.thebrowser.Browser) is
// deliberately absent: it is discontinued.
static NSDictionary<NSString *, NSArray<NSString *> *> *registry(void) {
    static NSDictionary *r;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        r = @{
            kDiaBrowserID: @[kDiaBundleID, kDiaDisplayName],
            kArdiaBrowserID: @[kArdiaBundleID, kArdiaDisplayName],
            kChromeBrowserID: @[kChromeBundleID, kChromeDisplayName],
        };
    });
    return r;
}

NSString *TweakBrowserIdForBundleId(NSString *bundleId) {
    if (!bundleId) return nil;
    for (NSString *browserId in registry())
        if ([registry()[browserId][0] isEqualToString:bundleId]) return browserId;
    return nil;
}

NSString *TweakBrowserDisplayName(NSString *browserId) {
    return browserId ? registry()[browserId][1] : nil;
}

NSString *TweakBrowserSupportDir(NSString *browserId) {
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
    return [browserId isEqualToString:kDiaBrowserID] || !browserId.length ? dir : [dir stringByAppendingPathComponent:browserId];
}
