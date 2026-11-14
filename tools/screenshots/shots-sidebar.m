// README renders of the sidebar chrome: the top row, the URL pill in its three states,
// the site controls popover, and a whole demo sidebar built around them.
#import "shots.h"
#import "../../src/features/sidebar/SiteControlsInternal.h"

static const CGFloat kWidth = 240;   // a typical sidebar
static const CGFloat kRowH = 40;     // the top row
static const CGFloat kPillRowH = 40; // TweakSidebarURLBar: the pill plus a little room

// TweakSidebarToggleButton is declared in TopRow.m only.
@interface NSButton (ShotToggle)
+ (instancetype)toggle;
@end

// Private to SiteControlsPopover.m.
@interface TweakSiteControls (ShotBuild)
- (void)build;
@end

NSColor *ShotSidebarColor(void) { return [NSColor colorWithSRGBRed:0.135 green:0.135 blue:0.145 alpha:1]; }

static NSView *sidebarCard(CGFloat height) { return ShotCard(NSMakeSize(kWidth, height), ShotSidebarColor(), 0, NO); }

#pragma mark - Top row

static void addTopRow(NSView *parent, CGFloat y) {
    // Window buttons: plain macOS circles, where the system draws them.
    NSArray *colors = @[[NSColor colorWithSRGBRed:1 green:0.37 blue:0.34 alpha:1], [NSColor colorWithSRGBRed:1 green:0.74 blue:0.18 alpha:1],
                        [NSColor colorWithSRGBRed:0.16 green:0.79 blue:0.25 alpha:1]];
    for (NSUInteger i = 0; i < colors.count; i++) {
        NSBox *dot = [[NSBox alloc] initWithFrame:NSMakeRect(14 + i * 20, y + kRowH / 2 - 6, 12, 12)];
        dot.boxType = NSBoxCustom; dot.borderWidth = 0; dot.cornerRadius = 6; dot.fillColor = colors[i];
        [parent addSubview:dot];
    }
    NSButton *toggle = [NSClassFromString(@"TweakSidebarToggleButton") toggle];
    toggle.frame = NSMakeRect(70 + 1, y + (kRowH - TweakChromeTopRowSize) / 2, TweakChromeTopRowSize, TweakChromeTopRowSize);
    [parent addSubview:toggle];

    CGFloat w = 3 * TweakChromeTopRowSize;   // placed as Sidebar.m does: trailing, 8 from the edge
    TweakNavButtons *nav = [[TweakNavButtons alloc] initWithFrame:NSMakeRect(kWidth - w - 8, y + (kRowH - TweakChromeTopRowSize) / 2, w, TweakChromeTopRowSize)];
    [parent addSubview:nav];
    [nav layoutSubtreeIfNeeded];
    ((NSButton *)nav.subviews[1]).enabled = NO;   // no forward history: dimmed, still in place
}

#pragma mark - URL pill

typedef NS_ENUM(NSInteger, ShotPillState) { ShotPillRest, ShotPillHover, ShotPillEmpty };

static TweakSidebarURLBar *pill(ShotPillState state, CGFloat y) {
    TweakSidebarURLBar *bar = [[TweakSidebarURLBar alloc] initWithFrame:NSMakeRect(0, y, kWidth, kPillRowH)];
    bar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    // Set directly: -refresh would ask a browser window for its URL.
    if (state != ShotPillEmpty) {
        bar.currentURL = @"https://example.com/";
        bar.label.stringValue = @"example.com";
    }
    bar.hovering = state == ShotPillHover;
    [bar updateAppearance:NO];
    for (NSButton *b in @[bar.linkButton, bar.siteButton]) {   // finish the hover fade now
        BOOL shown = state == ShotPillHover;
        b.hidden = !shown;
        b.alphaValue = shown ? 1 : 0;
    }
    bar.needsLayout = YES;
    [bar layoutSubtreeIfNeeded];
    return bar;
}

#pragma mark - Favourites and tabs

static void addFavourites(NSView *parent, CGFloat y) {
    NSArray *letters = @[@"I", @"C", @"D", @"N", @"M", @"P", @"S", @"W"];
    CGFloat inset = ArcSidebarInset, gap = ArcSpace2, h = 44;
    CGFloat w = (kWidth - 2 * inset - 3 * gap) / 4;
    for (NSUInteger i = 0; i < letters.count; i++) {
        NSView *tile = ShotCard(NSMakeSize(w, h), ArcFillColor(ArcFillTile), ArcRadiusPill, NO);
        tile.frameOrigin = NSMakePoint(inset + (i % 4) * (w + gap), y + (i / 4) * (h + gap));
        NSImageView *icon = [NSImageView imageViewWithImage:ShotLetterIcon(letters[i], (NSInteger)i, 20)];
        icon.frame = NSMakeRect(round((w - 20) / 2), round((h - 20) / 2), 20, 20);
        [tile addSubview:icon];
        [parent addSubview:tile];
    }
}

