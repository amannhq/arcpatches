#import "Features.h"

static NSString *gBrowser;

void TweakSetRunningBrowser(NSString *browserId) { gBrowser = [browserId copy]; }
NSString *TweakRunningBrowser(void) { return gBrowser; }

BOOL TweakFeatureSupports(const TweakFeature *feature, NSString *browserId) {
    if (!feature || !browserId.length) return NO;
    for (size_t i = 0; i < sizeof feature->browsers / sizeof feature->browsers[0] && feature->browsers[i]; i++)
        if (strcmp(feature->browsers[i], browserId.UTF8String) == 0) return YES;
    return NO;
}

BOOL TweakFeatureActive(const TweakFeature *feature) { return TweakFeatureSupports(feature, gBrowser); }
