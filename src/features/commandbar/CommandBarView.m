// The command bar's views: the results list, the panel, and its tint.
#import "CommandBarInternal.h"

#pragma mark - Results list

@implementation TweakResultsView {
    NSPoint _lastMouse;   // screen; hover only follows a pointer that moved
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }

- (void)setItems:(NSArray<TweakItem *> *)items {
    _items = [items copy];
    _selected = items.count ? 0 : -1;
    _lastMouse = NSEvent.mouseLocation;   // new rows under a still pointer don't take the highlight
    self.needsDisplay = YES;
}
- (void)setSelected:(NSInteger)s { _selected = s; self.needsDisplay = YES; }
- (void)setMetrics:(TweakBarMetrics)m { _metrics = m; self.needsDisplay = YES; }

- (NSRect)rectForRow:(NSInteger)r {
    TweakBarMetrics m = self.metrics;
    return NSMakeRect(m.listInset, m.listInset + r * (m.rowHeight + m.rowGap), NSWidth(self.bounds) - m.listInset * 2, m.rowHeight);
}

- (NSInteger)rowAt:(NSPoint)p {
    for (NSInteger r = 0; r < (NSInteger)self.items.count; r++) if (NSPointInRect(p, [self rectForRow:r])) return r;
    return -1;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

- (void)mouseMoved:(NSEvent *)e {
    // Rows reflowing under a still pointer (typing, the panel resizing) must not take
    // the highlight away from the arrow keys.
    NSPoint screen = NSEvent.mouseLocation;
    if (NSEqualPoints(screen, _lastMouse)) return;
    _lastMouse = screen;
    NSInteger r = [self rowAt:[self convertPoint:e.locationInWindow fromView:nil]];
    if (r >= 0 && r != self.selected) self.selected = r;
}

- (void)mouseDown:(NSEvent *)e {
    NSInteger r = [self rowAt:[self convertPoint:e.locationInWindow fromView:nil]];
    if (r >= 0) [self.delegate resultsView:self activate:r];
}

static BOOL showsDetail(TweakItemKind k) {
    return k == TweakItemHistory || k == TweakItemBookmark || k == TweakItemPage || k == TweakItemSearch || k == TweakItemURL;
}

- (void)drawRect:(NSRect)dirty {
    NSMutableParagraphStyle *trunc = [NSMutableParagraphStyle new];
    trunc.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *ta = @{NSFontAttributeName: ArcFontPaletteRow(), NSForegroundColorAttributeName: NSColor.labelColor,
                         NSParagraphStyleAttributeName: trunc};
    CGFloat pad = (ArcChipSize - ArcFaviconSize) / 2;   // a favicon lines up with a chip's symbol
    for (NSInteger r = 0; r < (NSInteger)self.items.count; r++) {
        TweakItem *it = self.items[r];
        NSRect row = [self rectForRow:r];
        BOOL sel = r == self.selected;
        if (sel) {
            [ArcFillColor(ArcFillSelected) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:row xRadius:ArcRadiusMedium yRadius:ArcRadiusMedium] fill];
        }

        // Icon: a favicon, an action's symbol in a rounded square, or a plain symbol.
        NSRect iconRect = NSMakeRect(NSMinX(row) + ArcSpace2 + pad, round(NSMidY(row) - ArcFaviconSize / 2), ArcFaviconSize, ArcFaviconSize);
        NSImage *icon = [self.delegate iconForItem:it];
        if (it.kind == TweakItemCommand || it.kind == TweakItemPage) {
            NSRect chip = NSInsetRect(iconRect, -pad, -pad);
            [self drawChip:chip selected:sel];
            [self drawSymbol:ArcSymbol(it.symbol, ArcPillIcon, NSFontWeightMedium, nil) in:chip tint:sel ? NSColor.labelColor : ArcIconColor(YES)];
        } else if (icon) {
            [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        } else {
            [self drawSymbol:ArcSymbol(it.symbol, ArcPaletteSearchIcon, NSFontWeightRegular, nil) in:iconRect tint:ArcIconColor(YES)];
        }

        // Title, then "— detail" (truncated first). Open tabs end in "Switch to Tab" and an
        // arrow chip: full contrast on the highlighted row, tertiary elsewhere.
        CGFloat x = NSMaxX(iconRect) + pad + ArcSpace3, maxX = NSMaxX(row) - ArcSpace2;
        if (it.kind == TweakItemTab) {
            NSColor *accessory = sel ? NSColor.labelColor : ArcTextTertiary();
            NSRect chip = NSMakeRect(maxX - ArcChipSize, round(NSMidY(row) - ArcChipSize / 2), ArcChipSize, ArcChipSize);
            [self drawChip:chip selected:sel];
            [self drawSymbol:ArcSymbol(@"arrow.right", ArcPillIcon, NSFontWeightSemibold, @"Switch to Tab") in:chip tint:accessory];
            maxX = [self drawTrailing:it.detail font:ArcFontAccessory() color:accessory endingAt:NSMinX(chip) - ArcSpace2 row:row];
        } else if (it.kind == TweakItemCommand) {
            maxX = [self drawTrailing:it.detail font:ArcFontPaletteDetail() color:ArcTextTertiary() endingAt:maxX row:row];
        }
        NSString *title = it.title ?: @"";
        NSSize ts = [title sizeWithAttributes:ta];
        CGFloat titleW = MAX(0, MIN(ts.width, (maxX - x) * (showsDetail(it.kind) ? ArcRowTitleShare : 1)));
        [title drawInRect:NSMakeRect(x, NSMidY(row) - ts.height / 2, titleW, ts.height) withAttributes:ta];
        NSString *detail = nil;
        if (it.kind == TweakItemHistory || it.kind == TweakItemBookmark || it.kind == TweakItemPage) detail = [self prettyURL:it.url];
        else if (it.kind == TweakItemSearch || it.kind == TweakItemURL) detail = it.detail;
        if (detail.length) {
            NSDictionary *da = @{NSFontAttributeName: ArcFontPaletteDetail(), NSForegroundColorAttributeName: ArcTextTertiary(),
                                 NSParagraphStyleAttributeName: trunc};
            NSString *d = [@"— " stringByAppendingString:detail];
            NSSize ds = [d sizeWithAttributes:da];
            CGFloat dx = x + titleW + ArcSpace2;
            [d drawInRect:NSMakeRect(dx, NSMidY(row) - ds.height / 2, MAX(0, maxX - dx), ds.height) withAttributes:da];
        }
    }
}

- (void)drawChip:(NSRect)chip selected:(BOOL)sel {
    [ArcFillColor(sel ? ArcFillPressed : ArcFillTile) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:chip xRadius:ArcRadiusChip yRadius:ArcRadiusChip] fill];
}

