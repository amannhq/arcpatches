// Privacy: hides Dia's AI surfaces (menus, sidebar, top bar, new tab page, hover
// cards, the URL editor's AI controls) and overrides the defaults that feed the assistant.
#import "PrivacyInternal.h"
#import "Browser.h"
#import <objc/runtime.h>

#pragma mark - Hiding AI UI

static NSArray<NSString *> *aiMenuTitles(void) {
    return @[@"Chat…", @"New Chat", @"Focus Chat", @"Send Chat Prompt Now", @"Open Daily Brief", @"Personalize Dia"];
}

static NSHashTable<NSMenuItem *> *gHiddenMenuItems;  // only these are un-hidden; Dia hides some items itself

static void applyMenus(void) {
    if (!gHiddenMenuItems) gHiddenMenuItems = [NSHashTable weakObjectsHashTable];
    if (![TweakSettings boolForKey:TweakKeyHideAI]) {
        for (NSMenuItem *i in gHiddenMenuItems) i.hidden = NO;
        [gHiddenMenuItems removeAllObjects];
        return;
    }
    NSArray *titles = aiMenuTitles();
    for (NSMenuItem *top in NSApp.mainMenu.itemArray)
        for (NSMenuItem *i in top.submenu.itemArray)
            if ([titles containsObject:i.title] && !i.hidden) {
                i.hidden = YES;  // hidden items also lose their shortcuts
                [gHiddenMenuItems addObject:i];
            }
}

static void hideMatching(NSView *parent, BOOL hide, BOOL (^match)(NSView *)) {
    for (NSView *v in parent.subviews) if (match(v) && v.hidden != hide) v.hidden = hide;
}

// Footer: "Chats" library cell.
static void (*origFooterLayout)(id, SEL);
static void hookedFooterLayout(NSView *self, SEL _cmd) {
    origFooterLayout(self, _cmd);
    if ([TweakSettings boolForKey:TweakKeyHideAI])
        hideMatching(self, YES, ^BOOL(NSView *v) { return [NSStringFromClass(v.class) isEqualToString:kDiaLibraryCellClass]; });
}

// Top bar: "Chat with this tab", personalization and skills buttons.
static void (*origBarLayout)(id, SEL);
static void hookedBarLayout(NSView *self, SEL _cmd) {
    origBarLayout(self, _cmd);
    if (![TweakSettings boolForKey:TweakKeyHideAI]) return;
    for (NSView *row in self.subviews)
        hideMatching(row, YES, ^BOOL(NSView *v) {
            NSString *c = NSStringFromClass(v.class);
            if ([c hasPrefix:kDiaPersonalityModulePrefix]) return YES;
            return [c isEqualToString:kDiaNavigationCapsuleButtonClass] && [v.accessibilityLabel containsString:@"Chat"];
        });
}

// New tab page: the Dia logo above the composer. The composer itself stays: it is
// also Dia's URL/search box.
static void (*origNTPLayout)(id, SEL);
static void hookedNTPLayout(NSView *self, SEL _cmd) {
    origNTPLayout(self, _cmd);
    if (![TweakSettings boolForKey:TweakKeyHideAI]) return;  // relayoutWindows un-hides on toggle
    for (NSView *holder in self.subviews)
        hideMatching(holder, YES, ^BOOL(NSView *v) {
            NSString *c = NSStringFromClass(v.class);
            return [c hasPrefix:kDiaPersonalizationModulePrefix] || [c hasPrefix:kDiaPowerUpModulePrefix];
        });
}

// Tab hover card: "Chat with this tab" and "Create context bundle" (tabs handed to
// the AI). Matched by the action button class and its tooltip.
static BOOL isAIHoverAction(NSView *b) {
    NSString *t = b.toolTip ?: b.accessibilityLabel;
    return [t isEqualToString:@"Chat with this tab"] || [t isEqualToString:@"Create context bundle"];
}
static void applyHoverAction(NSView *b) {
    if (isAIHoverAction(b)) {
        BOOL hide = [TweakSettings boolForKey:TweakKeyHideAI];
        if (b.hidden != hide) b.hidden = hide;
    }
}
static void (*origActionSetToolTip)(id, SEL, NSString *);
static void hookedActionSetToolTip(NSView *self, SEL _cmd, NSString *tip) {
    origActionSetToolTip(self, _cmd, tip);
    applyHoverAction(self);
}
static void (*origActionMoveToWindow)(id, SEL);
static void hookedActionMoveToWindow(NSView *self, SEL _cmd) {
    origActionMoveToWindow(self, _cmd);
    applyHoverAction(self);
}

