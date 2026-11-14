// Google Chrome (com.google.Chrome): the browser descriptor. Recognised so the
// entry point can name it, but no feature supports it: Chrome's UI is Chromium Views
// (C++, no Objective-C or Swift view classes to hook), all its code lives in a
// framework that loads after arcpatches' constructor, its command line comes straight
// from main()'s argv with no config or environment hook, and its executable is
// universal (x86_64 + arm64), which the patcher doesn't handle. docs/browsers.md
// has the full support matrix.
#import <Foundation/Foundation.h>

#define TWEAK_BROWSER_CHROME "chrome"   // the id features would list in TweakFeature.browsers

extern NSString *const kChromeBrowserID;      // "chrome"
extern NSString *const kChromeBundleID;       // com.google.Chrome
extern NSString *const kChromeDisplayName;    // Chrome
extern NSString *const kChromeAppPath;        // /Applications/Google Chrome.app
