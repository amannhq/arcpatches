// Browser registry and support matrix, run against the built arcpatches.dylib (no
// browser needed): which bundle ids are recognised, which features each browser gets,
// and that Ardia's switches survive the way Ardia parses ARDIA_CHROMIUM_SWITCHES.
#import <Foundation/Foundation.h>
#import "Features.h"
#import "Browsers.h"
#import "browsers/ardia/Browser.h"
#include <stdlib.h>

static int failures;
#define CHECK(cond) do { if (!(cond)) { fprintf(stderr, "FAIL %s:%d %s\n", __FILE__, __LINE__, #cond); failures++; } } while (0)

// What Ardia's launcher does with the variable (seen in its binary): prefix a space,
// split on " --", trim each part, put "--" back.
static NSArray<NSString *> *ardiaParse(const char *value) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *part in [[@" " stringByAppendingString:@(value)] componentsSeparatedByString:@" --"]) {
        NSString *t = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (t.length) [out addObject:[@"--" stringByAppendingString:t]];
    }
    return out;
}

int main(void) {
    @autoreleasepool {
        CHECK([TweakBrowserIdForBundleId(@"company.thebrowser.dia") isEqualToString:@"dia"]);
        CHECK([TweakBrowserIdForBundleId(@"com.ardia.browser") isEqualToString:@"ardia"]);
        CHECK([TweakBrowserIdForBundleId(@"com.google.Chrome") isEqualToString:@"chrome"]);
        CHECK(TweakBrowserIdForBundleId(@"company.thebrowser.Browser") == nil);   // original Arc: excluded
        CHECK(TweakBrowserIdForBundleId(nil) == nil);
        CHECK([TweakBrowserDisplayName(@"dia") isEqualToString:@"Dia"]);
        CHECK([TweakBrowserSupportDir(@"dia") hasSuffix:@"/Application Support/arcpatches"]);
        CHECK([TweakBrowserSupportDir(@"ardia") hasSuffix:@"/Application Support/arcpatches/ardia"]);

        const TweakFeature *all[] = {&TweakFeaturePrivacy, &TweakFeaturePerformance, &TweakFeatureTabs, &TweakFeatureSidebar,
                                     &TweakFeaturePreferences, &TweakFeatureCommandBar, &TweakFeatureShortcuts, &TweakFeatureTopRow};
        for (size_t i = 0; i < sizeof all / sizeof all[0]; i++) {
            CHECK(TweakFeatureSupports(all[i], @"dia"));
            CHECK(!TweakFeatureSupports(all[i], @"chrome"));
            CHECK(TweakFeatureSupports(all[i], @"ardia") == (all[i] == &TweakFeaturePerformance));
        }

        setenv("ARDIA_CHROMIUM_SWITCHES", "--user-set", 1);
        NSArray *mine = @[@"--disable-background-networking", @"--renderer-process-limit=4",
                          @"--host-resolver-rules=MAP a.test ~NOTFOUND,MAP *.a.test ~NOTFOUND"];
        TweakArdiaAppendChromiumSwitches(mine);
        TweakArdiaAppendChromiumSwitches(@[]);   // nothing to add: leaves it alone
        NSArray *expected = [@[@"--user-set"] arrayByAddingObjectsFromArray:mine];
        CHECK([ardiaParse(getenv("ARDIA_CHROMIUM_SWITCHES")) isEqualToArray:expected]);
        unsetenv("ARDIA_CHROMIUM_SWITCHES");
        TweakArdiaAppendChromiumSwitches(@[@"--a"]);
        CHECK(strcmp(getenv("ARDIA_CHROMIUM_SWITCHES"), "--a") == 0);
    }
    return failures ? 1 : 0;
}
