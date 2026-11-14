// Arc's site controls popover. Built by hand in a flipped view, top to bottom: action tiles,
// the profile's extensions, per-site settings, then the connection badge and a "…" menu.
#import "SiteControlsInternal.h"
#import "SiteControlsViews.h"
#import "Browser.h"

static const CGFloat kWidth = ArcPopoverWidth, kPad = ArcSpace3, kGap = ArcSpace2, kTileH = ArcTileHeight, kRowH = ArcRowHeight;
static const NSUInteger kColumns = 4;
static const CGFloat kRowInset = (ArcRowHeight - ArcRowIconCircle) / 2;   // rows' circles line up with the tiles

@interface TweakSiteControlsView : NSView
@end
@implementation TweakSiteControlsView
- (BOOL)isFlipped { return YES; }
@end

static TweakSiteControls *gShown;
static __weak NSView *gClosedAnchor;
static NSTimeInterval gClosedAt;

// Dia's own screenshot command, if its menu has one (by selector, else by title).
static NSMenuItem *screenshotItem(NSMenu *menu, int depth) {
    if (!menu || depth > 4) return nil;
    [menu update];   // runs validation, so isEnabled is current
    SEL known = NSSelectorFromString(kDiaCaptureScreenshotAction);
    for (NSMenuItem *item in menu.itemArray) {
        if (item.submenu) {
            NSMenuItem *hit = screenshotItem(item.submenu, depth + 1);
            if (hit) return hit;
            continue;
        }
        if (item.isSeparatorItem || item.isHidden || !item.action || !item.isEnabled) continue;
        NSString *t = item.title;
        if (item.action == known || [t localizedCaseInsensitiveContainsString:@"Screenshot"]
            || [t localizedCaseInsensitiveContainsString:@"Capture"]) return item;
    }
    return nil;
}

@implementation TweakSiteControls

- (void)loadView {
    self.view = [[TweakSiteControlsView alloc] initWithFrame:NSMakeRect(0, 0, kWidth, 200)];
}

#pragma mark Layout

- (CGFloat)placeHeader:(NSString *)title atY:(CGFloat)y {
    NSTextField *h = TweakSiteSectionHeader(title);
    [h sizeToFit];
    h.frame = NSMakeRect(kPad, y, kWidth - kPad * 2, NSHeight(h.frame));
    [self.view addSubview:h];
    return y + NSHeight(h.frame) + ArcSpace2;
}

- (CGFloat)placeGrid:(NSArray<NSView *> *)tiles columns:(NSUInteger)columns atY:(CGFloat)y {
    CGFloat w = (kWidth - kPad * 2 - kGap * (columns - 1)) / columns;
    for (NSUInteger i = 0; i < tiles.count; i++) {
        tiles[i].frame = NSMakeRect(kPad + (i % columns) * (w + kGap), y + (i / columns) * (kTileH + kGap), w, kTileH);
        [self.view addSubview:tiles[i]];
    }
    NSUInteger rows = (tiles.count + columns - 1) / columns;
    return y + rows * kTileH + (rows ? rows - 1 : 0) * kGap;
}

- (void)build {
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSURLComponents *c = [NSURLComponents componentsWithString:self.url];
    self.screenshotItem = screenshotItem(NSApp.mainMenu, 0);

    NSMutableArray *actions = [NSMutableArray arrayWithObjects:
        [TweakSiteTile tileWithSymbol:@"square.and.arrow.up" label:@"Share" target:self action:@selector(share:)],
        [TweakSiteTile tileWithSymbol:@"link" label:@"Copy Link" target:self action:@selector(copyLink:)], nil];
    if (self.screenshotItem)
        [actions addObject:[TweakSiteTile tileWithSymbol:@"camera" label:@"Screenshot" target:self action:@selector(screenshot:)]];
    [actions addObject:[TweakSiteTile tileWithSymbol:@"info.circle" label:@"Site Info" target:self action:@selector(siteInfo:)]];
    CGFloat y = [self placeGrid:actions columns:actions.count atY:kPad] + ArcSpace4;

    y = [self placeHeader:@"Extensions" atY:y];
    NSMutableArray *tiles = [NSMutableArray array];
    NSSize iconSize = NSMakeSize(ArcFaviconSize, ArcFaviconSize);
    for (NSUInteger i = 0; i < self.extensions.count; i++) {
        TweakSiteExtension *e = self.extensions[i];
        NSImage *icon = [e.icon copy];
        icon.size = iconSize;
        TweakSiteTile *t = icon ? [TweakSiteTile tileWithImage:icon label:e.name target:self action:@selector(extension:)]
                                : [TweakSiteTile tileWithSymbol:@"puzzlepiece.extension" label:e.name target:self action:@selector(extension:)];
        t.tag = i;
        [tiles addObject:t];
    }
    [tiles addObject:[TweakSiteTile tileWithSymbol:@"plus" label:@"Add Extensions" target:self action:@selector(webStore:)]];
    y = [self placeGrid:tiles columns:kColumns atY:y] + ArcSpace4;

    y = [self placeHeader:@"Settings" atY:y];
    NSMutableArray *rows = [NSMutableArray arrayWithObject:
        [TweakSiteRow rowWithSymbol:@"slider.horizontal.3" title:@"Site Settings" subtitle:c.host target:self action:@selector(siteSettings:)]];
    for (NSDictionary *p in TweakSitePermissions(self.url))
        [rows addObject:[TweakSiteRow rowWithSymbol:p[@"symbol"] title:p[@"title"] subtitle:p[@"state"] target:self action:@selector(siteSettings:)]];
    for (NSView *r in rows) {
        r.frame = NSMakeRect(kPad - kRowInset, y, kWidth - (kPad - kRowInset) * 2, kRowH);
        [self.view addSubview:r];
        y += kRowH;
    }

    y += ArcSpace2;
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(kPad, y, kWidth - kPad * 2, 1)];
    line.boxType = NSBoxSeparator;
    [self.view addSubview:line];
    y += 1 + ArcSpace2;

    NSView *badge = TweakSiteSecurityBadge([c.scheme.lowercaseString isEqualToString:@"https"]);
    badge.frameOrigin = NSMakePoint(kPad, y);
    [self.view addSubview:badge];
    TweakSiteTile *more = [TweakSiteTile tileWithSymbol:@"ellipsis" label:@"More" target:self action:@selector(more:)];
    more.frame = NSMakeRect(kWidth - kPad - ArcBadgeHeight, y, ArcBadgeHeight, ArcBadgeHeight);
    more.radius = ArcBadgeHeight / 2;
    [self.view addSubview:more];
    y += ArcBadgeHeight + kPad;

    self.view.frameSize = NSMakeSize(kWidth, y);
    self.popover.contentSize = self.view.frame.size;
}

