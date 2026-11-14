#import "Browser.h"
#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <stdlib.h>
#include <string.h>

NSString *const kArdiaBrowserID = @TWEAK_BROWSER_ARDIA;
NSString *const kArdiaBundleID = @"com.ardia.browser";
NSString *const kArdiaDisplayName = @"Ardia";
NSString *const kArdiaAppPath = @"/Applications/Ardia.app";
NSString *const kArdiaChromiumSwitchesEnv = @"ARDIA_CHROMIUM_SWITCHES";

void TweakArdiaAppendChromiumSwitches(NSArray<NSString *> *switches) {
    if (!switches.count) return;
    const char *name = kArdiaChromiumSwitchesEnv.UTF8String;
    const char *current = getenv(name);
    NSString *added = [switches componentsJoinedByString:@" "];
    NSString *value = current && *current ? [NSString stringWithFormat:@"%s %@", current, added] : added;
    setenv(name, value.UTF8String, 1);
    NSLog(@"[arcpatches] Chromium switches for Ardia: %@", added);
}

// The variable's name is a C string literal in the main executable's __cstring
// section; if an update drops it, the switches silently stop applying.
static BOOL mainImageHasCString(const char *s) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const struct mach_header *h = _dyld_get_image_header(i);
        if (h->filetype != MH_EXECUTE) continue;
        unsigned long size = 0;
        const uint8_t *data = getsectiondata((const struct mach_header_64 *)h, "__TEXT", "__cstring", &size);
        size_t len = strlen(s) + 1;   // with the terminator: the whole literal, not a prefix
        return data && memmem(data, size, s, len) != NULL;
    }
    return NO;
}

NSDictionary<NSString *, NSNumber *> *TweakArdiaHealthChecks(void) {
    return @{@"Chromium switches": @(mainImageHasCString(kArdiaChromiumSwitchesEnv.UTF8String))};
}
