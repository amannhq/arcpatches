// Dev tool: renders README screenshots of ArcPatches' own UI from the real view code,
// offscreen, in dark mode at 2x, with demo content: public sites and their favicons, no
// personal data, no browser running. The site-controls data source is replaced by demo
// data (shots-data.m), so nothing is read from a browser profile. Panels are drawn with
// translucent fills; frame.swift puts them on glass over its backdrop.
//
// From the repo root (fetch-icons.sh downloads favicons into build/shot-icons, git-ignored;
// without them the icons fall back to letter tiles):
//   tools/screenshots/fetch-icons.sh
//   mkdir -p build && clang -fobjc-arc -framework AppKit -framework QuartzCore -lsqlite3 -Isrc/core -Isrc/browsers/dia \
//     tools/screenshots/shots*.m $(find src -name '*.m' ! -name ArcPatches.m ! -name SiteControlsData.m) \
//     -o build/shots && build/shots build/shots-raw
//   swiftc -O -parse-as-library tools/screenshots/frame.swift tools/screenshots/backdrop.swift -o build/frame \
//     && build/frame build/shots-raw docs/screenshots
//
// Raw output: palette.png, editor.png, settings.png, plus shots-sidebar.m's renders.
#import "shots.h"
#import "../../src/features/commandbar/CommandBarInternal.h"

static NSColor *rgb(CGFloat r, CGFloat g, CGFloat b) { return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1]; }

NSImage *ShotLetterIcon(NSString *letter, NSInteger color, CGFloat size) {
    NSArray<NSColor *> *colors = @[rgb(0.36, 0.47, 0.98), rgb(0.95, 0.55, 0.25), rgb(0.20, 0.70, 0.55), rgb(0.85, 0.33, 0.45),
                                   rgb(0.58, 0.42, 0.90), rgb(0.25, 0.62, 0.90), rgb(0.90, 0.72, 0.20), rgb(0.45, 0.50, 0.58)];
    NSColor *fill = colors[color % colors.count];
    return [NSImage imageWithSize:NSMakeSize(size, size) flipped:NO drawingHandler:^BOOL(NSRect r) {
        [fill setFill];
        [[NSBezierPath bezierPathWithRoundedRect:r xRadius:size / 4 yRadius:size / 4] fill];
        NSDictionary *a = @{NSFontAttributeName: [NSFont systemFontOfSize:size * 0.6 weight:NSFontWeightBold],
                            NSForegroundColorAttributeName: NSColor.whiteColor};
        NSSize s = [letter sizeWithAttributes:a];
        [letter drawAtPoint:NSMakePoint(NSMidX(r) - s.width / 2, NSMidY(r) - s.height / 2) withAttributes:a];
        return YES;
    }];
}

// Mostly-dark favicons (GitHub, Next.js) vanish on dark glass: like a browser, give them a light backing.
static BOOL isDark(NSImage *img) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:16 pixelsHigh:16 bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [img drawInRect:NSMakeRect(0, 0, 16, 16)];
    [NSGraphicsContext restoreGraphicsState];
    CGFloat lum = 0, weight = 0;
    for (NSInteger y = 0; y < 16; y++) for (NSInteger x = 0; x < 16; x++) {
        NSColor *c = [[rep colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        lum += (0.3 * c.redComponent + 0.59 * c.greenComponent + 0.11 * c.blueComponent) * c.alphaComponent;
        weight += c.alphaComponent;
    }
    return weight > 0 && lum / weight < 0.22;
}

NSImage *ShotSiteIcon(NSString *domain, CGFloat size) {
    NSString *path = [NSString stringWithFormat:@"build/shot-icons/%@.png", domain];
    NSImage *fav = [[NSImage alloc] initWithContentsOfFile:path];
    if (!fav) return ShotLetterIcon([domain substringToIndex:1].uppercaseString, (NSInteger)(domain.length % 8), size);
    BOOL backing = isDark(fav);
    return [NSImage imageWithSize:NSMakeSize(size, size) flipped:NO drawingHandler:^BOOL(NSRect r) {
        NSRect inner = r;
        NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect:r xRadius:size / 4 yRadius:size / 4];
        [tile addClip];   // square favicons with their own backgrounds get the same soft corners
        if (backing) {
            [[NSColor colorWithWhite:0.96 alpha:1] setFill];
            [tile fill];
            inner = NSInsetRect(r, size * 0.14, size * 0.14);
        }
        NSGraphicsContext.currentContext.imageInterpolation = NSImageInterpolationHigh;
        [fav drawInRect:inner];
        return YES;
    }];
}

