// The sidebar's URL pill and its back/forward/reload buttons.
#import "SidebarViews.h"
#import "NavBarInternal.h"
#import "Browser.h"

static const CGFloat kSideInset = ArcSidebarInset;   // same as the pinned tiles and tabs below it
static const CGFloat kTextInset = ArcSpace3;
static const CGFloat kButtonSize = ArcPillButton;
static const CGFloat kButtonGap = 2;
static const NSTimeInterval kLoadingRecheck = 0.5;

#pragma mark - URL pill

@interface TweakSidebarURLBar ()
@property (nonatomic) BOOL copyWanted, siteWanted;   // target state: layout follows it, not the fade
@end

@implementation TweakSidebarURLBar

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _pill = [[NSView alloc] initWithFrame:NSZeroRect];
    _pill.wantsLayer = YES;
    ArcRound(_pill.layer, ArcRadiusPill);
    [self addSubview:_pill];

    // Arc shows the bare host: no lock or globe in front of it.
    _label = [NSTextField labelWithString:@""];
    _label.font = ArcFontURL();
    _label.textColor = ArcTextSecondary();
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    _label.placeholderString = @"Search or Enter URL…";   // Arc's empty-state wording
    _label.wantsLayer = YES;   // for the "Copied" crossfade
    [_pill addSubview:_label];

    // Arc's empty state: a magnifying glass before the placeholder when no page is open.
    _searchIcon = [NSImageView imageViewWithImage:ArcSymbol(@"magnifyingglass", ArcPillIcon, NSFontWeightMedium, @"Search")];
    _searchIcon.contentTintColor = ArcTextSecondary();
    _searchIcon.hidden = YES;
    [_pill addSubview:_searchIcon];

    _linkButton = [TweakPillIconButton buttonWithSymbol:@"link" label:@"Copy Link" target:self action:@selector(copyLink:)];
    _siteButton = [TweakPillIconButton buttonWithSymbol:@"slider.horizontal.2.square" label:@"Site Controls" target:self action:@selector(siteControls:)];
    for (NSButton *b in @[_linkButton, _siteButton]) {
        b.hidden = YES;   // hidden, not transparent: an invisible button would still take the click
        b.alphaValue = 0;
        [_pill addSubview:b];
    }

    [self updateAppearance:NO];
    TweakSidebarPillRegister(self);
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)layout {
    [super layout];
    NSRect b = self.bounds;
    CGFloat h = ArcPillHeight;
    self.pill.frame = NSMakeRect(kSideInset, 2, NSWidth(b) - kSideInset * 2, h);
    CGFloat pad = (h - kButtonSize) / 2;
    CGFloat right = NSWidth(self.pill.frame) - pad;
    CGFloat textEnd = NSWidth(self.pill.frame) - kTextInset;
    BOOL wanted[] = {self.siteWanted, self.copyWanted};
    NSArray *buttons = @[self.siteButton, self.linkButton];   // right to left
    for (NSUInteger i = 0; i < buttons.count; i++) {
        if (!wanted[i]) continue;   // a fading-out button keeps its last frame
        right -= kButtonSize;
        [buttons[i] setFrame:NSMakeRect(right, pad, kButtonSize, kButtonSize)];
        textEnd = right - 6;
        right -= kButtonGap;
    }
    CGFloat fh = ceil(self.label.cell.cellSize.height) ?: 17;
    BOOL empty = !self.label.stringValue.length && !self.showingFeedback;
    if (self.searchIcon.hidden == empty) self.searchIcon.hidden = !empty;
    CGFloat textX = kTextInset;
    if (empty) {
        NSSize s = self.searchIcon.intrinsicContentSize;
        self.searchIcon.frame = NSMakeRect(kTextInset, round((h - s.height) / 2), s.width, s.height);
        textX = kTextInset + s.width + ArcSpace2;
    }
    self.label.frame = NSMakeRect(textX, round((h - fh) / 2), MAX(0, textEnd - textX), fh);
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
    [self updateAppearance:YES];
}
- (void)mouseMoved:(NSEvent *)e { [self syncHover]; }
- (void)mouseEntered:(NSEvent *)e { [self syncHover]; }
- (void)mouseExited:(NSEvent *)e { [self syncHover]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateAppearance:NO]; }

// Hovered, or its site-controls popover is open (the pointer is in the popover then).
- (BOOL)active { return self.hovering || self.siteButton.selected; }

- (void)updateAppearance:(BOOL)animated {
    TweakChromeSetFill(self, self.pill.layer, ArcFillColor(self.active ? ArcFillHover : ArcFillRest), animated);
    [self updateButtons];
}

