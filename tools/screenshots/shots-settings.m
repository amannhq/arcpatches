// Before/after stills for the website: one pair per ArcPatches setting that changes what
// you see, named <key>-on.png / <key>-off.png after the setting's defaults key (without
// "arcpatches."). Built from the same views and demo data as the README renders; each is
// a translucent panel that frame.swift puts on glass. Settings that only change Dia's own
// UI (its top bar, its editor) or nothing visible (privacy, performance, shortcuts) have
// no still: this tool renders only ArcPatches' views.
#import "shots.h"
#import "../../src/features/sidebar/SidebarViews.h"

static const CGFloat kW = ShotSidebarWidth, kRow = ShotRowHeight;

static void save(NSView *v, NSString *dir, NSString *name) { ShotWritePNG(v, [dir stringByAppendingPathComponent:name]); }

static NSView *glassCard(CGFloat w, CGFloat h) { return ShotCard(NSMakeSize(w, h), ShotGlassColor(), 0, NO); }

// A generic page: a heading and lines of text as soft bars (no real site's content).
static NSView *page(NSRect frame) {
    NSView *p = ShotCard(frame.size, [NSColor colorWithSRGBRed:0.085 green:0.09 blue:0.1 alpha:1], 0, NO);
    p.frameOrigin = frame.origin;
    CGFloat x = 28, y = 28, w = NSWidth(frame) - 56;
    NSArray *bars = @[@[@0.55, @14, @0.16], @[@0.0, @14, @0], @[@1.0, @8, @0.08], @[@0.92, @8, @0.08], @[@0.97, @8, @0.08],
                      @[@0.6, @8, @0.08], @[@0.0, @12, @0], @[@1.0, @8, @0.08], @[@0.85, @8, @0.08], @[@0.9, @8, @0.08]];
    for (NSArray *b in bars) {
        CGFloat bw = [b[0] doubleValue] * w, bh = [b[1] doubleValue];
        if (bw > 0) {
            NSView *bar = ShotCard(NSMakeSize(bw, bh), [NSColor colorWithWhite:1 alpha:[b[2] doubleValue]], bh / 2, NO);
            bar.frameOrigin = NSMakePoint(x, y);
            [p addSubview:bar];
        }
        y += bh + 10;
    }
    return p;
}

// A window crop: the sidebar on glass at the left, a page on the right.
NSView *ShotWindowCrop(CGFloat width, CGFloat height, NSView **sidebarOut, NSView **pageOut) {
    NSView *win = ShotCard(NSMakeSize(width, height), NSColor.clearColor, 0, NO);
    NSView *side = glassCard(kW, height);
    [win addSubview:side];
    NSView *pg = page(NSMakeRect(kW, 0, width - kW, height));
    [win addSubview:pg];
    if (sidebarOut) *sidebarOut = side;
    if (pageOut) *pageOut = pg;
    return win;
}

static NSView *topRowCard(ShotTopRowOptions o) {
    NSView *card = glassCard(kW, kRow + 8);
    ShotAddTopRow(card, 4, o);
    return card;
}

static NSView *pillCard(ShotPillState s, NSString *label, BOOL buttons) {
    NSView *card = glassCard(kW, kRow + 8);
    [card addSubview:ShotPill(s, 4, label, buttons)];
    return card;
}

// Dia's own bar at the top of the page, as a generic stand-in: back, forward, reload, a field.
static void addGenericTopBar(NSView *pg) {
    CGFloat h = 40, w = NSWidth(pg.bounds);
    NSView *bar = ShotCard(NSMakeSize(w, h), [NSColor colorWithSRGBRed:0.13 green:0.135 blue:0.145 alpha:1], 0, NO);
    CGFloat x = 10;
    for (NSString *sym in @[@"arrow.left", @"arrow.right", @"arrow.clockwise"]) {
        NSImageView *i = [NSImageView imageViewWithImage:ArcSymbol(sym, 13, NSFontWeightRegular, nil)];
        i.contentTintColor = ArcIconColor(YES);
        i.frame = NSMakeRect(x, 11, 18, 18);
        [bar addSubview:i];
        x += 28;
    }
    NSView *field = ShotCard(NSMakeSize(w - x - 12, 26), ArcFillColor(ArcFillRest), 7, NO);
    field.frameOrigin = NSMakePoint(x + 4, 7);
    NSTextField *t = [NSTextField labelWithString:@"nextjs.org/docs"];
    t.font = ArcFontURL(); t.textColor = NSColor.labelColor;
    [t sizeToFit];
    t.frameOrigin = NSMakePoint(10, round((26 - NSHeight(t.frame)) / 2));
    [field addSubview:t];
    [bar addSubview:field];
    for (NSView *v in pg.subviews) v.frameOrigin = NSMakePoint(NSMinX(v.frame), NSMinY(v.frame) + h);
    [pg addSubview:bar];
}

