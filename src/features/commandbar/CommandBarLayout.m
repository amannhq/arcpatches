// Where the command bar sits, how big it is, and how it appears and leaves.
//   Palette (⌘T): centred over the web content, its top 30% of the way down.
//   Editor (⌘L):  its top-left on the URL pill's top-left, covering the pill.
#import "CommandBarInternal.h"
#import "Browser.h"
#import <QuartzCore/QuartzCore.h>

TweakBarMetrics TweakBarMetricsFor(BOOL editor) {
    if (editor) return (TweakBarMetrics){ArcPillHeight, ArcEditorRowHeight, 0, ArcSidebarInset, YES};
    return (TweakBarMetrics){ArcPaletteSearchHeight, ArcPaletteRowHeight, ArcPaletteRowGap, ArcSpace2, NO};
}

static void fade(NSWindow *w, CGFloat alpha, NSTimeInterval duration, CAMediaTimingFunction *timing, void (^done)(void));

#pragma mark - Web content

static void collectPanes(NSView *v, NSMutableArray<NSView *> *out) {
    if ([NSStringFromClass(v.class) isEqualToString:kDiaContentPaneClass]) {
        if (!v.isHiddenOrHasHiddenAncestor && NSWidth(v.bounds) > 1 && NSHeight(v.bounds) > 1) [out addObject:v];
        return;
    }
    for (NSView *s in v.subviews) collectPanes(s, out);
}

NSRect TweakCommandBarContentRect(NSWindow *window) {
    NSView *root = window.contentView.superview ?: window.contentView;
    NSMutableArray<NSView *> *panes = [NSMutableArray array];
    if (root) collectPanes(root, panes);
    NSRect r = NSZeroRect;   // window coordinates; a split view has several panes
    for (NSView *p in panes) {
        NSRect pr = [p convertRect:p.bounds toView:nil];
        r = NSIsEmptyRect(r) ? pr : NSUnionRect(r, pr);
    }
    // Panes parked off-window (other spaces) mustn't pull the centre away.
    NSRect whole = [window.contentView convertRect:window.contentView.bounds toView:nil];
    r = NSIntersectionRect(r, whole);
    if (NSIsEmptyRect(r)) r = whole;
    return [window convertRectToScreen:r];
}

@implementation TweakCommandBar (Layout)

- (BOOL)isEditor { return self.mode == TweakCommandBarCurrentTab; }

- (CGFloat)hairline { return 1.0 / MAX((CGFloat)1, self.host.backingScaleFactor); }

- (void)applyStyleForMode {
    BOOL editor = [self isEditor];
    // HUD material is always dark; use the light popover material in light mode so text stays readable.
    BOOL dark = [[self.host.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]]
                 isEqualToString:NSAppearanceNameDarkAqua];
    self.background.material = dark ? NSVisualEffectMaterialHUDWindow : NSVisualEffectMaterialPopover;
    self.background.layer.borderWidth = [self hairline];
    [self.host.effectiveAppearance performAsCurrentDrawingAppearance:^{
        self.background.layer.borderColor = ArcPanelBorder().CGColor;
    }];
    self.field.font = editor ? ArcFontURL() : ArcFontPaletteField();
    self.fieldIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:ArcPaletteSearchIcon weight:NSFontWeightRegular];
    self.results.metrics = TweakBarMetricsFor(editor);
}

- (NSRect)panelFrameForHeight:(CGFloat)height {
    NSRect a = self.anchor, host = self.host.frame;
    if ([self isEditor]) {
        // About 1.55× the sidebar (the pill plus its inset on each side), never past the window.
        CGFloat sidebar = self.pinnedToPill ? NSWidth(a) + 2 * ArcSidebarInset : NSWidth(a);
        CGFloat width = MIN(ArcEditorMaxWidth, MAX(ArcEditorMinWidth, sidebar * ArcEditorWidthRatio));
        width = MIN(width, NSMaxX(host) - NSMinX(a));
        if (self.pinnedToPill) width = MAX(width, NSWidth(a));   // always covers the pill
        return NSMakeRect(NSMinX(a), NSMaxY(a) - height, width, height);
    }
    CGFloat width = MIN(ArcPaletteWidth, NSWidth(a) - 2 * ArcPaletteMargin);
    CGFloat top = NSMaxY(a) - NSHeight(a) * ArcPaletteTopFraction;
    return NSMakeRect(round(NSMidX(a) - width / 2), round(top - height), width, height);
}

