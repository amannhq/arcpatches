// The ArcPatches pane in Dia's Settings window: URL bar, sidebar, shortcuts,
// privacy and performance options.
#import "PrefsPane.h"

@implementation TweakPrefsPane

- (BOOL)isFlipped { return YES; }

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    _switches = [NSMutableDictionary dictionary];
    _rowsByKey = [NSMutableDictionary dictionary];

    _modePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSArray *m in @[@[@"Top (Dia default)", @(TweakURLBarModeTop)], @[@"Hidden", @(TweakURLBarModeHidden)], @[@"In sidebar", @(TweakURLBarModeSidebar)]]) {
        [_modePopup addItemWithTitle:m[0]];
        _modePopup.lastItem.tag = [m[1] integerValue];
    }
    _modePopup.target = self;
    _modePopup.action = @selector(modeChanged:);

    _commandBarPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSArray *m in @[@[@"ArcPatches (Arc-style)", @(TweakCommandBarStyleNative)], @[@"Dia's editor", @(TweakCommandBarStyleDiaEditor)], @[@"Off (Dia default)", @(TweakCommandBarStyleOff)]]) {
        [_commandBarPopup addItemWithTitle:m[0]];
        _commandBarPopup.lastItem.tag = [m[1] integerValue];
    }
    _commandBarPopup.target = self;
    _commandBarPopup.action = @selector(commandBarChanged:);

    NSView *urlGroup = [self groupWithRows:@[
        [self rowWithTitle:@"URL bar position" detail:@"Where the address and back, forward and reload controls live." control:_modePopup key:nil],
        [self rowWithTitle:@"Command bar" detail:@"What ⌘T, ⌘L and the sidebar URL bar open. ArcPatches's bar finds tabs, history, bookmarks and commands." control:_commandBarPopup key:nil],
        [self rowWithTitle:@"Reveal top bar on hover" detail:@"Move the pointer to the top edge of a page to show Dia's bar." control:[self switchForKey:TweakKeyRevealOnHover] key:TweakKeyRevealOnHover],
    ]];
    NSView *sidebarGroup = [self groupWithRows:@[
        [self rowWithTitle:@"⌘L opens the sidebar URL bar" detail:@"With Dia's editor as the command bar: open it at the sidebar instead of the top." control:[self switchForKey:TweakKeyCmdLFocusesSidebar] key:TweakKeyCmdLFocusesSidebar],
        [self rowWithTitle:@"Show full URL" detail:@"Otherwise only the site's domain is shown." control:[self switchForKey:TweakKeySidebarFullURL] key:TweakKeySidebarFullURL],
        [self rowWithTitle:@"Back, forward and reload buttons" detail:@"Shown next to the window controls." control:[self switchForKey:TweakKeySidebarNavButtons] key:TweakKeySidebarNavButtons],
        [self rowWithTitle:@"Copy link and site controls" detail:@"Buttons that appear in the URL bar when the pointer is over it." control:[self switchForKey:TweakKeySidebarPillButtons] key:TweakKeySidebarPillButtons],
        [self rowWithTitle:@"Top bar while the sidebar is hidden" detail:@"Shows Dia's bar when the sidebar is collapsed, as in focus mode. Off, like Arc: no URL bar until the sidebar is back." control:[self switchForKey:TweakKeyTopBarWhenSidebarHidden] key:TweakKeyTopBarWhenSidebarHidden],
    ]];
    NSView *topRowGroup = [self groupWithRows:@[
        [self rowWithTitle:@"Sidebar toggle button" detail:@"Shown after the window controls; hides and shows the sidebar with Dia's own command." control:[self switchForKey:TweakKeySidebarToggleButton] key:TweakKeySidebarToggleButton],
        [self rowWithTitle:@"Downloads in the Sidebar Corner" detail:@"Shows downloads at the bottom left of the sidebar, as Arc does, instead of next to the reload button." control:[self switchForKey:TweakKeyDownloadsInFooter] key:TweakKeyDownloadsInFooter],
        [self rowWithTitle:@"Profile name in top row" detail:@"Dia shows the profile name in the sidebar header. Arc doesn\u2019t, and it can sit under the back and forward buttons." control:[self switchForKey:TweakKeyTopRowProfileName] key:TweakKeyTopRowProfileName],
        [self rowWithTitle:@"Hide window buttons in full screen" detail:@"The sidebar's top row then starts with the toggle, as in Arc." control:[self switchForKey:TweakKeyHideWindowButtonsInFullScreen] key:TweakKeyHideWindowButtonsInFullScreen],
    ]];
    _recorders = [NSMutableArray array];
    NSMutableArray *shortcutRows = [NSMutableArray arrayWithObject:
        [self rowWithTitle:@"Extra shortcuts" detail:@"Keys for tidying tabs and switching profiles. Click a shortcut to change it." control:[self switchForKey:TweakKeyExtraShortcuts] key:TweakKeyExtraShortcuts]];
    for (NSDictionary *a in TweakShortcutActions()) {
        TweakShortcutRecorder *r = [[TweakShortcutRecorder alloc] initWithActionId:a[@"id"]];
        [_recorders addObject:r];
        [shortcutRows addObject:[self rowWithTitle:a[@"title"] detail:a[@"detail"] control:r key:[@"shortcut." stringByAppendingString:a[@"id"]]]];
    }
    _profileNumberPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _profileNumberPopup.controlSize = NSControlSizeSmall;
    _profileNumberPopup.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    NSEventModifierFlags ctrl = NSEventModifierFlagControl, opt = NSEventModifierFlagOption, cmd = NSEventModifierFlagCommand;
    for (NSArray *m in @[@[@"⌃1 … ⌃9", @(ctrl)], @[@"⌃⌥1 … ⌃⌥9", @(ctrl | opt)], @[@"⌃⌘1 … ⌃⌘9", @(ctrl | cmd)], @[@"None", @0]]) {
        [_profileNumberPopup addItemWithTitle:m[0]];
        _profileNumberPopup.lastItem.tag = [m[1] integerValue];
    }
    _profileNumberPopup.target = self;
    _profileNumberPopup.action = @selector(profileNumberChanged:);
    [shortcutRows addObject:[self rowWithTitle:@"Switch to profile 1–9" detail:@"In the order Dia lists your profiles. macOS uses ⌃1… for Spaces when that's turned on in Keyboard Shortcuts."
                                       control:_profileNumberPopup key:TweakKeyProfileNumberMods]];
    NSView *shortcutsGroup = [self groupWithRows:shortcutRows];
    NSMutableArray *arcRows = [NSMutableArray array];
    for (NSDictionary *r in TweakArcShortcutSettings())
        [arcRows addObject:[self rowWithTitle:r[@"title"] detail:r[@"detail"] control:[self switchForKey:r[@"key"]] key:r[@"key"]]];
    NSView *arcShortcutsGroup = [self groupWithRows:arcRows];

    NSView *privacyGroup = [self groupWithRows:@[
        [self rowWithTitle:@"Hide AI features" detail:@"Chat menus and shortcuts, Chats in the sidebar, the Chat button, \u201cChat with this tab\u201d on tab previews, \u201cAdd tabs or files\u201d, and page content extraction." control:[self switchForKey:TweakKeyHideAI] key:TweakKeyHideAI],
        [self rowWithTitle:@"Block AI services" detail:@"Dia's AI endpoints (chat, AI search, artifacts) and Google's Gemini API. Hover for the full list." control:[self switchForKey:TweakKeyBlockAI] key:TweakKeyBlockAI],
        [self rowWithTitle:@"Block telemetry" detail:@"Datadog, Sentry, Segment, LaunchDarkly events and Dia's OpenTelemetry gateway." control:[self switchForKey:TweakKeyBlockTelemetry] key:TweakKeyBlockTelemetry],
    ]];
    _blockedLabel = [self label:@"" size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];
    self.rowsByKey[TweakKeyBlockAI].firstObject.toolTip = [@"Blocked hosts:\n" stringByAppendingString:[TweakAIHosts() componentsJoinedByString:@"\n"]];

    _rendererPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSArray *r in @[@[@"Chromium default", @0], @[@"16", @16], @[@"8", @8], @[@"4", @4]]) {
        [_rendererPopup addItemWithTitle:r[0]];
        _rendererPopup.lastItem.tag = [r[1] integerValue];
    }
    _rendererPopup.target = self;
    _rendererPopup.action = @selector(rendererChanged:);
    NSView *perfGroup = [self groupWithRows:@[
        [self rowWithTitle:@"Turn off on-device AI" detail:@"Don't start Dia's local AI service process (about 40 MB), which otherwise classifies everything typed in the URL editor. Requires Hide AI features." control:[self switchForKey:TweakKeyDisableOnDeviceAI] key:TweakKeyDisableOnDeviceAI],
        [self rowWithTitle:@"Renderer process limit" detail:@"Tabs share processes above this number: less memory with many tabs, but one crash can take several tabs with it." control:_rendererPopup key:TweakKeyRendererLimit],
        [self rowWithTitle:@"Disable background networking" detail:@"Stops Chromium's background updaters (components, field trials). May delay Safe Browsing list updates." control:[self switchForKey:TweakKeyNoBackgroundNetworking] key:TweakKeyNoBackgroundNetworking],
    ]];
    NSTextField *perfNote = [self label:@"Performance options apply after restarting Dia." size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor];

    NSTextField *footer = [self label:@"Press ⌃⌘U to switch between Dia's URL bar and the option above.\nArcPatches is unofficial and not affiliated with The Browser Company. It re-patches Dia automatically after updates."
                                 size:11 weight:NSFontWeightRegular color:NSColor.tertiaryLabelColor];

    NSStackView *stack = [NSStackView stackViewWithViews:@[
        [self label:@"URL bar" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], urlGroup,
        [self label:@"Sidebar URL bar" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], sidebarGroup,
        [self label:@"Sidebar top row" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], topRowGroup,
        [self label:@"Arc shortcuts" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], arcShortcutsGroup,
        [self label:@"Shortcuts" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], shortcutsGroup,
        [self label:@"Privacy" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], privacyGroup, _blockedLabel,
        [self label:@"Performance" size:13 weight:NSFontWeightSemibold color:NSColor.labelColor], perfGroup, perfNote,
        footer,
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    [stack setCustomSpacing:20 afterView:urlGroup];
    [stack setCustomSpacing:20 afterView:sidebarGroup];
    [stack setCustomSpacing:20 afterView:arcShortcutsGroup];
    [stack setCustomSpacing:20 afterView:shortcutsGroup];
    [stack setCustomSpacing:20 afterView:topRowGroup];
    [stack setCustomSpacing:20 afterView:_blockedLabel];
    [stack setCustomSpacing:14 afterView:perfNote];
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:self.bounds];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.automaticallyAdjustsContentInsets = NO;   // positioned below the title bar in -layout
    TweakFlippedView *doc = [[TweakFlippedView alloc] initWithFrame:NSZeroRect];
    doc.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = doc;
    [self addSubview:scroll];
    _scroll = scroll;
    [doc addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [doc.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:doc.topAnchor constant:20],
        [stack.bottomAnchor constraintEqualToAnchor:doc.bottomAnchor constant:-20],
        [stack.leadingAnchor constraintEqualToAnchor:doc.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:doc.trailingAnchor constant:-20],
        [urlGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [sidebarGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [arcShortcutsGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [shortcutsGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [privacyGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [perfGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [topRowGroup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    ]];

    [self sync];
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(__unused NSTimer *t) { [weakSelf updateBlocked]; }];
    _timer.tolerance = 0.5;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sync) name:TweakSettingsDidChangeNotification object:nil];
    return self;
}

- (void)dealloc { [_timer invalidate]; [NSNotificationCenter.defaultCenter removeObserver:self]; }

/// Like Dia's own panes, the scroll area ends at the title bar, so content never
/// scrolls underneath it.
- (void)layout {
    [super layout];
    NSWindow *w = self.window;
    CGFloat titlebar = w ? MAX(0, NSHeight(w.frame) - NSMaxY(w.contentLayoutRect)) : 0;
    NSRect f = self.bounds;
    f.origin.y += titlebar;            // flipped: the top of the pane
    f.size.height -= titlebar;
    if (!NSEqualRects(self.scroll.frame, f)) self.scroll.frame = f;
}

- (void)updateBlocked {
    self.blockedLabel.stringValue = [NSString stringWithFormat:@"%lu requests blocked since launch. Blocking changes fully apply after restarting Dia.",
                                     (unsigned long)TweakBlockedRequestCount()];
}

- (void)setRow:(NSString *)key enabled:(BOOL)on {
    for (NSView *v in self.rowsByKey[key]) {
        v.alphaValue = on ? 1 : 0.45;
        if ([v isKindOfClass:NSControl.class]) [(NSControl *)v setEnabled:on];
    }
}

- (void)sync {
    TweakURLBarMode mode = TweakSettings.urlBarMode;
    [self.modePopup selectItemWithTag:mode];
    [self.commandBarPopup selectItemWithTag:TweakCommandBarCurrentStyle()];
    [self.rendererPopup selectItemWithTag:[NSUserDefaults.standardUserDefaults integerForKey:TweakKeyRendererLimit]];
    [self setRow:TweakKeyDisableOnDeviceAI enabled:[TweakSettings boolForKey:TweakKeyHideAI]];
    for (NSString *key in self.switches) self.switches[key].state = [TweakSettings boolForKey:key] ? NSControlStateValueOn : NSControlStateValueOff;
    [self setRow:TweakKeyRevealOnHover enabled:mode != TweakURLBarModeTop];
    for (NSString *k in @[TweakKeyCmdLFocusesSidebar, TweakKeySidebarFullURL, TweakKeySidebarNavButtons, TweakKeySidebarPillButtons, TweakKeyTopBarWhenSidebarHidden])
        [self setRow:k enabled:mode == TweakURLBarModeSidebar];
    BOOL shortcuts = [TweakSettings boolForKey:TweakKeyExtraShortcuts];
    for (TweakShortcutRecorder *r in self.recorders) {
        [r sync];
        [self setRow:[@"shortcut." stringByAppendingString:r.actionId] enabled:shortcuts];
    }
    [self.profileNumberPopup selectItemWithTag:TweakProfileNumberMods()];
    [self setRow:TweakKeyProfileNumberMods enabled:shortcuts];
}

- (void)modeChanged:(NSPopUpButton *)p { [TweakSettings setURLBarMode:p.selectedTag]; }
- (void)commandBarChanged:(NSPopUpButton *)p {
    [NSUserDefaults.standardUserDefaults setInteger:p.selectedTag forKey:TweakKeyCommandBarStyle];
    [NSNotificationCenter.defaultCenter postNotificationName:TweakSettingsDidChangeNotification object:nil];
}
- (void)rendererChanged:(NSPopUpButton *)p {
    [NSUserDefaults.standardUserDefaults setInteger:p.selectedTag forKey:TweakKeyRendererLimit];
    [NSNotificationCenter.defaultCenter postNotificationName:TweakSettingsDidChangeNotification object:nil];
}
- (void)profileNumberChanged:(NSPopUpButton *)p {
    [NSUserDefaults.standardUserDefaults setInteger:p.selectedTag forKey:TweakKeyProfileNumberMods];
    [NSNotificationCenter.defaultCenter postNotificationName:TweakSettingsDidChangeNotification object:nil];
}
- (void)switchChanged:(NSSwitch *)s { [TweakSettings setBool:s.state == NSControlStateValueOn forKey:s.identifier]; }

@end