static CGFloat addTabs(NSView *parent, CGFloat y) {
    NSArray *tabs = @[@[@"I", @0, @"Inbox"], @[@"C", @1, @"Calendar"], @[@"D", @2, @"Getting started"],
                      @[@"E", @4, @"Design review notes"], @[@"D", @2, @"Changelog"]];
    CGFloat h = 34;
    for (NSUInteger i = 0; i <= tabs.count; i++) {
        BOOL newTab = i == tabs.count, selected = i == 2;
        NSView *row = ShotCard(NSMakeSize(kWidth - 2 * ArcSidebarInset, h), selected ? ArcFillColor(ArcFillSelected) : NSColor.clearColor, ArcRadiusMedium, NO);
        row.frameOrigin = NSMakePoint(ArcSidebarInset, y);
        NSImage *img = newTab ? ArcSymbol(@"plus", ArcPillIcon, NSFontWeightMedium, nil) : ShotLetterIcon(tabs[i][0], [tabs[i][1] integerValue], 16);
        NSImageView *icon = [NSImageView imageViewWithImage:img];
        icon.contentTintColor = ArcIconColor(YES);
        icon.frame = NSMakeRect(ArcSpace3 - 2, round((h - 16) / 2), 16, 16);
        [row addSubview:icon];
        NSTextField *title = [NSTextField labelWithString:newTab ? @"New Tab" : tabs[i][2]];
        title.font = ArcFontRowTitle();
        title.textColor = newTab ? ArcTextSecondary() : NSColor.labelColor;
        [title sizeToFit];
        title.frameOrigin = NSMakePoint(ArcSpace3 + 16 + ArcSpace2 - 2, round((h - NSHeight(title.frame)) / 2));
        [row addSubview:title];
        [parent addSubview:row];
        y += h + 2;
    }
    return y;
}

#pragma mark - Renders

void ShotSidebar(NSString *dir) {
    NSView *top = sidebarCard(kRowH);
    addTopRow(top, 0);
    ShotWritePNG(top, [dir stringByAppendingPathComponent:@"toprow.png"]);

    NSArray *names = @[@"pill-rest.png", @"pill-hover.png", @"pill-empty.png"];
    for (ShotPillState s = ShotPillRest; s <= ShotPillEmpty; s++) {
        NSView *card = sidebarCard(kPillRowH);
        [card addSubview:pill(s, 0)];
        ShotWritePNG(card, [dir stringByAppendingPathComponent:names[s]]);
    }

    // The whole sidebar: top row, the pill under the pointer, favourites, then tabs.
    NSView *sidebar = sidebarCard(460);
    CGFloat y = 6;
    addTopRow(sidebar, y);
    y += kRowH + 4;
    [sidebar addSubview:pill(ShotPillHover, y)];
    y += kPillRowH + 10;
    addFavourites(sidebar, y);
    y += 2 * 44 + ArcSpace2 + 14;
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(ArcSidebarInset + 6, y, kWidth - 2 * (ArcSidebarInset + 6), 1)];
    line.boxType = NSBoxCustom; line.borderWidth = 0; line.fillColor = ArcHairline();
    [sidebar addSubview:line];
    y = addTabs(sidebar, y + 10) + 8;
    sidebar.frameSize = NSMakeSize(kWidth, y);
    ShotWritePNG(sidebar, [dir stringByAppendingPathComponent:@"sidebar.png"]);
}

// Dia's screenshot command, as the popover looks for it in the main menu.
@interface ShotMenuTarget : NSObject
@end
@implementation ShotMenuTarget
- (void)takeScreenshot:(id)sender {}
@end

void ShotSiteControls(NSString *dir) {
    static ShotMenuTarget *target;
    target = [ShotMenuTarget new];
    NSMenu *main = [NSMenu new], *file = [[NSMenu alloc] initWithTitle:@"File"];
    NSMenuItem *shot = [file addItemWithTitle:@"Take Screenshot" action:@selector(takeScreenshot:) keyEquivalent:@""];
    shot.target = target;
    [main addItemWithTitle:@"File" action:nil keyEquivalent:@""].submenu = file;
    NSApp.mainMenu = main;

    TweakSiteControls *c = [TweakSiteControls new];
    c.url = @"https://example.com/";
    c.extensions = TweakSiteExtensions(nil);
    NSView *content = c.view;
    content.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [c build];
    NSView *card = ShotCard(content.frame.size, [NSColor colorWithSRGBRed:0.16 green:0.16 blue:0.17 alpha:1], ArcRadiusPopover, YES);
    [card addSubview:content];
    ShotWritePNG(card, [dir stringByAppendingPathComponent:@"site-controls.png"]);
}
