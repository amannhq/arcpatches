// Privacy, layer 2: blocked hosts, and the URLSession side of blocking (Dia's
// native Swift layer). An NSURLProtocol fails requests to blocked hosts, and
// WebSocket tasks are redirected to an invalid host.
#import "PrivacyInternal.h"
#import <objc/runtime.h>

static NSUInteger gBlockedCount;
static NSLock *gLock;

NSArray<NSString *> *TweakAIHosts(void) {
    return @[@"aiproxy.diabrowser.engineering", @"ai-service.diabrowser.engineering",
             @"ai-service.staging.diabrowser.engineering", @"ai-service-eval.diabrowser.engineering",
             @"websearch.diabrowser.engineering", @"webresultproxy.diabrowser.engineering",
             @"artifactcdn.diabrowser.engineering", @"generativelanguage.googleapis.com"];
}

NSArray<NSString *> *TweakTelemetryHosts(void) {
    // LaunchDarkly *flag* fetches (clientstream/clientsdk) stay allowed: Dia needs them to start.
    return @[@"browser-intake-datadoghq.com", @"datadoghq.com", @"ingest.us.sentry.io", @"sentry.io",
             @"api.segment.io", @"cdn-settings.segment.com", @"segment.io",
             @"mobile.launchdarkly.com", @"events.launchdarkly.com",
             @"otel-gateway.diabrowser.engineering"];
}

NSArray<NSString *> *TweakPrivacyBlockedHosts(void) {
    NSMutableArray *h = [NSMutableArray array];
    if ([TweakSettings boolForKey:TweakKeyBlockAI]) [h addObjectsFromArray:TweakAIHosts()];
    if ([TweakSettings boolForKey:TweakKeyBlockTelemetry]) [h addObjectsFromArray:TweakTelemetryHosts()];
    return h;
}

static BOOL isBlocked(NSString *host) {
    host = host.lowercaseString;
    if (!host.length) return NO;
    for (NSString *b in TweakPrivacyBlockedHosts())
        if ([host isEqualToString:b] || [host hasSuffix:[@"." stringByAppendingString:b]]) return YES;
    return NO;
}

NSUInteger TweakBlockedRequestCount(void) {
    [gLock lock];
    NSUInteger n = gBlockedCount;
    [gLock unlock];
    return n;
}

static void noteBlocked(NSURL *url) {
    [gLock lock];
    gBlockedCount++;
    [gLock unlock];
    NSLog(@"[arcpatches] blocked %@", url.host);
}

#pragma mark - URLSession layer

@interface TweakBlockProtocol : NSURLProtocol
@end

@implementation TweakBlockProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)r { return isBlocked(r.URL.host); }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)r { return r; }
- (void)startLoading {
    noteBlocked(self.request.URL);
    [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil]];
}
- (void)stopLoading {}
@end

static NSURLSession *(*origSessionWithConfig)(id, SEL, NSURLSessionConfiguration *, id, NSOperationQueue *);
static NSURLSession *hookedSessionWithConfig(id self, SEL _cmd, NSURLSessionConfiguration *c, id d, NSOperationQueue *q) {
    if (c && ![c.protocolClasses containsObject:TweakBlockProtocol.class])
        c.protocolClasses = [@[TweakBlockProtocol.class] arrayByAddingObjectsFromArray:c.protocolClasses ?: @[]];
    return origSessionWithConfig(self, _cmd, c, d, q);
}

static NSURLSession *(*origSessionWithConfigOnly)(id, SEL, NSURLSessionConfiguration *);
static NSURLSession *hookedSessionWithConfigOnly(id self, SEL _cmd, NSURLSessionConfiguration *c) {
    if (c && ![c.protocolClasses containsObject:TweakBlockProtocol.class])
        c.protocolClasses = [@[TweakBlockProtocol.class] arrayByAddingObjectsFromArray:c.protocolClasses ?: @[]];
    return origSessionWithConfigOnly(self, _cmd, c);
}

// NSURLProtocol doesn't see WebSocket tasks; point blocked ones at an unroutable host.
static NSURL *wsRewrite(NSURL *u) {
    if (!isBlocked(u.host)) return u;
    noteBlocked(u);
    return [NSURL URLWithString:@"wss://blocked.invalid/"];
}
static id (*origWSURL)(id, SEL, NSURL *);
static id hookedWSURL(id self, SEL _cmd, NSURL *u) { return origWSURL(self, _cmd, wsRewrite(u)); }
static id (*origWSURLProtocols)(id, SEL, NSURL *, NSArray *);
static id hookedWSURLProtocols(id self, SEL _cmd, NSURL *u, NSArray *p) { return origWSURLProtocols(self, _cmd, wsRewrite(u), p); }
static id (*origWSRequest)(id, SEL, NSURLRequest *);
static id hookedWSRequest(id self, SEL _cmd, NSURLRequest *r) {
    if (!isBlocked(r.URL.host)) return origWSRequest(self, _cmd, r);
    NSMutableURLRequest *m = [r mutableCopy];
    m.URL = wsRewrite(r.URL);
    return origWSRequest(self, _cmd, m);
}

void TweakPrivacyInstallNetwork(void) {
    gLock = [NSLock new];
    [NSURLProtocol registerClass:TweakBlockProtocol.class];
    Class meta = object_getClass(NSURLSession.class);
    origSessionWithConfig = (void *)TweakHook(meta, @selector(sessionWithConfiguration:delegate:delegateQueue:), (IMP)hookedSessionWithConfig);
    origSessionWithConfigOnly = (void *)TweakHook(meta, @selector(sessionWithConfiguration:), (IMP)hookedSessionWithConfigOnly);
    origWSURL = (void *)TweakHook(NSURLSession.class, @selector(webSocketTaskWithURL:), (IMP)hookedWSURL);
    origWSURLProtocols = (void *)TweakHook(NSURLSession.class, @selector(webSocketTaskWithURL:protocols:), (IMP)hookedWSURLProtocols);
    origWSRequest = (void *)TweakHook(NSURLSession.class, @selector(webSocketTaskWithRequest:), (IMP)hookedWSRequest);
}
