// Performance: turns off Dia's on-device AI service and exposes a few Chromium
// switches. Chromium switches are read once at launch: in Dia through Privacy's
// argv hook (PrivacyArgv.m), in Ardia through its ARDIA_CHROMIUM_SWITCHES variable.
#import "Common.h"
#import "Features.h"
#import "Browser.h"
#import "../../browsers/ardia/Browser.h"
#import <objc/runtime.h>

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

// Answers a skipped initialize:callback: with "nothing"/failure (nil, NO, 0) so whoever
// awaits it moves on. Only for void blocks whose arguments are all objects, blocks, BOOLs
// or integers (all passed as one zeroed register); otherwise NO and the caller lets Dia start
// the service.
static BOOL answerWithFailure(id callback) {
    const char *sig = blockSignature(callback);
    NSMethodSignature *ms = nil;
    @try { ms = sig ? [NSMethodSignature signatureWithObjCTypes:sig] : nil; } @catch (__unused NSException *e) {}
    if (!ms || ms.methodReturnType[0] != 'v' || ms.numberOfArguments > 5) return NO;
    for (NSUInteger i = 1; i < ms.numberOfArguments; i++)   // 0 is the block itself
        if (!strchr("@#BcCsSiIlLqQ", [ms getArgumentTypeAtIndex:i][0])) return NO;
    void (*invoke)(id, long, long, long, long) = ((struct TweakBlockLayout *)(__bridge void *)callback)->invoke;
    dispatch_async(dispatch_get_main_queue(), ^{ invoke(callback, 0, 0, 0, 0); });   // extra zeroed registers are ignored
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
