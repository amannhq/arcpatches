// Feature registry. Each feature (src/features/<name>/) declares the browsers it
// supports, by browser id (src/browsers/<id>/); the entry point installs a feature
// only when the running app is one of them.
#import <Foundation/Foundation.h>

typedef struct {
    const char *name;
    const char *browsers[4];   // browser ids, e.g. TWEAK_BROWSER_DIA; unused slots are NULL
    void (*early)(void);       // before main(): hooks the browser's startup needs, or NULL
    void (*install)(void);     // on the main queue once AppKit is up, or NULL
} TweakFeature;

void TweakSetRunningBrowser(NSString *browserId);   // the entry point, at load
NSString *TweakRunningBrowser(void);                // e.g. "dia"; nil in an app no browser matched
BOOL TweakFeatureSupports(const TweakFeature *feature, NSString *browserId);
BOOL TweakFeatureActive(const TweakFeature *feature);   // supports the running browser

extern const TweakFeature TweakFeaturePrivacy;
extern const TweakFeature TweakFeaturePerformance;
extern const TweakFeature TweakFeatureTabs;
extern const TweakFeature TweakFeatureSidebar;
extern const TweakFeature TweakFeaturePreferences;
extern const TweakFeature TweakFeatureCommandBar;
extern const TweakFeature TweakFeatureShortcuts;
extern const TweakFeature TweakFeatureTopRow;
