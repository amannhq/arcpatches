// Ardia (com.ardia.browser): the browser descriptor. Ardia is a React Native macOS UI
// over CEF; its sidebar, command bar and settings are JavaScript views with no stable
// native class names, so none of Dia's UI features apply. What does apply is its
// Chromium command line, which Ardia extends from an environment variable
// (docs/browsers.md has the details and the support matrix).
#import <Foundation/Foundation.h>

#define TWEAK_BROWSER_ARDIA "ardia"   // the id features list in TweakFeature.browsers

extern NSString *const kArdiaBrowserID;       // "ardia"
extern NSString *const kArdiaBundleID;        // com.ardia.browser
extern NSString *const kArdiaDisplayName;     // Ardia
extern NSString *const kArdiaAppPath;         // /Applications/Ardia.app

// Ardia's CEF launcher reads this with getenv(), splits it on " --" and appends each
// switch to Chromium's command line, but only when the running app has no Team ID in
// its signature (a dev build, or an ad hoc re-signed one such as Ardia Arc).
extern NSString *const kArdiaChromiumSwitchesEnv;   // ARDIA_CHROMIUM_SWITCHES

// Appends switches (each "--name" or "--name=value") to ARDIA_CHROMIUM_SWITCHES,
// keeping whatever is already set. Call before main(): Ardia reads it at launch only.
void TweakArdiaAppendChromiumSwitches(NSArray<NSString *> *switches);

// Health checks for the companion: Ardia's launcher still reads the variable.
NSDictionary<NSString *, NSNumber *> *TweakArdiaHealthChecks(void);