// The URL bar in the sidebar (ArcPatches) or at the top (Dia's bar).
static NSView *urlBarMode(BOOL sidebar) {
    NSView *side, *pg;
    NSView *win = ShotWindowCrop(560, 196, &side, &pg);
    ShotTopRowOptions o = ShotTopRowDefault;
    o.nav = sidebar;   // in top mode, back, forward and reload are in Dia's bar
    ShotAddTopRow(side, 4, o);
    CGFloat y = kRow + 8;
    if (sidebar) { [side addSubview:ShotPill(ShotPillRest, y, nil, YES)]; y += kRow + 10; }
    else { addGenericTopBar(pg); y += 6; }
    ShotAddFavourites(side, y);
    return win;
}

// ⌘L with the sidebar URL bar: the editor opens over the pill, its top-left on the pill's.
static NSView *editorAtPill(void) {
    NSView *side;
    NSView *win = ShotWindowCrop(560, 340, &side, NULL);
    ShotAddTopRow(side, 4, ShotTopRowDefault);
    [side addSubview:ShotPill(ShotPillRest, kRow + 8, nil, YES)];
    ShotAddFavourites(side, kRow * 2 + 18);
    NSView *ed = ShotEditor();
    ed.frameOrigin = NSMakePoint(ArcSidebarInset, kRow + 8 + 2);
    // Over other UI the real panel is near-opaque (ArcPanelTint over its blur), so the sidebar under it doesn't show through.
    NSView *back = ShotCard(ed.frame.size, ArcPanelTint(), ArcRadiusPopover, YES);
    back.frameOrigin = ed.frame.origin;
    [win addSubview:back];
    [win addSubview:ed];
    return win;
}

// Full screen: with the setting on, the top row starts with the toggle, and the window
// buttons come with the title strip that slides down over the window's top edge
// (`stripOffset` -ArcFullScreenStripHeight is hidden, 0 is shown).
NSView *ShotFullScreenRow(BOOL hideButtons, CGFloat stripOffset) {
    CGFloat strip = ArcFullScreenStripHeight;
    NSView *card = glassCard(kW, 2 * kRow + 12);
    ShotTopRowOptions o = ShotTopRowDefault;
    o.lights = !hideButtons;
    ShotAddTopRow(card, 4, o);
    [card addSubview:ShotPill(ShotPillRest, kRow + 6, nil, YES)];
    if (hideButtons && stripOffset > -strip) {
        NSView *s = ShotCard(NSMakeSize(kW, strip), [NSColor colorWithSRGBRed:0.17 green:0.175 blue:0.185 alpha:0.96], 0, NO);
        s.frameOrigin = NSMakePoint(0, stripOffset);
        ShotAddWindowButtons(s, ArcFullScreenStripInset, strip / 2, ArcFullScreenStripSpacing, NO);
        NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(0, strip - 1, kW, 1)];
        line.boxType = NSBoxCustom; line.borderWidth = 0; line.fillColor = ArcHairline();
        [s addSubview:line];
        [card addSubview:s];
    }
    return card;
}

void ShotSettings(NSString *dir) {
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    save(urlBarMode(YES), dir, @"urlBarMode-on.png");
    save(urlBarMode(NO), dir, @"urlBarMode-off.png");

    save(pillCard(ShotPillHover, nil, YES), dir, @"sidebarPillButtons-on.png");
    save(pillCard(ShotPillHover, nil, NO), dir, @"sidebarPillButtons-off.png");
    save(pillCard(ShotPillRest, @"https://nextjs.org/docs/app/getting-started", YES), dir, @"sidebarShowsFullURL-on.png");
    save(pillCard(ShotPillRest, nil, YES), dir, @"sidebarShowsFullURL-off.png");
    save(pillCard(ShotPillEmpty, nil, YES), dir, @"empty-state.png");

    ShotTopRowOptions o = ShotTopRowDefault;
    save(topRowCard(o), dir, @"sidebarShowsNavButtons-on.png");
    o.nav = NO; save(topRowCard(o), dir, @"sidebarShowsNavButtons-off.png");
    o = ShotTopRowDefault;
    save(topRowCard(o), dir, @"sidebarToggleButton-on.png");
    o.toggle = NO; save(topRowCard(o), dir, @"sidebarToggleButton-off.png");
    o = ShotTopRowDefault;
    o.profile = YES; save(topRowCard(o), dir, @"topRowProfileName-on.png");
    o.profile = NO; save(topRowCard(o), dir, @"topRowProfileName-off.png");

    save(ShotFullScreenRow(YES, -ArcFullScreenStripHeight), dir, @"hideWindowButtonsInFullScreen-on.png");
    save(ShotFullScreenRow(YES, 0), dir, @"hideWindowButtonsInFullScreen-on-strip.png");   // pointer at the top edge
    save(ShotFullScreenRow(NO, 0), dir, @"hideWindowButtonsInFullScreen-off.png");

    save(ShotPalette(0, 6), dir, @"commandBarStyle-on.png");
    save(editorAtPill(), dir, @"cmdLFocusesSidebar-on.png");
}
