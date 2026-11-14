// arcpatches's own command bar: an Arc-style palette over the window that finds
// open tabs, history, bookmarks, Dia's menu commands, chrome:// pages, or searches.
//   ⌘T          new-tab mode (results open in a new tab)
//   ⌘L / pill   current-tab mode, pre-filled with the current URL
#import "CommandBarInternal.h"
#import "Features.h"
#import "Browser.h"

@implementation TweakCommandBar

+ (instancetype)shared {
    static TweakCommandBar *bar;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ bar = [TweakCommandBar new]; });
    return bar;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _sources = [TweakCommandSources new];

    _panel = [[TweakCommandPanel alloc] initWithContentRect:NSMakeRect(0, 0, kWidth, kInputHeight)
                                               styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskFullSizeContentView
                                                 backing:NSBackingStoreBuffered defer:YES];
    _panel.opaque = NO;
    _panel.backgroundColor = NSColor.clearColor;
    _panel.hasShadow = YES;
    _panel.level = NSFloatingWindowLevel;
    _panel.delegate = self;
    _panel.releasedWhenClosed = NO;
    _panel.hidesOnDeactivate = YES;

    _background = [[NSVisualEffectView alloc] initWithFrame:_panel.contentView.bounds];
    _background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _background.material = NSVisualEffectMaterialHUDWindow;
    _background.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _background.state = NSVisualEffectStateActive;
    _background.wantsLayer = YES;
    _background.layer.cornerRadius = 16;
    _background.layer.cornerCurve = kCACornerCurveContinuous;
    _background.layer.masksToBounds = YES;
    _background.layer.borderWidth = 1;
    _panel.contentView = _background;

    TweakTintView *tint = [[TweakTintView alloc] initWithFrame:_background.bounds];
    tint.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_background addSubview:tint];

    _fieldIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _fieldIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightRegular];
    _fieldIcon.contentTintColor = NSColor.secondaryLabelColor;
    [_background addSubview:_fieldIcon];

    _field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    _field.bezeled = NO;
    _field.drawsBackground = NO;
    _field.focusRingType = NSFocusRingTypeNone;
    _field.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
    _field.placeholderString = @"Search or enter URL";
    _field.cell.scrollable = YES;
    _field.cell.wraps = NO;
    _field.delegate = self;
    [_background addSubview:_field];

    _divider = [[NSBox alloc] initWithFrame:NSZeroRect];
    _divider.boxType = NSBoxSeparator;
    [_background addSubview:_divider];

    _results = [[TweakResultsView alloc] initWithFrame:NSZeroRect];
    _results.delegate = self;
    [_background addSubview:_results];
    return self;
}

#pragma mark Showing

- (void)showInWindow:(NSWindow *)window mode:(TweakCommandBarMode)mode {
    if (!window) return;
    if (self.panel.isVisible) [self close];
    self.host = window;
    self.mode = mode;
    self.panel.appearance = window.effectiveAppearance;
    // HUD material is always dark; use the light popover material in light mode so text stays readable.
    BOOL dark = [[window.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]]
                 isEqualToString:NSAppearanceNameDarkAqua];
    self.background.material = dark ? NSVisualEffectMaterialHUDWindow : NSVisualEffectMaterialPopover;
    [self.background.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.background.layer.borderColor = dyn(1, 0.12, 0, 0.10).CGColor;
    }];
    [self.sources prepareForWindow:window];

    NSString *initial = @"";
    if (mode == TweakCommandBarCurrentTab) {
        NSString *u = TweakURLForWindow(window);
        if (u.length && ![u hasPrefix:@"dia://"]) initial = u;
    }
    self.field.stringValue = initial;
    self.typed = initial;
    self.completionText = nil;
    self.completionURL = nil;
    self.shownQuery = nil;
    [self layoutForRows:0];
    [window addChildWindow:self.panel ordered:NSWindowAbove];
    [self.panel makeKeyAndOrderFront:nil];
    [self.panel makeFirstResponder:self.field];
    // The system highlight (e.g. a light accent) under white text was unreadable in dark mode.
    if ([self.field.currentEditor isKindOfClass:NSTextView.class])
        ((NSTextView *)self.field.currentEditor).selectedTextAttributes = @{
            NSBackgroundColorAttributeName: dyn(1, 0.24, 0, 0.14),
            NSForegroundColorAttributeName: NSColor.labelColor,
        };
    [self.field.currentEditor selectAll:nil];
    // Current-tab mode starts with the URL selected and no list (like Arc's ⌘L).
    if (mode == TweakCommandBarNewTab) [self runQuery];
    else [self showItems:@[]];
}

- (void)layoutForRows:(NSUInteger)rows {
    NSWindow *w = self.host;
    NSRect wf = w.frame;
    CGFloat width = MIN(kWidth, NSWidth(wf) - 80);
    CGFloat listH = rows ? rows * kRowHeight + kListInset * 2 : 0;
    CGFloat height = kInputHeight + (rows ? 1 + listH : 0);
    CGFloat top = NSMaxY(wf) - NSHeight(wf) * 0.20;  // about a fifth of the way down
    [self.panel setFrame:NSMakeRect(NSMidX(wf) - width / 2, top - height, width, height) display:YES];

    self.fieldIcon.frame = NSMakeRect(22, height - kInputHeight / 2 - 12, 24, 24);
    self.field.frame = NSMakeRect(58, height - kInputHeight / 2 - 15, width - 58 - 22, 30);
    self.divider.hidden = rows == 0;
    self.divider.frame = NSMakeRect(0, height - kInputHeight - 1, width, 1);
    self.results.frame = NSMakeRect(0, 0, width, listH);
}

- (void)close {
    [self.host removeChildWindow:self.panel];
    [self.panel orderOut:nil];
    [self.host makeKeyAndOrderFront:nil];
}

- (void)windowDidResignKey:(NSNotification *)n {
    // Clicking outside closes it, like Arc; the window that took key keeps it.
    if (!self.panel.isVisible) return;
    [self.host removeChildWindow:self.panel];
    [self.panel orderOut:nil];
}

#pragma mark Results delegate

- (void)resultsView:(TweakResultsView *)v activate:(NSInteger)row { [self activateRow:row forceNewTab:NO]; }

- (NSImage *)iconForItem:(TweakItem *)item {
    if (item.kind == TweakItemCommand || item.kind == TweakItemPage || item.kind == TweakItemSearch) return nil;
    return [self.sources faviconFor:item.url];
}

@end

#pragma mark - Public

BOOL TweakCommandBarShow(NSWindow *window, BOOL newTab) {
    if (!window || ![NSStringFromClass(window.class) isEqualToString:kDiaPlatformWindowClass]) return NO;
    [[TweakCommandBar shared] showInWindow:window mode:newTab ? TweakCommandBarNewTab : TweakCommandBarCurrentTab];
    return YES;
}

static void installCommandBar(void) {
    TweakPaletteInstall();
    TweakSiteIconsInstall();
}

const TweakFeature TweakFeatureCommandBar = {"commandbar", {TWEAK_BROWSER_DIA}, NULL, installCommandBar};