// URL editor / composer: placeholder reads as a URL bar, not a chat box.
static NSString *const kURLPlaceholder = @"Search or enter URL";
static NSAttributedString *urlPlaceholder(NSAttributedString *ph) {
    if (!ph.length || ![TweakSettings boolForKey:TweakKeyHideAI] || [ph.string isEqualToString:kURLPlaceholder]) return ph;
    return [[NSAttributedString alloc] initWithString:kURLPlaceholder attributes:[ph attributesAtIndex:0 effectiveRange:NULL]];
}

// Dia's Swift code stores the placeholder directly, but AppKit reads it back
// through the Objective-C getter when drawing, so substitute it there.
static NSAttributedString *(*origPlaceholderGetter)(id, SEL);
static NSAttributedString *hookedPlaceholderGetter(id self, SEL _cmd) {
    return urlPlaceholder(origPlaceholderGetter(self, _cmd));
}

// URL editor / composer: the bottom toolbar (mic, "Think more", Go) is all AI
// controls apart from Go, which Return already does.
static void (*origToolbarLayout)(id, SEL);
static void hookedToolbarLayout(NSView *self, SEL _cmd) {
    origToolbarLayout(self, _cmd);
    BOOL hide = [TweakSettings boolForKey:TweakKeyHideAI];
    if (self.hidden != hide) self.hidden = hide;
}

// With the toolbar hidden Dia still reserves its height under the suggestion list,
// clipping the last rows. Let the list run to the bottom instead.
static const CGFloat kSuggestionsBottomPad = 8;
static void (*origSuggestionsSetFrame)(id, SEL, NSRect);
static void hookedSuggestionsSetFrame(NSView *self, SEL _cmd, NSRect f) {
    NSView *toolbar = nil;
    for (NSView *s in self.superview.subviews)
        if ([NSStringFromClass(s.class) isEqualToString:kDiaEditorToolbarClass]) toolbar = s;
    if (toolbar.hidden && NSHeight(f) > 0 && self.superview.isFlipped)
        f.size.height = MAX(0, NSHeight(self.superview.bounds) - NSMinY(f) - kSuggestionsBottomPad);
    origSuggestionsSetFrame(self, _cmd, f);
}

// The start page's composer has the same reserved toolbar space; trim it while
// Dia's proposed height still includes the (hidden) toolbar.
static void (*origPanelSetFrame)(id, SEL, NSRect);
static BOOL inPopover(NSView *v) {
    for (NSView *s = v.superview; s; s = s.superview)
        if ([NSStringFromClass(s.class) containsString:kDiaPopoverModule]) return YES;  // sized by TweakNavBar's popover hook
    return NO;
}

static void hookedPanelSetFrame(NSView *self, SEL _cmd, NSRect f) {
    NSView *toolbar = TweakDescendantOfClass(self, kDiaEditorToolbarClass);
    if (toolbar.hidden && !inPopover(self) && NSHeight(f) >= NSMaxY(toolbar.frame) - 1 && NSHeight(f) > NSHeight(toolbar.frame))
        f.size.height -= NSHeight(toolbar.frame);
    origPanelSetFrame(self, _cmd, f);
}

// URL editor / composer: the "Add tabs or files" (attach context for the AI) row.
static void (*origCapsLayout)(id, SEL);
static void hookedCapsLayout(NSView *self, SEL _cmd) {
    origCapsLayout(self, _cmd);
    BOOL hide = [TweakSettings boolForKey:TweakKeyHideAI];
    if (self.hidden != hide) self.hidden = hide;
}

// Overrides one of Dia's own defaults while `on`. The value it replaced is kept
// under arcpatches.saved.<key> (an empty dict if there was none) and put back when off.
static void overrideDefault(NSString *key, id value, BOOL on) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSString *savedKey = [@"arcpatches.saved." stringByAppendingString:key];
    NSDictionary *saved = [d dictionaryForKey:savedKey];
    if (on) {
        if (!saved) {
            // The persistent domain only: a registered default must not be written back as the user's value.
            id old = [d persistentDomainForName:NSBundle.mainBundle.bundleIdentifier][key];
            [d setObject:old ? @{@"value": old} : @{} forKey:savedKey];
        }
        if (![[d objectForKey:key] isEqual:value]) [d setObject:value forKey:key];
    } else if (saved) {
        if (saved[@"value"]) [d setObject:saved[@"value"] forKey:key];
        else [d removeObjectForKey:key];
        [d removeObjectForKey:savedKey];
    }
}

