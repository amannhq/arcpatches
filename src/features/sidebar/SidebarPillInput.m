// What the URL pill does with the mouse and with copies: a click opens the address editor,
// a drag drags the page's link, a right-click shows a small menu, and every copy (its
// own button, the site controls popover, ⌘⇧C) confirms in place with "Copied".
#import "SidebarViews.h"
#import "../shortcuts/CleanURL.h"

static const CGFloat kDragThreshold = 4;   // points of movement before a press becomes a drag
static NSHashTable<TweakSidebarURLBar *> *gBars;

@interface TweakSidebarURLBar (Private)
- (void)syncHover;
@end


#pragma mark - "Copied"

void TweakSidebarPillRegister(TweakSidebarURLBar *bar) {
    if (!gBars) gBars = [NSHashTable weakObjectsHashTable];
    [gBars addObject:bar];
}

// The pill a person can see in this window: attached, not hidden, sidebar not collapsed.
static TweakSidebarURLBar *visiblePill(NSWindow *window) {
    if (!window) return nil;
    for (TweakSidebarURLBar *bar in gBars.allObjects)
        if (bar.window == window && bar.superview && !bar.isHiddenOrHasHiddenAncestor && NSWidth(bar.superview.frame) > 40) return bar;
    return nil;
}

BOOL TweakSidebarShowCopiedFeedback(NSWindow *window) {
    TweakSidebarURLBar *bar = visiblePill(window);
    [bar showCopiedFeedback];
    return bar != nil;
}

@implementation TweakSidebarURLBar (Input)

// "Copied" replaces the host and the link icon becomes a checkmark, then both restore.
- (void)showCopiedFeedback {
    NSUInteger generation = ++self.feedbackGeneration;
    self.showingFeedback = YES;
    TweakChromeCrossfade(self.label.layer);
    self.label.stringValue = @"Copied";
    self.needsLayout = YES;   // the empty state's magnifying glass goes
    [self.linkButton setSymbol:@"checkmark" animated:YES];
    NSAccessibilityPostNotificationWithUserInfo(NSApp, NSAccessibilityAnnouncementRequestedNotification,
                                                @{NSAccessibilityAnnouncementKey: @"Copied"});
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ArcFeedbackHold * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TweakSidebarURLBar *bar = weakSelf;
        if (!bar || bar.feedbackGeneration != generation) return;   // a later copy owns the label now
        bar.showingFeedback = NO;
        TweakChromeCrossfade(bar.label.layer);
        [bar.linkButton setSymbol:@"link" animated:YES];
        [bar forceRefresh];
    });
}

- (void)copyLink:(id)sender {
    if (TweakCopyPageLink(self.window, NO)) [self showCopiedFeedback];
    else NSBeep();
}

- (void)copyMarkdownLink:(id)sender {
    if (TweakCopyPageLink(self.window, YES)) [self showCopiedFeedback];
    else NSBeep();
}

// The site button only has a frame while shown; otherwise the popover hangs off the pill.
- (void)openSiteControls:(id)sender {
    TweakSidebarOpenSiteControls(self.siteButton.isHidden ? self.pill : self.siteButton);
}

#pragma mark Mouse

// The pill's own subviews (label, icon) take no clicks: the bar handles them all, and
// never lets a press on the pill move the window.
- (NSView *)hitTest:(NSPoint)p {
    NSView *hit = [super hitTest:p];
    return (hit == self.pill || hit == self.label || hit == self.searchIcon) ? self : hit;
}
- (BOOL)mouseDownCanMoveWindow { return NO; }

- (BOOL)hasPageURL {
    NSString *u = self.currentURL;
    return u.length && ![u isEqualToString:@"about:blank"];
}

// A click opens the editor on mouse up; moving a few points first drags the link instead.
- (void)mouseDown:(NSEvent *)e {
    if (e.modifierFlags & NSEventModifierFlagControl) { [NSMenu popUpContextMenu:[self menuForEvent:e] withEvent:e forView:self]; return; }
    NSPoint start = e.locationInWindow;
    while (YES) {
        NSEvent *next = [self.window nextEventMatchingMask:NSEventMaskLeftMouseDragged | NSEventMaskLeftMouseUp];
        if (!next || next.type == NSEventTypeLeftMouseUp) { if (next) [self openEditor]; return; }
        NSPoint p = next.locationInWindow;
        if ([self hasPageURL] && hypot(p.x - start.x, p.y - start.y) >= kDragThreshold) { [self dragLinkWithEvent:e]; return; }
    }
}

- (void)dragLinkWithEvent:(NSEvent *)e {
    NSString *u = TweakLiveURLForWindow(self.window), *url = u.length ? TweakCleanURL(u) : nil;
    if (!url.length) return;
    NSPasteboardItem *item = [NSPasteboardItem new];
    if ([NSURL URLWithString:url]) [item setString:url forType:NSPasteboardTypeURL];
    [item setString:url forType:NSPasteboardTypeString];
    NSDraggingItem *drag = [[NSDraggingItem alloc] initWithPasteboardWriter:item];
    NSRect r = self.pill.frame;
    NSBitmapImageRep *rep = [self.pill bitmapImageRepForCachingDisplayInRect:self.pill.bounds];
    NSImage *image = nil;
    if (rep) {
        [self.pill cacheDisplayInRect:self.pill.bounds toBitmapImageRep:rep];
        image = [[NSImage alloc] initWithSize:r.size];
        [image addRepresentation:rep];
    }
    [drag setDraggingFrame:r contents:image];
    [self beginDraggingSessionWithItems:@[drag] event:e source:self];
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)s sourceOperationMaskForDraggingContext:(NSDraggingContext)c {
    return NSDragOperationCopy | NSDragOperationLink;
}

- (void)draggingSession:(NSDraggingSession *)s endedAtPoint:(NSPoint)p operation:(NSDragOperation)op { [self syncHover]; }

#pragma mark Menu

- (NSMenu *)menuForEvent:(NSEvent *)e {
    BOOL page = [self hasPageURL], site = TweakSidebarURLIsSite(self.currentURL);
    NSMenu *menu = [NSMenu new];
    menu.autoenablesItems = NO;
    NSArray *items = @[@[@"Copy Link", NSStringFromSelector(@selector(copyLink:)), @(page)],
                       @[@"Copy as Markdown Link", NSStringFromSelector(@selector(copyMarkdownLink:)), @(page)],
                       @[@"Site Controls…", NSStringFromSelector(@selector(openSiteControls:)), @(site)]];
    for (NSArray *i in items) {
        if ([i[0] hasPrefix:@"Site"]) [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *m = [menu addItemWithTitle:i[0] action:NSSelectorFromString(i[1]) keyEquivalent:@""];
        m.target = self;
        m.enabled = [i[2] boolValue];
    }
    return menu;
}

@end
