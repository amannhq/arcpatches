// Browser registry: every browser this build knows (src/browsers/<id>/), by bundle id.
// A patched copy keeps its browser's bundle id ("Dia Arc" is still company.thebrowser.dia),
// so this is how the entry point tells which browser it was loaded into. Which features
// run there is up to each feature's TweakFeature.browsers list (Features.h).
#import <Foundation/Foundation.h>

NSString *TweakBrowserIdForBundleId(NSString *bundleId);   // "dia", "ardia", "chrome"; nil if unknown
NSString *TweakBrowserDisplayName(NSString *browserId);    // "Dia"; nil if unknown

// Where the companion looks for this browser's health.json: arcpatches/ for Dia (as
// before), arcpatches/<id>/ for the others.
NSString *TweakBrowserSupportDir(NSString *browserId);
