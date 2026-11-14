// The sidebar's URL pill and its back/forward/reload buttons.
#import "SidebarViews.h"

static const CGFloat kPillHeight = 30;
static const CGFloat kSideInset = 6;    // same as the pinned tiles and tabs below it

static NSColor *dyn(CGFloat darkWhite, CGFloat darkAlpha, CGFloat lightWhite, CGFloat lightAlpha) {
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) {
        BOOL dark = [[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        return dark ? [NSColor colorWithWhite:darkWhite alpha:darkAlpha] : [NSColor colorWithWhite:lightWhite alpha:lightAlpha];
    }];
}

#pragma mark - URL pill

@implementation TweakSidebarURLBar

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _pill = [[NSView alloc] initWithFrame:NSZeroRect];
    _pill.wantsLayer = YES;
    _pill.layer.cornerRadius = 9;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_pill];

    _icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:10 weight:NSFontWeightMedium];
    _icon.contentTintColor = NSColor.secondaryLabelColor;
    [_pill addSubview:_icon];

    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightMedium];
    _label.textColor = NSColor.labelColor;
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    _label.placeholderString = @"Search or enter URL";
    [_pill addSubview:_label];

    [self updateAppearance];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)layout {
    [super layout];
    NSRect b = self.bounds;
    self.pill.frame = NSMakeRect(kSideInset, 2, NSWidth(b) - kSideInset * 2, kPillHeight);
    self.icon.frame = NSMakeRect(9, (kPillHeight - 14) / 2, 14, 14);
    CGFloat fh = 17;
    self.label.frame = NSMakeRect(27, (kPillHeight - fh) / 2, NSWidth(self.pill.frame) - 27 - 8, fh);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseEntered:(NSEvent *)e { self.hovering = YES; [self updateAppearance]; }
- (void)mouseExited:(NSEvent *)e { self.hovering = NO; [self updateAppearance]; }
- (void)mouseDown:(NSEvent *)e { [self openEditor]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateAppearance]; }

- (void)updateAppearance {
    NSColor *bg = self.hovering ? dyn(1, 0.12, 0, 0.08) : dyn(1, 0.08, 0, 0.055);
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.pill.layer.backgroundColor = bg.CGColor;
    }];
}

- (void)refresh {
    NSString *u = TweakURLForWindow(self.window);
    if ([u isEqualToString:self.currentURL] && self.label.stringValue.length) return;
    self.currentURL = u;
    NSString *text = @"";
    if (u.length && ![u isEqualToString:@"about:blank"]) {
        NSURL *url = [NSURL URLWithString:u];
        NSString *host = url.host;
        if (TweakSettings.sidebarShowsFullURL || !host.length) text = u;
        else text = [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
        // Dev servers and local services differ only by port: "localhost:3000", not "localhost".
        if (!TweakSettings.sidebarShowsFullURL && host.length && url.port) text = [text stringByAppendingFormat:@":%@", url.port];
    }
    self.label.stringValue = text;
    NSString *symbol = !u.length ? @"magnifyingglass" : ([u hasPrefix:@"https://"] ? @"lock.fill" : @"globe");
    self.icon.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
}

- (void)forceRefresh { self.currentURL = nil; self.label.stringValue = @""; [self refresh]; }

- (BOOL)openEditor {
    if (TweakCommandBarCurrentStyle() == TweakCommandBarStyleNative) return TweakCommandBarShow(self.window, NO);
    NSRect anchor = [self.pill convertRect:self.pill.bounds toView:nil];
    return TweakNavBarOpenEditor(self.window, anchor);
}

@end

#pragma mark - Nav buttons

@implementation TweakNavButtons

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    NSArray *symbols = @[@"chevron.left", @"chevron.right", @"arrow.clockwise"];
    NSArray *labels = @[@"Back", @"Forward", @"Reload"];
    for (NSUInteger i = 0; i < symbols.count; i++) {
        NSButton *b = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:labels[i]]
                                         target:self action:@selector(tap:)];
        b.bordered = NO;
        b.tag = i;
        b.toolTip = labels[i];
        b.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:12 weight:NSFontWeightSemibold];
        b.contentTintColor = NSColor.secondaryLabelColor;
        [self addSubview:b];
    }
    return self;
}

- (void)layout {
    [super layout];
    CGFloat w = 26, x = 0;
    for (NSView *b in self.subviews) { b.frame = NSMakeRect(x, 0, w, NSHeight(self.bounds)); x += w; }
}

- (void)tap:(NSButton *)sender { TweakNavBarPerform(self.window, sender.tag); }

@end