static void applyDefaults(void) {
    BOOL hide = [TweakSettings boolForKey:TweakKeyHideAI];
    // Page content extraction feeds the assistant; Dia defaults it on.
    overrideDefault(@"enablePageContentExtraction", @NO, hide);
    overrideDefault(@"hasManuallyClosedAskOnPage", @YES, hide);
    overrideDefault(@"datadogTracesSamplingRate", @0, [TweakSettings boolForKey:TweakKeyBlockTelemetry]);
}

static void hookLayout(NSString *className, IMP imp, void (**orig)(id, SEL)) {
    Class c = NSClassFromString(className);
    if (c) *orig = (void *)TweakHook(c, @selector(layout), imp);
    else NSLog(@"[arcpatches] %@ not found", className);
}

static void relayoutWindows(void) {
    for (NSWindow *w in NSApp.windows) {
        NSMutableArray *queue = [NSMutableArray arrayWithObject:w.contentView.superview ?: w.contentView];
        while (queue.count) {
            NSView *v = queue.lastObject;
            [queue removeLastObject];
            NSString *c = NSStringFromClass(v.class);
            if ([c isEqualToString:kDiaSidebarFooterClass] || [c isEqualToString:kDiaNavigationBarClass] ||
                [c isEqualToString:kDiaNewTabPageContentClass]) {
                // Un-hide what we hid; Dia's layout then re-applies its own state.
                for (NSView *s in v.subviews) {
                    if ([NSStringFromClass(s.class) isEqualToString:kDiaLibraryCellClass]) s.hidden = NO;
                    for (NSView *g in s.subviews) {
                        NSString *gc = NSStringFromClass(g.class);
                        if ([gc hasPrefix:kDiaPersonalizationModulePrefix] || [gc hasPrefix:kDiaPowerUpModulePrefix] || [gc hasPrefix:kDiaPersonalityModulePrefix] ||
                            ([gc isEqualToString:kDiaNavigationCapsuleButtonClass] && [g.accessibilityLabel containsString:@"Chat"]))
                            g.hidden = NO;
                    }
                }
                v.needsLayout = YES;
            }
            [queue addObjectsFromArray:v.subviews];
        }
    }
}

void TweakPrivacyInstallUI(void) {
    hookLayout(kDiaSidebarFooterClass, (IMP)hookedFooterLayout, &origFooterLayout);
    hookLayout(kDiaNavigationBarClass, (IMP)hookedBarLayout, &origBarLayout);
    hookLayout(kDiaNewTabPageContentClass, (IMP)hookedNTPLayout, &origNTPLayout);
    hookLayout(kDiaAssistantCapabilitiesToolbarClass, (IMP)hookedCapsLayout, &origCapsLayout);
    hookLayout(kDiaEditorToolbarClass, (IMP)hookedToolbarLayout, &origToolbarLayout);
    Class hoverAction = NSClassFromString(kDiaTabPopoverActionButtonClass);
    if (hoverAction) {
        origActionSetToolTip = (void *)TweakHook(hoverAction, @selector(setToolTip:), (IMP)hookedActionSetToolTip);
        origActionMoveToWindow = (void *)TweakHook(hoverAction, @selector(viewDidMoveToWindow), (IMP)hookedActionMoveToWindow);
    }
    Class sugg = NSClassFromString(kDiaEditorSuggestionsClass);
    if (sugg) origSuggestionsSetFrame = (void *)TweakHook(sugg, @selector(setFrame:), (IMP)hookedSuggestionsSetFrame);
    Class panel = NSClassFromString(kDiaAssistantPanelRootClass);
    if (panel) origPanelSetFrame = (void *)TweakHook(panel, @selector(setFrame:), (IMP)hookedPanelSetFrame);
    Class editorText = TweakFindClass(kDiaEditorTextViewPrefix, kDiaEditorTextViewSuffix);
    if (editorText) origPlaceholderGetter = (void *)TweakHook(editorText, @selector(placeholderAttributedString), (IMP)hookedPlaceholderGetter);
    applyDefaults();
    applyMenus();
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil
                                                usingBlock:^(__unused NSNotification *n) { applyMenus(); }];
    [NSNotificationCenter.defaultCenter addObserverForName:TweakSettingsDidChangeNotification object:nil queue:nil
                                                usingBlock:^(__unused NSNotification *n) {
        applyDefaults();
        applyMenus();
        relayoutWindows();
    }];
    // Dia rebuilds menus now and then; keep them in line.
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(__unused NSTimer *t) { applyMenus(); }];
    t.tolerance = 5;
}