- (void)updateButtons {
    NSString *u = self.currentURL;
    BOOL on = self.active && [TweakSettings boolForKey:TweakKeySidebarPillButtons];
    BOOL hasURL = u.length && ![u isEqualToString:@"about:blank"];
    BOOL copyShown = on && (hasURL || self.showingFeedback), siteShown = on && TweakSidebarURLIsSite(u);
    if (copyShown == self.copyWanted && siteShown == self.siteWanted) return;
    BOOL copyChanged = copyShown != self.copyWanted, siteChanged = siteShown != self.siteWanted;
    self.copyWanted = copyShown;
    self.siteWanted = siteShown;
    // Place the appearing buttons (and truncate the label) before they fade in.
    [self layout];   // frames only; safe even when a refresh comes from a layout pass
    if (copyChanged) TweakChromeFade(self.linkButton, copyShown);
    if (siteChanged) TweakChromeFade(self.siteButton, siteShown);
}

- (void)refresh {
    [self syncHover];
    [TweakNavButtons scheduleRefresh];
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
    if (!text.length != !self.label.stringValue.length) self.needsLayout = YES;   // empty state on/off
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

- (void)siteControls:(id)sender { TweakSidebarOpenSiteControls(sender); }

@end

#pragma mark - Nav buttons

static NSHashTable<TweakNavButtons *> *gNavButtons;
static BOOL gNavRefreshPending;

@interface TweakNavButtons ()
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL recheckPending;
@end

@implementation TweakNavButtons

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    NSArray *symbols = @[@"arrow.left", @"arrow.right", @"arrow.clockwise"];
    NSArray *labels = @[@"Back", @"Forward", @"Reload"];
    for (NSUInteger i = 0; i < symbols.count; i++) {
        TweakChromeButton *b = [TweakChromeButton buttonWithSymbol:symbols[i] label:labels[i] pointSize:ArcTopRowIcon
                                                            radius:ArcRadiusMedium target:self action:@selector(tap:)];
        b.tag = i;
        [self addSubview:b];
    }
    if (!gNavButtons) gNavButtons = [NSHashTable weakObjectsHashTable];
    [gNavButtons addObject:self];
    return self;
}

- (void)layout {
    [super layout];
    CGFloat s = ArcTopRowButton, x = 0, y = round((NSHeight(self.bounds) - s) / 2);
    for (NSView *b in self.subviews) { b.frame = NSMakeRect(x, y, s, s); x += s; }
}

- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [TweakNavButtons scheduleRefresh]; }

// Coalesced and outside any layout pass: the URL pill's refresh (title changes, window
// focus, the 3s timer) asks for it, often several times in a row.
+ (void)scheduleRefresh {
    if (gNavRefreshPending) return;
    gNavRefreshPending = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        gNavRefreshPending = NO;
        for (TweakNavButtons *nav in gNavButtons.allObjects) [nav updateState];
    });
}

- (void)updateState {
    if (!self.window || self.isHiddenOrHasHiddenAncestor) return;
    TweakNavState s = TweakNavBarState(self.window);
    NSArray<TweakChromeButton *> *b = self.subviews;
    if (b.count < 3) return;
    b[0].enabled = s.canGoBack;   // no-ops when unchanged
    b[1].enabled = s.canGoForward;
    if (s.loading != self.loading) {
        self.loading = s.loading;
        [b[2] setLabel:s.loading ? @"Stop" : @"Reload"];
        [b[2] setSymbol:s.loading ? @"xmark" : @"arrow.clockwise" animated:YES];
    }
    // Loading ends without a title change often enough: look again shortly.
    if (s.loading && !self.recheckPending) {
        self.recheckPending = YES;
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kLoadingRecheck * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            weakSelf.recheckPending = NO;
            [weakSelf updateState];
        });
    }
}

// While loading, Dia's own reload control (which TweakNavBarPerform presses) stops.
// ⌘-click or middle-click on reload duplicates the tab, as in Arc. Back and forward have no
// "in a new tab" here: Dia exposes no tab's history (nor a menu command for it), so they
// navigate in place.
- (void)tap:(NSButton *)sender {
    NSEvent *e = NSApp.currentEvent;
    BOOL newTab = e.type == NSEventTypeOtherMouseUp || (e.modifierFlags & NSEventModifierFlagCommand);
    if (newTab && sender.tag == 2) {
        NSWindow *w = self.window;
        if (!w.isKeyWindow) [w makeKeyWindow];   // Dia's menu acts on the key window
        if (!TweakPerformMenuTitle(kDiaDuplicateTabTitle)) {
            NSString *u = TweakURLForWindow(w);
            if (u.length) TweakOpenInNewTab(w, u);
        }
        return;
    }
    if (sender.tag == 2 && !self.loading) [(TweakChromeButton *)sender spinIcon];   // Arc's reload turn
    TweakNavBarPerform(self.window, sender.tag);
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf updateState]; });
}

@end
