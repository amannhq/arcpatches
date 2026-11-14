// Privacy: hides Dia's AI surfaces (PrivacyUI.m) and blocks AI + telemetry hosts.
//
// Blocking happens in two layers:
//  1. Chromium (web engine + its network service): --host-resolver-rules added to
//     argv before main(), so blocked hosts fail DNS. Applied at launch only. (PrivacyArgv.m)
//  2. Dia's native Swift layer (URLSession): an NSURLProtocol that fails requests
//     to blocked hosts, and WebSocket tasks redirected to an invalid host. (PrivacyHosts.m)
#import "PrivacyInternal.h"
#import "Features.h"
#import "Browser.h"

NSString *const TweakKeyHideAI = @"arcpatches.hideAI";
NSString *const TweakKeyBlockAI = @"arcpatches.blockAI";
NSString *const TweakKeyBlockTelemetry = @"arcpatches.blockTelemetry";

void TweakPrivacyInstall(void) {
    TweakPrivacyInstallNetwork();
    dispatch_async(dispatch_get_main_queue(), ^{ TweakPrivacyInstallUI(); });
}

static void installPrivacyEarly(void) {
    TweakPrivacyPatchArgv();
    TweakPrivacyInstall();  // URLSession hooks must exist before Dia creates its sessions
}

const TweakFeature TweakFeaturePrivacy = {"privacy", {TWEAK_BROWSER_DIA}, installPrivacyEarly, NULL};