NSString *ShotHost(NSString *url) {
    NSString *host = [NSURL URLWithString:url].host;
    return [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
}

NSColor *ShotGlassColor(void) { return [NSColor colorWithSRGBRed:0.07 green:0.08 blue:0.09 alpha:0.62]; }

void ShotWritePNG(NSView *v, NSString *path) {
    [v layoutSubtreeIfNeeded];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:(NSInteger)NSWidth(v.bounds) * 2 pixelsHigh:(NSInteger)NSHeight(v.bounds) * 2 bitsPerSample:8 samplesPerPixel:4
        hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    rep.size = v.bounds.size;
    [v cacheDisplayInRect:v.bounds toBitmapImageRep:rep];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

@interface ShotCardView : NSView
@property (nonatomic, strong) NSColor *fill;
@property (nonatomic) CGFloat radius;
@property (nonatomic) BOOL border;
@end
@implementation ShotCardView
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r {
    NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 0.5, 0.5) xRadius:self.radius yRadius:self.radius];
    [self.fill setFill]; [p fill];
    if (!self.border) return;
    [ArcPanelBorder() setStroke]; p.lineWidth = 1; [p stroke];
}
@end

NSView *ShotCard(NSSize size, NSColor *fill, CGFloat radius, BOOL border) {
    ShotCardView *v = [[ShotCardView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
    v.fill = fill; v.radius = radius; v.border = border;
    v.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    return v;
}

#pragma mark - Command bar (⌘T palette, ⌘L editor)

@interface DemoDelegate : NSObject <TweakResultsViewDelegate>
@end
@implementation DemoDelegate
- (NSImage *)iconForItem:(TweakItem *)item {
    return [item.url hasPrefix:@"https://"] ? ShotSiteIcon(ShotHost(item.url), ArcFaviconSize) : nil;
}
- (void)resultsView:(TweakResultsView *)v activate:(NSInteger)row {}
@end

static TweakItem *item(TweakItemKind kind, NSString *title, NSString *detail, NSString *url, NSString *symbol) {
    TweakItem *i = [TweakItem new];
    i.kind = kind; i.title = title; i.detail = detail; i.url = url; i.symbol = symbol;
    return i;
}

// The command bar's panel, laid out as CommandBarLayout.m's -layoutForRows: does.
// `typed` is what was typed; `selected` follows it, shown with the field's selection colour.
static NSView *commandBar(BOOL editor, CGFloat width, NSString *typed, NSString *selected, NSImage *icon, NSArray *items) {
    static DemoDelegate *del;
    del = [DemoDelegate new];
    TweakBarMetrics m = TweakBarMetricsFor(editor);
    NSUInteger n = items.count;
    CGFloat listH = n ? 2 * m.listInset + n * m.rowHeight + (n - 1) * m.rowGap : 0;
    CGFloat line = n && !editor ? 0.5 : 0;   // a hairline at 2x
    CGFloat height = m.inputHeight + line + listH, mid = m.inputHeight / 2;   // flipped: the field row on top
    NSView *panel = ShotCard(NSMakeSize(width, height), ShotGlassColor(), ArcRadiusPopover, NO);

    CGFloat iconX = editor ? ArcSpace3 : ArcPaletteSearchInset;
    NSImageView *fieldIcon = [NSImageView imageViewWithImage:icon ?: ArcSymbol(@"magnifyingglass", ArcPaletteSearchIcon, NSFontWeightRegular, nil)];
    fieldIcon.imageScaling = NSImageScaleProportionallyDown;
    fieldIcon.contentTintColor = ArcIconColor(YES);
    fieldIcon.frame = NSMakeRect(iconX, round(mid - ArcFaviconSize / 2), ArcFaviconSize, ArcFaviconSize);
    [panel addSubview:fieldIcon];

    NSFont *font = editor ? ArcFontURL() : ArcFontPaletteField();
    CGFloat fieldH = ceil(font.ascender - font.descender + font.leading) + ArcSpace1 / 2;
    CGFloat fieldX = NSMaxX(fieldIcon.frame) + (editor ? ArcSpace2 : ArcSpace3);
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:typed
        attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.labelColor}];
    [text appendAttributedString:[[NSAttributedString alloc] initWithString:selected ?: @"" attributes:@{
        NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.labelColor, NSBackgroundColorAttributeName: ArcTextSelection()}]];
    NSTextField *field = [NSTextField labelWithAttributedString:text];
    field.frame = NSMakeRect(fieldX, round(mid - fieldH / 2), width - fieldX - iconX, fieldH);
    [panel addSubview:field];

    if (line) {
        NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(0, m.inputHeight, width, line)];
        divider.boxType = NSBoxCustom; divider.borderWidth = 0; divider.fillColor = ArcHairline();
        [panel addSubview:divider];
    }
    TweakResultsView *results = [[TweakResultsView alloc] initWithFrame:NSMakeRect(0, m.inputHeight + line, width, listH)];
    results.metrics = m;
    results.delegate = del;
    results.items = items;   // the first row is highlighted, as when the bar opens
    [panel addSubview:results];
    return panel;
}