- (void)layoutForRows:(NSUInteger)rows {
    TweakBarMetrics m = TweakBarMetricsFor([self isEditor]);
    CGFloat listH = rows ? 2 * m.listInset + rows * m.rowHeight + (rows - 1) * m.rowGap : 0;
    CGFloat line = rows && !m.editor ? [self hairline] : 0;
    CGFloat height = m.inputHeight + line + listH;
    NSRect frame = [self panelFrameForHeight:height];
    [self.panel setFrame:frame display:YES];
    [self.panel invalidateShadow];   // the shadow follows the rounded panel as rows come and go
    CGFloat width = NSWidth(frame), mid = height - m.inputHeight / 2;

    CGFloat iconX = m.editor ? ArcSpace3 : ArcPaletteSearchInset;
    self.fieldIcon.frame = NSMakeRect(iconX, round(mid - ArcFaviconSize / 2), ArcFaviconSize, ArcFaviconSize);
    NSFont *font = self.field.font;
    CGFloat fieldH = ceil(font.ascender - font.descender + font.leading) + ArcSpace1 / 2;
    CGFloat fieldX = NSMaxX(self.fieldIcon.frame) + (m.editor ? ArcSpace2 : ArcSpace3);
    self.field.frame = NSMakeRect(fieldX, round(mid - fieldH / 2), width - fieldX - iconX, fieldH);
    self.divider.hidden = line == 0;
    self.divider.frame = NSMakeRect(0, height - m.inputHeight - line, width, line);
    self.results.frame = NSMakeRect(0, 0, width, listH);
}

#pragma mark - Motion

- (void)animateIn {
    NSPanel *p = self.panel;
    p.ignoresMouseEvents = NO;
    p.alphaValue = 0;
    CALayer *l = self.background.layer;
    if (l && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        // Grow from 0.98 around the centre (palette) or the top-left corner (editor, out of the pill).
        CGFloat s = ArcPaletteAppearScale, w = NSWidth(l.bounds), h = NSHeight(l.bounds);
        CGPoint fixed = [self isEditor] ? CGPointMake(0, l.geometryFlipped ? 0 : h) : CGPointMake(w / 2, h / 2);
        CGPoint anchor = CGPointMake(l.anchorPoint.x * w, l.anchorPoint.y * h);
        CATransform3D from = CATransform3DMakeTranslation((fixed.x - anchor.x) * (1 - s), (fixed.y - anchor.y) * (1 - s), 0);
        from = CATransform3DScale(from, s, s, 1);
        CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"transform"];
        grow.fromValue = [NSValue valueWithCATransform3D:from];
        grow.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
        grow.duration = ArcDurationMedium;
        grow.timingFunction = ArcEaseOut();
        [l addAnimation:grow forKey:@"arcpatches.appear"];
    }
    fade(p, 1, ArcDurationMedium, ArcEaseOut(), nil);
}

// Fades run even with Reduce Motion on (only the scale is motion), so not through ArcAnimate.
static void fade(NSWindow *w, CGFloat alpha, NSTimeInterval duration, CAMediaTimingFunction *timing, void (^done)(void)) {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        ctx.duration = duration;
        ctx.timingFunction = timing;
        w.animator.alphaValue = alpha;
    } completionHandler:done];
}

- (void)fadeOut {
    NSPanel *p = self.panel;
    if (!p.isVisible) return;
    NSUInteger generation = self.showGeneration;
    p.ignoresMouseEvents = YES;   // a click during the fade reaches the page, not a dying row
    __weak typeof(self) weakSelf = self;
    fade(p, 0, ArcDurationFast, ArcEaseIn(), ^{
        if (weakSelf.showGeneration != generation) return;   // shown again meanwhile
        [p orderOut:nil];
        p.alphaValue = 1;
    });
}

@end
