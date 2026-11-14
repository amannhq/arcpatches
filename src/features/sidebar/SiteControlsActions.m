// What the site controls popover's tiles, rows and "…" menu do. Each closes the popover
// first, so whatever it opens (a tab, a menu, Dia's own popups) gets focus.
#import "SiteControlsInternal.h"
#import "Browser.h"
#import "../shortcuts/CleanURL.h"

static NSString *const kWebStoreURL = @"https://chromewebstore.google.com";

@implementation TweakSiteControls (Actions)

- (void)share:(NSButton *)sender {
    NSURL *u = [NSURL URLWithString:self.url];
    if (!u) { NSBeep(); return; }
    NSSharingServicePicker *picker = [[NSSharingServicePicker alloc] initWithItems:@[u]];
    picker.delegate = self;
    [picker showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
}

- (void)sharingServicePicker:(NSSharingServicePicker *)picker didChooseSharingService:(NSSharingService *)service {
    if (service) { [self.popover close]; [self finish]; }
}

- (void)copyLink:(id)sender {
    NSView *bar = self.anchor;
    while (bar && ![bar isKindOfClass:TweakSidebarURLBar.class]) bar = bar.superview;
    [self closeThen:^(NSWindow *w, NSString *u) {
        // The pill's own copy shows "Copied" in its label.
        if ([bar respondsToSelector:@selector(copyLink:)]) [bar copyLink:nil];
        else if (!TweakSidebarCopyURL(w)) NSBeep();
    }];
}

- (void)screenshot:(id)sender {
    NSMenuItem *item = self.screenshotItem;
    [self closeThen:^(NSWindow *w, NSString *u) {
        [w makeKeyAndOrderFront:nil];
        if (![NSApp sendAction:item.action to:item.target from:item]) NSBeep();
    }];
}

- (void)siteInfo:(id)sender { [self closeThen:^(NSWindow *w, NSString *u) { TweakSidebarOpenDiaSiteControls(w); }]; }

- (void)siteSettings:(id)sender {
    NSString *settings = self.siteSettingsURL;
    [self closeThen:^(NSWindow *w, NSString *u) { TweakOpenInNewTab(w, settings); }];
}

- (void)webStore:(id)sender { [self closeThen:^(NSWindow *w, NSString *u) { TweakOpenInNewTab(w, kWebStoreURL); }]; }

// Pinned extensions have a button in Dia's (hidden) top bar that opens their popup; the
// rest get Chromium's details page.
- (void)extension:(NSButton *)sender {
    if (sender.tag < 0 || (NSUInteger)sender.tag >= self.extensions.count) return;
    TweakSiteExtension *e = self.extensions[sender.tag];
    [self closeThen:^(NSWindow *w, NSString *u) {
        BOOL pressed = TweakSidebarPressNavBarElement(w, kDiaPinnedExtensionsViewClass, ^BOOL(id el) {
            NSString *label = [el respondsToSelector:@selector(accessibilityLabel)] ? [el accessibilityLabel] : nil;
            NSString *tip = [el isKindOfClass:NSView.class] ? [(NSView *)el toolTip] : nil;
            NSString *ident = [el respondsToSelector:@selector(accessibilityIdentifier)] ? [el accessibilityIdentifier] : nil;
            return ([label isKindOfClass:NSString.class] && [label caseInsensitiveCompare:e.name] == NSOrderedSame)
                || ([tip isKindOfClass:NSString.class] && [tip caseInsensitiveCompare:e.name] == NSOrderedSame)
                || ([ident isKindOfClass:NSString.class] && [ident containsString:e.identifier]);
        });
        if (!pressed) TweakOpenInNewTab(w, [kDiaExtensionDetailsURLPrefix stringByAppendingString:e.identifier]);
    }];
}

- (void)more:(NSButton *)sender {
    NSMenu *menu = [NSMenu new];
    [menu addItemWithTitle:@"Copy as Markdown Link" action:@selector(copyMarkdown:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:@"Open Site Settings" action:@selector(siteSettings:) keyEquivalent:@""].target = self;
    [menu addItemWithTitle:@"View Page Source" action:@selector(viewSource:) keyEquivalent:@""].target = self;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight(sender.bounds) + 4) inView:sender];
}

- (void)copyMarkdown:(id)sender {
    [self closeThen:^(NSWindow *w, NSString *u) {
        NSString *title = nil;
        @try {
            id t = [TweakActiveTabForWindow(w) valueForKey:@"title"];
            if ([t isKindOfClass:NSString.class]) title = t;
        } @catch (__unused NSException *e) {}
        NSPasteboard *pb = NSPasteboard.generalPasteboard;
        [pb clearContents];
        [pb setString:TweakMarkdownLink(title, TweakCleanURL(u)) forType:NSPasteboardTypeString];
    }];
}

- (void)viewSource:(id)sender {
    [self closeThen:^(NSWindow *w, NSString *u) { TweakOpenInNewTab(w, [@"view-source:" stringByAppendingString:u]); }];
}

@end