// Draws `text` so it ends at `right`; returns where the title has to stop.
- (CGFloat)drawTrailing:(NSString *)text font:(NSFont *)font color:(NSColor *)color endingAt:(CGFloat)right row:(NSRect)row {
    if (!text.length) return right;
    NSDictionary *a = @{NSFontAttributeName: font, NSForegroundColorAttributeName: color};
    NSSize s = [text sizeWithAttributes:a];
    [text drawAtPoint:NSMakePoint(right - s.width, NSMidY(row) - s.height / 2) withAttributes:a];
    return right - s.width - ArcSpace4;
}

- (void)drawSymbol:(NSImage *)sym in:(NSRect)r tint:(NSColor *)tint {
    if (!sym) return;
    NSImage *tinted = [NSImage imageWithSize:sym.size flipped:NO drawingHandler:^BOOL(NSRect dst) {
        [sym drawInRect:dst];
        [tint set];
        NSRectFillUsingOperation(dst, NSCompositingOperationSourceAtop);
        return YES;
    }];
    NSSize s = sym.size;
    NSRect fit = NSMakeRect(NSMidX(r) - s.width / 2, NSMidY(r) - s.height / 2, s.width, s.height);
    [tinted drawInRect:fit fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
}

- (NSString *)prettyURL:(NSString *)u {
    NSString *s = u;
    for (NSString *p in @[@"https://", @"http://"]) if ([s hasPrefix:p]) s = [s substringFromIndex:p.length];
    if ([s hasPrefix:@"www."]) s = [s substringFromIndex:4];
    if ([s hasSuffix:@"/"]) s = [s substringToIndex:s.length - 1];
    return s;
}

@end

#pragma mark - Panel

@implementation TweakCommandPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return NO; }
@end

// Near-opaque on purpose (ArcPanelTint): see its note in ArcStyle.m.
@implementation TweakTintView
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r {
    [ArcPanelTint() setFill];
    NSRectFillUsingOperation(r, NSCompositingOperationSourceOver);
}
@end
