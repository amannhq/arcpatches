// Performance: turns off Dia's on-device AI service and exposes a few Chromium
// switches. Chromium switches are read once at launch: in Dia through Privacy's
// argv hook (PrivacyArgv.m), in Ardia through its ARDIA_CHROMIUM_SWITCHES variable.
#import "Common.h"
#import "Features.h"
#import "Browser.h"
#import "../../browsers/ardia/Browser.h"
#import <objc/runtime.h>
#include <ctype.h>

NSString *const TweakKeyDisableOnDeviceAI = @"arcpatches.disableOnDeviceAI";
NSString *const TweakKeyNoBackgroundNetworking = @"arcpatches.noBackgroundNetworking";
NSString *const TweakKeyRendererLimit = @"arcpatches.rendererProcessLimit";   // 0 = Chromium default

#pragma mark - On-device AI

// ArcAIService fronts the ai.mojom.AIService utility process. With AI hidden its
// only remaining use is classifying every string typed into the URL editor, so
// never start it.
static BOOL onDeviceAIOff(void) {
    return [TweakSettings boolForKey:TweakKeyHideAI] && [TweakSettings boolForKey:TweakKeyDisableOnDeviceAI];
}

// clang's block ABI (Block_layout / Block_descriptor).
struct TweakBlockLayout { void *isa; int flags, reserved; void *invoke; struct { unsigned long reserved, size; void *rest[]; } *desc; };

// A block's own type signature, or NULL.
static const char *blockSignature(id block) {
    struct TweakBlockLayout *b = (__bridge void *)block;
    enum { HasCopyDispose = 1 << 25, HasSignature = 1 << 30 };
    if (!b || !b->desc || !(b->flags & HasSignature)) return NULL;
    return b->desc->rest[(b->flags & HasCopyDispose) ? 2 : 0];
}

// Answers a skipped initialize:callback: with failure so whoever awaits it moves on:
// an NSError argument gets a real error, other named objects nil, a BOOL NO. Only for
// void blocks whose signature names every argument that way (nil for an unnamed object
// or 0 for an integer could read as success); otherwise NO and Dia starts the service.
static BOOL answerWithFailure(id callback) {
    const char *p = blockSignature(callback);
    if (!p || *p++ != 'v') return NO;
    while (isdigit(*p)) p++;
    if (strncmp(p, "@?", 2)) return NO;   // the block itself
    for (p += 2; isdigit(*p); p++);
    NSError *err = [NSError errorWithDomain:@"dev.amannhq.arcpatches" code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"On-device AI is turned off by ArcPatches"}];
    struct { long v[4]; } args = {{0}};   // a struct, so the block below can capture it
    int n = 0;
    while (*p) {
        if (n == 4) return NO;
        if (!strncmp(p, "@\"NSError\"", 10)) { args.v[n] = (long)(__bridge void *)err; p += 10; }
        else if (p[0] == '@' && p[1] == '"') { const char *q = strchr(p + 2, '"'); if (!q) return NO; p = q + 1; }
        else if (*p == 'B' || *p == 'c') p++;
        else return NO;
        n++;
        while (isdigit(*p)) p++;
    }
    void (*invoke)(id, long, long, long, long) = ((struct TweakBlockLayout *)(__bridge void *)callback)->invoke;
    dispatch_async(dispatch_get_main_queue(), ^{   // captures err and callback; unused registers are ignored
        (void)err;
        invoke(callback, args.v[0], args.v[1], args.v[2], args.v[3]);
    });
    return YES;
}

static void (*origAIInitialize)(id, SEL, id, id);
static void hookedAIInitialize(id self, SEL _cmd, id config, id callback) {
    if (onDeviceAIOff()) {
        if (!callback) { NSLog(@"[arcpatches] on-device AI service not started"); return; }
        if (answerWithFailure(callback)) { NSLog(@"[arcpatches] on-device AI service not started (callback answered)"); return; }
        static BOOL logged;
        if (!logged) { logged = YES; NSLog(@"[arcpatches] AI initialize callback has an unknown shape; service starts anyway"); }
    }
    origAIInitialize(self, _cmd, config, callback);
}

static BOOL (*origAIIsAvailable)(id, SEL);
static BOOL hookedAIIsAvailable(id self, SEL _cmd) {
    return onDeviceAIOff() ? NO : origAIIsAvailable(self, _cmd);
}

#pragma mark - Chromium switches

NSArray<NSString *> *TweakPerformanceSwitches(void) {
    NSMutableArray *s = [NSMutableArray array];
    if ([TweakSettings boolForKey:TweakKeyNoBackgroundNetworking]) [s addObject:@"--disable-background-networking"];
    NSInteger limit = [NSUserDefaults.standardUserDefaults integerForKey:TweakKeyRendererLimit];
    if (limit > 0) [s addObject:[NSString stringWithFormat:@"--renderer-process-limit=%ld", (long)limit]];
    return s;
}

void TweakPerformanceInstall(void) {
    Class ai = NSClassFromString(kDiaAIServiceClass);
    if (ai) {
        // Only hook initialize:callback: while it still is -(void)x:(id)config callback:(block).
        Method m = class_getInstanceMethod(ai, @selector(initialize:callback:));
        const char *types = m ? method_getTypeEncoding(m) : NULL;
        NSMethodSignature *ms = nil;
        @try { ms = types ? [NSMethodSignature signatureWithObjCTypes:types] : nil; } @catch (__unused NSException *e) {}
        if (ms && ms.numberOfArguments == 4 && ms.methodReturnType[0] == 'v' && [ms getArgumentTypeAtIndex:2][0] == '@' &&
            !strcmp([ms getArgumentTypeAtIndex:3], "@?"))
            origAIInitialize = (void *)TweakHook(ai, @selector(initialize:callback:), (IMP)hookedAIInitialize);
        else
            NSLog(@"[arcpatches] ArcAIService initialize:callback: is %s; on-device AI not stopped at start", types ?: "missing");
        origAIIsAvailable = (void *)TweakHook(ai, @selector(isAvailable), (IMP)hookedAIIsAvailable);
    } else {
        NSLog(@"[arcpatches] ArcAIService not found; on-device AI switch inactive");
    }
}

// Ardia has no ArcAIService (on-device AI) to stop; only the switches apply there.
static void installPerformanceEarly(void) {
    if ([TweakRunningBrowser() isEqualToString:kArdiaBrowserID]) TweakArdiaAppendChromiumSwitches(TweakPerformanceSwitches());
    else TweakPerformanceInstall();
}

const TweakFeature TweakFeaturePerformance = {"performance", {TWEAK_BROWSER_DIA, TWEAK_BROWSER_ARDIA}, installPerformanceEarly, NULL};