#pragma mark Presenting

- (void)showFrom:(NSView *)anchor {
    self.anchor = anchor;
    self.browserWindow = anchor.window;
    self.url = TweakURLForWindow(anchor.window);
    __weak typeof(self) weakSelf = self;
    self.extensions = TweakSiteExtensions(^(NSArray *list) {
        TweakSiteControls *me = weakSelf;
        if (!me.popover.shown || [list isEqualToArray:me.extensions]) return;
        me.extensions = list;
        [me build];
    });
    self.popover = [NSPopover new];
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.animates = YES;
    self.popover.delegate = self;
    self.popover.contentViewController = self;
    [self view];
    [self build];
    // Anchored to the pill, not the button: the pill may hide its buttons while this is open.
    NSView *host = anchor.superview ?: anchor;
    NSRect rect = anchor.superview ? anchor.frame : anchor.bounds;
    [self.popover showRelativeToRect:rect ofView:host preferredEdge:host.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY];
    self.escapeMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *e) {
        if (e.keyCode != 53 || !weakSelf.popover.shown) return e;   // Escape
        [weakSelf.popover performClose:nil];
        return nil;
    }];
    // The button keeps Arc's "selected" fill (and the pill keeps it shown) while this is open.
    if ([anchor respondsToSelector:@selector(setSelected:)]) [(id)anchor setSelected:YES];
}

// Before the close animation: the button's mouse up may come before didClose.
- (void)popoverWillClose:(NSNotification *)n {
    gClosedAnchor = self.anchor;
    gClosedAt = NSProcessInfo.processInfo.systemUptime;
}

- (void)popoverDidClose:(NSNotification *)n { [self finish]; }

// Idempotent: from didClose, and after -close (which may not tell the delegate).
- (void)finish {
    if (self.escapeMonitor) [NSEvent removeMonitor:self.escapeMonitor];
    self.escapeMonitor = nil;
    if (gShown == self) gShown = nil;
    // The popover and this controller hold each other; let both go once it is gone.
    NSPopover *popover = self.popover;
    dispatch_async(dispatch_get_main_queue(), ^{ if (!popover.shown) popover.contentViewController = nil; });
    NSView *anchor = self.anchor;
    if ([anchor respondsToSelector:@selector(setSelected:)]) [(id)anchor setSelected:NO];
    // The pill decides again whether its buttons show, now that this one may hide.
    NSView *bar = anchor;
    while (bar && ![bar isKindOfClass:TweakSidebarURLBar.class]) bar = bar.superview;
    if ([bar respondsToSelector:@selector(updateButtons)]) [bar updateButtons];
}

// Closes the popover, then runs the action once it is gone (so what it opens takes focus).
- (void)closeThen:(void (^)(NSWindow *window, NSString *url))action {
    NSWindow *w = self.browserWindow;
    NSString *u = self.url;
    [self.popover close];
    [self finish];
    dispatch_async(dispatch_get_main_queue(), ^{ if (w) action(w, u); });
}

- (NSString *)siteSettingsURL { return [kDiaSiteDetailsURLPrefix stringByAppendingString:TweakSidebarEncodedOrigin(self.url)]; }

@end

#pragma mark - Entry points

BOOL TweakSiteControlsIsShownFor(NSView *anchor) {
    return anchor && gShown.anchor == anchor && gShown.popover.shown;
}

void TweakSiteControlsToggle(NSView *anchor) {
    if (!anchor.window) return;
    if (TweakSiteControlsIsShownFor(anchor)) { [gShown.popover performClose:nil]; return; }
    // The click on the button closed the transient popover on mouse down: that click means close.
    if (gClosedAnchor == anchor && NSProcessInfo.processInfo.systemUptime - gClosedAt < 0.3) return;
    if (gShown) { TweakSiteControls *old = gShown; [old.popover close]; [old finish]; }
    gShown = [TweakSiteControls new];
    [gShown showFrom:anchor];
}
