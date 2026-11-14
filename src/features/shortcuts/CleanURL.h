// Link text for the Arc copy shortcuts. Foundation only, so it can be tested without a browser.
#import <Foundation/Foundation.h>

// The URL without tracking parameters (utm_*, fbclid, gclid, mc_eid, igshid, si).
// Anything else, the fragment and the original encoding are kept; unparseable input
// comes back unchanged.
NSString *TweakCleanURL(NSString *url);
// "[title](url)" with the title's brackets escaped; the URL stands in for an empty title.
NSString *TweakMarkdownLink(NSString *title, NSString *url);
