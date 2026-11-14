// TweakCleanURL and TweakMarkdownLink (src/features/shortcuts/CleanURL.m): the text
// the Arc copy shortcuts put on the clipboard. Foundation only, no browser needed.
#import <Foundation/Foundation.h>
#import "CleanURL.h"

static int failures;
static void expect(NSString *got, NSString *want, int line) {
    if ([got isEqualToString:want]) return;
    fprintf(stderr, "FAIL cleanurl.m:%d\n  got  %s\n  want %s\n", line, got.UTF8String, want.UTF8String);
    failures++;
}
#define EXPECT(got, want) expect((got), (want), __LINE__)

int main(void) {
    @autoreleasepool {
        // Tracking parameters go, whatever their case.
        EXPECT(TweakCleanURL(@"https://a.test/p?utm_source=x&utm_medium=y&UTM_Campaign=z"), @"https://a.test/p");
        EXPECT(TweakCleanURL(@"https://a.test/?fbclid=1"), @"https://a.test/");
        EXPECT(TweakCleanURL(@"https://a.test/?gclid=1&mc_eid=2&igshid=3&si=4"), @"https://a.test/");
        // Everything else stays, in order, with its encoding and the fragment.
        EXPECT(TweakCleanURL(@"https://a.test/p?id=7&utm_source=x&q=a%20b#top"), @"https://a.test/p?id=7&q=a%20b#top");
        EXPECT(TweakCleanURL(@"https://a.test/p?utm_term=x#sec-2"), @"https://a.test/p#sec-2");
        EXPECT(TweakCleanURL(@"http://a.test/?sid=1&size=2&utm=3"), @"http://a.test/?sid=1&size=2&utm=3");   // not tracking names
        // Nothing to remove: returned exactly as given.
        EXPECT(TweakCleanURL(@"https://a.test/p?b=2&a=1"), @"https://a.test/p?b=2&a=1");
        EXPECT(TweakCleanURL(@"https://a.test/p"), @"https://a.test/p");
        EXPECT(TweakCleanURL(@""), @"");
        // Not a web page: untouched.
        EXPECT(TweakCleanURL(@"mailto:a@b.test?subject=hi&utm_source=x"), @"mailto:a@b.test?subject=hi&utm_source=x");
        EXPECT(TweakCleanURL(@"file:///tmp/a.html?utm_source=x"), @"file:///tmp/a.html?utm_source=x");
        EXPECT(TweakCleanURL(@"not a url ?utm_source=x"), @"not a url ?utm_source=x");

        // Markdown: brackets and backslashes in titles are escaped; a ")" in a title is
        // harmless inside [...], so it stays. "(", ")" and spaces in the URL are encoded.
        EXPECT(TweakMarkdownLink(@"Title", @"https://a.test/"), @"[Title](https://a.test/)");
        EXPECT(TweakMarkdownLink(@"a [b] c", @"https://a.test/"), @"[a \\[b\\] c](https://a.test/)");
        EXPECT(TweakMarkdownLink(@"x](evil)", @"https://a.test/"), @"[x\\](evil)](https://a.test/)");
        EXPECT(TweakMarkdownLink(@"back\\slash", @"https://a.test/"), @"[back\\\\slash](https://a.test/)");
        EXPECT(TweakMarkdownLink(@"Foo (bar)", @"https://a.test/wiki/Foo_(bar)"), @"[Foo (bar)](https://a.test/wiki/Foo_%28bar%29)");
        EXPECT(TweakMarkdownLink(@"two\nlines", @"https://a.test/a b"), @"[two lines](https://a.test/a%20b)");
        EXPECT(TweakMarkdownLink(@"  ", @"https://a.test/"), @"[https://a.test/](https://a.test/)");   // empty title: the URL
    }
    return failures ? 1 : 0;
}
