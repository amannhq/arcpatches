// Privacy, layer 1: the Chromium command line (--host-resolver-rules, added to argv
// before main(), so blocked hosts fail DNS in the web engine and its network
// service), and the local agent runtime, which isn't started while AI is hidden.
#import "PrivacyInternal.h"
#import "Browser.h"
#include <spawn.h>

#pragma mark - Chromium layer (command line)

// Dia starts Chromium from an ArcBrowserApplicationConfiguration whose argc/argv
// getters supply the command line; append --host-resolver-rules there.
static NSString *resolverSwitch(void) {
    NSArray *hosts = TweakPrivacyBlockedHosts();
    if (!hosts.count) return nil;
    NSMutableArray *rules = [NSMutableArray array];
    for (NSString *h in hosts) {
        [rules addObject:[NSString stringWithFormat:@"MAP %@ ~NOTFOUND", h]];
        [rules addObject:[NSString stringWithFormat:@"MAP *.%@ ~NOTFOUND", h]];
    }
    return [@"--host-resolver-rules=" stringByAppendingString:[rules componentsJoinedByString:@","]];
}

// Marks the command line as already extended (so repeated getter calls don't append twice).
static NSString *const kMarker = @"--arcpatches";

static int (*origArgc)(id, SEL);
static NSArray *(*origArgv)(id, SEL);

static BOOL hasSwitch(NSArray *argv) { return [argv containsObject:kMarker]; }

static NSArray *hookedArgv(id self, SEL _cmd) {
    NSArray *argv = origArgv(self, _cmd);
    if (hasSwitch(argv) || (argv.count && ![argv.firstObject isKindOfClass:NSString.class])) return argv;
    NSMutableArray *extra = [TweakPerformanceSwitches() mutableCopy];
    NSString *sw = resolverSwitch();
    if (sw) [extra addObject:sw];
    [extra addObject:kMarker];
    return [argv arrayByAddingObjectsFromArray:extra];
}

static int hookedArgc(id self, SEL _cmd) {
    NSArray *argv = origArgv(self, @selector(argv));
    return (int)hookedArgv(self, @selector(argv)).count - (int)argv.count + origArgc(self, _cmd);
}

void TweakPrivacyPatchArgv(void) {
    Class cls = NSClassFromString(kDiaAppConfigurationClass);
    if (!cls) { NSLog(@"[arcpatches] ArcBrowserApplicationConfiguration not found; web-engine blocking inactive"); return; }
    origArgv = (void *)TweakHook(cls, @selector(argv), (IMP)hookedArgv);
    if (origArgv) origArgc = (void *)TweakHook(cls, @selector(argc), (IMP)hookedArgc);
}

#pragma mark - Local agent runtime

// Dia's AgentServerManager posix_spawns Resources/agent-server-resources/dist/agent-server
// (a local agent runtime on 127.0.0.1). Don't start it while AI features are hidden.
// dyld interposing applies because arcpatches is an inserted library.
static BOOL refuseSpawn(const char *path) {
    if (!path || !strstr(path, "agent-server-resources")) return NO;
    if (![TweakSettings boolForKey:TweakKeyHideAI]) return NO;
    static int logged;
    if (logged++ < 3) NSLog(@"[arcpatches] not starting agent-server");
    return YES;
}

static int ad_posix_spawn(pid_t *pid, const char *path, const posix_spawn_file_actions_t *fa,
                          const posix_spawnattr_t *attr, char *const argv[], char *const envp[]) {
    if (refuseSpawn(path)) return EPERM;
    return posix_spawn(pid, path, fa, attr, argv, envp);
}

static int ad_posix_spawnp(pid_t *pid, const char *file, const posix_spawn_file_actions_t *fa,
                           const posix_spawnattr_t *attr, char *const argv[], char *const envp[]) {
    if (refuseSpawn(file)) return EPERM;
    return posix_spawnp(pid, file, fa, attr, argv, envp);
}

__attribute__((used)) static const struct { const void *replacement, *original; } interposers[]
    __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)ad_posix_spawn, (const void *)posix_spawn},
    {(const void *)ad_posix_spawnp, (const void *)posix_spawnp},
};
