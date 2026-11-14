// arcpatches's own command bar: an Arc-style palette that finds open tabs, history,
// bookmarks, Dia's menu commands, chrome:// pages, or searches.
//   ⌘T          new-tab mode, centred over the web content (results open in a new tab)
//   ⌘L / pill   current-tab mode: drops down from the URL pill, pre-filled with the URL
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

    _panel = [[TweakCommandPanel alloc] initWithContentRect:NSMakeRect(0, 0, ArcPaletteMinWidth, ArcPaletteSearchHeight)
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
    ArcRound(_background.layer, ArcRadiusPopover);
    _background.layer.masksToBounds = YES;
    _panel.contentView = _background;

    TweakTintView *tint = [[TweakTintView alloc] initWithFrame:_background.bounds];
    tint.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_background addSubview:tint];

    _fieldIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _fieldIcon.imageScaling = NSImageScaleProportionallyDown;
    _fieldIcon.contentTintColor = ArcIconColor(YES);
    [_background addSubview:_fieldIcon];

    _field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    _field.bezeled = NO;
    _field.drawsBackground = NO;
    _field.focusRingType = NSFocusRingTypeNone;
    _field.placeholderString = @"Search or Enter URL...";
    _field.cell.scrollable = YES;
    _field.cell.wraps = NO;
    _field.delegate = self;
    [_background addSubview:_field];

    _divider = [[NSBox alloc] initWithFrame:NSZeroRect];
    _divider.boxType = NSBoxCustom;
    _divider.borderWidth = 0;
    _divider.fillColor = ArcHairline();
    [_background addSubview:_divider];

    _results = [[TweakResultsView alloc] initWithFrame:NSZeroRect];
    _results.delegate = self;
    [_background addSubview:_results];
    return self;
}

#pragma mark Showing

- (void)showInWindow:(NSWindow *)window mode:(TweakCommandBarMode)mode anchor:(NSRect)anchor pinned:(BOOL)pinned {
    if (!window) return;
    if (self.panel.isVisible) [self close];
    self.showGeneration++;
    self.host = window;
    self.mode = mode;
    self.anchor = anchor;
    self.pinnedToPill = pinned;
    self.panel.appearance = window.effectiveAppearance;
    [self applyStyleForMode];
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
    self.results.items = @[];
    [self layoutForRows:0];
    [window addChildWindow:self.panel ordered:NSWindowAbove];
    [self.panel makeKeyAndOrderFront:nil];
    [self.panel makeFirstResponder:self.field];
    // The system highlight (e.g. a light accent) under white text was unreadable in dark mode.
    if ([self.field.currentEditor isKindOfClass:NSTextView.class])
        ((NSTextView *)self.field.currentEditor).selectedTextAttributes = @{
            NSBackgroundColorAttributeName: ArcTextSelection(),
            NSForegroundColorAttributeName: NSColor.labelColor,
        };
    [self.field.currentEditor selectAll:nil];
    [self updateFieldIcon];
    // ⌘L starts with the URL selected and suggestions for the page you're on, like Arc.
    // Both list their first rows synchronously, so the panel appears at its height.
    if (mode == TweakCommandBarNewTab || !initial.length) [self runQuery];
    else [self showSuggestionsForCurrentPage];
    [self animateIn];
}

- (void)close {
    [self.host removeChildWindow:self.panel];
    [self fadeOut];
    [self.host makeKeyAndOrderFront:nil];
}

- (void)windowDidResignKey:(NSNotification *)n {
    // Clicking outside closes it, like Arc; the window that took key keeps it.
    if (!self.panel.isVisible || self.panel.ignoresMouseEvents) return;
    [self.host removeChildWindow:self.panel];
    [self fadeOut];
}

#pragma mark Results delegate

- (void)resultsView:(TweakResultsView *)v activate:(NSInteger)row { [self activateRow:row forceNewTab:NO]; }

- (NSImage *)iconForItem:(TweakItem *)item {
    if (item.kind == TweakItemCommand || item.kind == TweakItemPage || item.kind == TweakItemSearch) return nil;
    return [self.sources faviconFor:item.url];
}

@end

#pragma mark - Public

static BOOL isBrowserWindow(NSWindow *w) { return w && [NSStringFromClass(w.class) isEqualToString:kDiaPlatformWindowClass]; }

BOOL TweakCommandBarShow(NSWindow *window, BOOL newTab) {
    if (!isBrowserWindow(window)) return NO;
    NSRect content = TweakCommandBarContentRect(window);
    // ⌘L without a sidebar pill: drop down from the top of the web content.
    NSRect anchor = newTab ? content
                  : NSMakeRect(NSMinX(content) + ArcSpace2, NSMaxY(content) - ArcSpace2 - ArcPillHeight, ArcEditorMaxWidth, ArcPillHeight);
    [[TweakCommandBar shared] showInWindow:window mode:newTab ? TweakCommandBarNewTab : TweakCommandBarCurrentTab anchor:anchor pinned:NO];
    return YES;
}

BOOL TweakCommandBarShowEditor(NSWindow *window, NSRect pillInWindow) {
    if (!isBrowserWindow(window) || NSIsEmptyRect(pillInWindow)) return NO;
    [[TweakCommandBar shared] showInWindow:window mode:TweakCommandBarCurrentTab anchor:[window convertRectToScreen:pillInWindow] pinned:YES];
    return YES;
}

static void installCommandBar(void) {
    TweakPaletteInstall();
    TweakSiteIconsInstall();
}

const TweakFeature TweakFeatureCommandBar = {"commandbar", {TWEAK_BROWSER_DIA}, NULL, installCommandBar};
