// Adds an "arcpatches" pane to Dia's Settings window by appending a row to its
// sidebar table and swapping our own form in when that row is selected.
#import "PrefsPane.h"
#import "Features.h"
#import "Browser.h"
#import <objc/runtime.h>

static NSString *const kPaneTitle = @"ArcPatches";
static const void *kBaseCountKey = &kBaseCountKey;
static const void *kPaneKey = &kPaneKey;
static const void *kHiddenKey = &kHiddenKey;
static const void *kTitleKey = &kTitleKey;

static NSInteger (*origNumberOfRows)(id, SEL, NSTableView *);
static NSView *(*origViewForRow)(id, SEL, NSTableView *, NSTableColumn *, NSInteger);
static void (*origSelectionDidChange)(id, SEL, NSNotification *);

#pragma mark - Settings window plumbing

static NSInteger baseCount(NSTableView *t) { return [objc_getAssociatedObject(t, kBaseCountKey) integerValue]; }

static NSView *paneHost(NSWindow *w) {
    // The detail side of the settings split view (the item that isn't at x = 0).
    NSMutableArray *queue = [NSMutableArray arrayWithObject:w.contentView];
    while (queue.count) {
        NSView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([v isKindOfClass:NSSplitView.class]) {
            for (NSView *item in v.subviews)
                if (NSMinX(item.frame) > 0 && NSWidth(item.frame) > 100 && item.subviews.count) return item.subviews.firstObject;
            return nil;
        }
        [queue addObjectsFromArray:v.subviews];
    }
    return nil;
}

static NSTextField *titleField(NSWindow *w) {
    for (NSToolbarItem *item in w.toolbar.items) {
        if (![item.itemIdentifier isEqualToString:@"PreferencesPaneTitle"]) continue;
        NSMutableArray *queue = item.view ? [NSMutableArray arrayWithObject:item.view] : [NSMutableArray array];
        while (queue.count) {
            NSView *v = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([v isKindOfClass:NSTextField.class]) return (NSTextField *)v;
            [queue addObjectsFromArray:v.subviews];
        }
    }
    return nil;
}

static void showPane(NSWindow *w, BOOL show) {
    NSView *host = paneHost(w);
    if (!host) return;
    TweakPrefsPane *pane = objc_getAssociatedObject(w, kPaneKey);
    NSTextField *title = titleField(w);
    if (show) {
        if (!pane) {
            pane = [[TweakPrefsPane alloc] initWithFrame:host.bounds];
            pane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
            objc_setAssociatedObject(w, kPaneKey, pane, OBJC_ASSOCIATION_RETAIN);
        }
        if (pane.superview == host) return;
        NSMutableArray *hidden = [NSMutableArray array];
        for (NSView *v in host.subviews)
            if (!v.hidden) { v.hidden = YES; [hidden addObject:v]; }
        objc_setAssociatedObject(w, kHiddenKey, hidden, OBJC_ASSOCIATION_RETAIN);
        pane.frame = host.bounds;
        [host addSubview:pane];
        if (title) {
            objc_setAssociatedObject(w, kTitleKey, title.stringValue, OBJC_ASSOCIATION_RETAIN);
            title.stringValue = kPaneTitle;
        }
    } else if (pane.superview) {
        [pane removeFromSuperview];
        for (NSView *v in objc_getAssociatedObject(w, kHiddenKey)) v.hidden = NO;
        objc_setAssociatedObject(w, kHiddenKey, nil, OBJC_ASSOCIATION_RETAIN);
        NSString *old = objc_getAssociatedObject(w, kTitleKey);
        if (title && old && [title.stringValue isEqualToString:kPaneTitle]) title.stringValue = old;
    }
}

static NSInteger hookedNumberOfRows(id self, SEL _cmd, NSTableView *t) {
    NSInteger n = origNumberOfRows(self, _cmd, t);
    objc_setAssociatedObject(t, kBaseCountKey, @(n), OBJC_ASSOCIATION_RETAIN);
    return n + 1;
}

static NSView *makeCell(NSTableView *t) {
    // Match Dia's own cells: 18pt icon at x=5, label at x=32.
    NSFont *font = [NSFont systemFontOfSize:13];
    NSView *sample = [t viewAtColumn:0 row:0 makeIfNecessary:NO];
    for (NSView *v in sample.subviews)
        if ([v isKindOfClass:NSTextField.class]) font = [(NSTextField *)v font];

    NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 164, 28)];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"sidebar.left" accessibilityDescription:kPaneTitle]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightRegular];
    icon.contentTintColor = NSColor.labelColor;
    icon.frame = NSMakeRect(5, 2, 18, 24);
    NSTextField *label = [NSTextField labelWithString:kPaneTitle];
    label.font = font;
    label.frame = NSMakeRect(32, 6, 120, 17);
    [cell addSubview:icon];
    [cell addSubview:label];
    cell.imageView = icon;
    cell.textField = label;
    return cell;
}

static NSView *hookedViewForRow(id self, SEL _cmd, NSTableView *t, NSTableColumn *col, NSInteger row) {
    if (row == baseCount(t)) return makeCell(t);
    return origViewForRow(self, _cmd, t, col, row);
}

static void hookedSelectionDidChange(id self, SEL _cmd, NSNotification *n) {
    NSTableView *t = n.object;
    if ([t isKindOfClass:NSTableView.class] && t.selectedRow == baseCount(t)) {
        showPane(t.window, YES);
        return;  // Dia's handler would index past its own pane list.
    }
    if ([t isKindOfClass:NSTableView.class]) showPane(t.window, NO);
    origSelectionDidChange(self, _cmd, n);
}

void TweakPreferencesInstall(void) {
    Class cls = NSClassFromString(kDiaPreferencesListClass);
    if (!cls) { NSLog(@"[arcpatches] %@ not found; settings pane inactive", kDiaPreferencesListClass); return; }
    SEL sels[] = {@selector(numberOfRowsInTableView:), @selector(tableView:viewForTableColumn:row:), @selector(tableViewSelectionDidChange:)};
    // All or nothing: an extra row without its cell and selection hooks crashes Dia's Settings.
    for (int i = 0; i < 3; i++)
        if (!class_getInstanceMethod(cls, sels[i])) { NSLog(@"[arcpatches] %@ lacks %@; settings pane inactive", kDiaPreferencesListClass, NSStringFromSelector(sels[i])); return; }
    origNumberOfRows = (void *)TweakHook(cls, sels[0], (IMP)hookedNumberOfRows);
    origViewForRow = (void *)TweakHook(cls, sels[1], (IMP)hookedViewForRow);
    origSelectionDidChange = (void *)TweakHook(cls, sels[2], (IMP)hookedSelectionDidChange);
}

const TweakFeature TweakFeaturePreferences = {"preferences", {TWEAK_BROWSER_DIA}, NULL, TweakPreferencesInstall};