static void palette(NSString *dir) {
    NSArray *items = @[
        item(TweakItemTab, @"Next.js Docs", @"Switch to Tab", @"https://nextjs.org/docs", @"square.on.square"),
        item(TweakItemHistory, @"vercel/next.js", nil, @"https://github.com/vercel/next.js", @"globe"),
        item(TweakItemSearch, @"next", @"Search Google", nil, @"magnifyingglass"),
        item(TweakItemCommand, @"Duplicate Tab", @"⇧⌘D", nil, @"plus.square.on.square"),
        item(TweakItemPage, @"Downloads", nil, @"chrome://downloads", @"arrow.down.circle"),
        item(TweakItemHistory, @"Next steps", nil, @"https://developer.apple.com/tutorials/swiftui", @"globe"),
    ];
    NSView *bar = commandBar(NO, 640, @"next", @"js.org", nil, items);
    ShotWritePNG(bar, [dir stringByAppendingPathComponent:@"palette.png"]);
}

static void editor(NSString *dir) {
    NSArray *items = @[
        item(TweakItemHistory, @"Next.js Docs", nil, @"https://nextjs.org/docs", @"globe"),
        item(TweakItemHistory, @"nextjs.org", nil, @"https://nextjs.org/", @"globe"),
        item(TweakItemTab, @"Layouts and Pages", @"Switch to Tab", @"https://nextjs.org/docs/app/getting-started/layouts-and-pages", @"square.on.square"),
        item(TweakItemHistory, @"Installation", nil, @"https://nextjs.org/docs/app/getting-started/installation", @"globe"),
        item(TweakItemHistory, @"Next.js Blog", nil, @"https://nextjs.org/blog", @"globe"),
    ];
    CGFloat width = MIN(ArcEditorMaxWidth, MAX(ArcEditorMinWidth, 240 * ArcEditorWidthRatio));   // from a 240-pt sidebar
    NSView *bar = commandBar(YES, width, @"", @"https://nextjs.org/docs", ShotSiteIcon(@"nextjs.org", ArcFaviconSize), items);
    ShotWritePNG(bar, [dir stringByAppendingPathComponent:@"editor.png"]);
}

#pragma mark - Settings pane

static void settings(NSString *dir) {
    NSView *pane = [[NSClassFromString(@"TweakPrefsPane") alloc] initWithFrame:NSMakeRect(0, 0, 600, 1080)];
    NSView *crop = ShotCard(NSMakeSize(600, 708), [NSColor colorWithSRGBRed:0.12 green:0.12 blue:0.13 alpha:1], 0, NO);
    pane.appearance = crop.appearance;
    [crop addSubview:pane];
    [pane layoutSubtreeIfNeeded];
    // Keep the first groups: the crop is flipped, so the pane's top is at y = 0.
    pane.frame = NSMakeRect(0, 0, 600, 1080);
    ShotWritePNG(crop, [dir stringByAppendingPathComponent:@"settings.png"]);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        NSString *dir = argc > 1 ? @(argv[1]) : @".";
        [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [NSApp.appearance performAsCurrentDrawingAppearance:^{
            palette(dir);
            editor(dir);
            settings(dir);
            ShotSidebar(dir);
            ShotSiteControls(dir);
        }];
        printf("wrote renders to %s\n", dir.UTF8String);
    }
    return 0;
}
