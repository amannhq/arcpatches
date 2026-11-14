#import "CleanURL.h"

static BOOL isTrackingParameter(NSString *name) {
    NSString *n = name.lowercaseString;
    static NSSet *exact;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ exact = [NSSet setWithArray:@[@"fbclid", @"gclid", @"mc_eid", @"igshid", @"si"]]; });
    return [n hasPrefix:@"utm_"] || [exact containsObject:n];
}

NSString *TweakCleanURL(NSString *url) {
    if (!url.length) return url;
    NSURLComponents *c = [NSURLComponents componentsWithString:url];
    NSArray<NSURLQueryItem *> *items = c.percentEncodedQueryItems;
    if (!items.count) return url;
    NSMutableArray<NSURLQueryItem *> *kept = [NSMutableArray arrayWithCapacity:items.count];
    for (NSURLQueryItem *i in items)
        if (!isTrackingParameter(i.name)) [kept addObject:i];
    if (kept.count == items.count) return url;   // untouched: no re-serialising
    c.percentEncodedQueryItems = kept.count ? kept : nil;   // nil, or a bare "?" is left behind
    return c.string ?: url;
}

NSString *TweakMarkdownLink(NSString *title, NSString *url) {
    NSString *t = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!t.length) t = url;
    t = [t stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    t = [t stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
    t = [t stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
    t = [[t componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] componentsJoinedByString:@" "];
    // Parentheses and spaces would end the link target early.
    NSString *u = [url stringByReplacingOccurrencesOfString:@"(" withString:@"%28"];
    u = [u stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
    u = [u stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    return [NSString stringWithFormat:@"[%@](%@)", t, u];
}
