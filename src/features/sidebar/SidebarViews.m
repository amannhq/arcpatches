// The sidebar's URL pill and its back/forward/reload buttons.
#import "SidebarViews.h"

static const CGFloat kSideInset = 6;    // same as the pinned tiles and tabs below it
static const CGFloat kTextInset = 12;
static const CGFloat kButtonSize = 28;
static const CGFloat kButtonGap = 2;
static const NSTimeInterval kCopiedFeedback = 1.2;

NSColor *TweakPillFill(CGFloat darkAlpha, CGFloat lightAlpha) {
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) {
        BOOL dark = [[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        return dark ? [NSColor colorWithWhite:1 alpha:darkAlpha] : [NSColor colorWithWhite:0 alpha:lightAlpha];
    }];
}

#pragma mark - URL pill

@implementation TweakSidebarURLBar

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _pill = [[NSView alloc] initWithFrame:NSZeroRect];
    _pill.wantsLayer = YES;
    _pill.layer.cornerRadius = 10;
    _pill.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_pill];

    // Arc shows the bare host: no lock or globe in front of it.
    _label = [NSTextField labelWithString:@""];
    _label.font = [NSFont systemFontOfSize:13 weight:NSFontWeightRegular];
    _label.textColor = NSColor.secondaryLabelColor;
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    _label.placeholderString = @"Search or enter URL";
    [_pill addSubview:_label];

    _linkButton = [TweakPillIconButton buttonWithSymbol:@"link" label:@"Copy Link" target:self action:@selector(copyLink:)];
    _siteButton = [TweakPillIconButton buttonWithSymbol:@"slider.horizontal.2.square" label:@"Site Controls" target:self action:@selector(siteControls:)];
    for (NSButton *b in @[_linkButton, _siteButton]) {
        b.hidden = YES;   // hidden, not transparent: an invisible button would still take the click
        [_pill addSubview:b];
    }

    [self updateAppearance];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)layout {
    [super layout];
    NSRect b = self.bounds;
    CGFloat h = TWEAK_PILL_HEIGHT;
    self.pill.frame = NSMakeRect(kSideInset, 2, NSWidth(b) - kSideInset * 2, h);
    CGFloat pad = (h - kButtonSize) / 2;
    CGFloat right = NSWidth(self.pill.frame) - pad;
    CGFloat textEnd = NSWidth(self.pill.frame) - kTextInset;
    for (NSButton *btn in @[self.siteButton, self.linkButton]) {   // right to left
        if (btn.hidden) continue;
        right -= kButtonSize;
        btn.frame = NSMakeRect(right, pad, kButtonSize, kButtonSize);
        textEnd = right - 6;
        right -= kButtonGap;
    }
    CGFloat fh = ceil(self.label.cell.cellSize.height) ?: 17;
    self.label.frame = NSMakeRect(kTextInset, round((h - fh) / 2), MAX(0, textEnd - kTextInset), fh);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

// Dia relayouts and re-parents the sidebar often, which can drop an exit event: every
// hover event (and every refresh) re-reads where the pointer really is.
- (BOOL)pointerInside {
    NSWindow *w = self.window;
    if (!w || self.isHiddenOrHasHiddenAncestor) return NO;
    NSPoint p = [self convertPoint:w.mouseLocationOutsideOfEventStream fromView:nil];
    return NSPointInRect(p, self.pill.frame);
}
- (void)syncHover {
    BOOL inside = [self pointerInside];
    if (inside == self.hovering) return;
    self.hovering = inside;
    [self updateAppearance];
}
- (void)mouseMoved:(NSEvent *)e { [self syncHover]; }
- (void)mouseEntered:(NSEvent *)e { [self syncHover]; }
- (void)mouseExited:(NSEvent *)e { [self syncHover]; }
- (void)mouseDown:(NSEvent *)e { [self openEditor]; }   // the buttons take their own clicks
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateAppearance]; }

- (void)updateAppearance {
    NSColor *bg = self.hovering ? TweakPillFill(0.11, 0.07) : TweakPillFill(0.08, 0.05);
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.pill.layer.backgroundColor = bg.CGColor;
    }];
    [self updateButtons];
}

- (void)updateButtons {
    NSString *u = self.currentURL;
    BOOL on = self.hovering && [TweakSettings boolForKey:TweakKeySidebarPillButtons];
    BOOL hasURL = u.length && ![u isEqualToString:@"about:blank"];
    BOOL copyShown = on && (hasURL || self.showingFeedback), siteShown = on && TweakSidebarURLIsSite(u);
    if (self.linkButton.hidden == copyShown || self.siteButton.hidden == siteShown) {
        self.linkButton.hidden = !copyShown;
        self.siteButton.hidden = !siteShown;
        self.needsLayout = YES;
    }
}

- (void)refresh {
    [self syncHover];
    if (self.showingFeedback) return;   // "Copied" restores itself
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
    [self updateButtons];
}

- (void)forceRefresh { if (self.showingFeedback) return; self.currentURL = nil; self.label.stringValue = @""; [self refresh]; }

- (BOOL)openEditor {
    NSRect anchor = [self.pill convertRect:self.pill.bounds toView:nil];
    if (TweakCommandBarCurrentStyle() == TweakCommandBarStyleNative) return TweakCommandBarShowEditor(self.window, anchor);
    return TweakNavBarOpenEditor(self.window, anchor);
}

#pragma mark Hover buttons

- (void)copyLink:(id)sender {
    if (!TweakSidebarCopyURL(self.window)) { NSBeep(); return; }
    NSUInteger generation = ++self.feedbackGeneration;
    self.showingFeedback = YES;
    self.label.stringValue = @"Copied";
    [(TweakPillIconButton *)self.linkButton setSymbol:@"checkmark"];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kCopiedFeedback * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TweakSidebarURLBar *bar = weakSelf;
        if (!bar || bar.feedbackGeneration != generation) return;   // a later copy owns the label now
        bar.showingFeedback = NO;
        [(TweakPillIconButton *)bar.linkButton setSymbol:@"link"];
        [bar forceRefresh];
    });
}

- (void)siteControls:(id)sender { TweakSidebarOpenSiteControls(self.window); }

@end

#pragma mark - Nav buttons

@implementation TweakNavButtons

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    NSArray *symbols = @[@"arrow.left", @"arrow.right", @"arrow.clockwise"];
    NSArray *labels = @[@"Back", @"Forward", @"Reload"];
    for (NSUInteger i = 0; i < symbols.count; i++) {
        NSButton *b = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:symbols[i] accessibilityDescription:labels[i]]
                                         target:self action:@selector(tap:)];
        b.bordered = NO;
        b.tag = i;
        b.toolTip = labels[i];
        b.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:14 weight:NSFontWeightRegular];
        b.contentTintColor = NSColor.secondaryLabelColor;
        [self addSubview:b];
    }
    return self;
}

- (void)layout {
    [super layout];
    CGFloat w = 28, x = 0;
    for (NSView *b in self.subviews) { b.frame = NSMakeRect(x, 0, w, NSHeight(self.bounds)); x += w; }
}

- (void)tap:(NSButton *)sender { TweakNavBarPerform(self.window, sender.tag); }

@end
