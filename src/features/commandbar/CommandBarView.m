// The command bar's views: the results list, the panel, and its tint.
#import "CommandBarInternal.h"

#pragma mark - Results list

@implementation TweakResultsView

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }

- (void)setItems:(NSArray<TweakItem *> *)items { _items = [items copy]; _selected = items.count ? 0 : -1; self.needsDisplay = YES; }
- (void)setSelected:(NSInteger)s { _selected = s; self.needsDisplay = YES; }

- (NSRect)rectForRow:(NSInteger)r {
    return NSMakeRect(kListInset, kListInset + r * kRowHeight, NSWidth(self.bounds) - kListInset * 2, kRowHeight);
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
    NSInteger r = [self rowAt:[self convertPoint:e.locationInWindow fromView:nil]];
    if (r >= 0 && r != self.selected) self.selected = r;
}

- (void)mouseDown:(NSEvent *)e {
    NSInteger r = [self rowAt:[self convertPoint:e.locationInWindow fromView:nil]];
    if (r >= 0) [self.delegate resultsView:self activate:r];
}

- (void)drawRect:(NSRect)dirty {
    NSFont *titleFont = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    NSFont *detailFont = [NSFont systemFontOfSize:15 weight:NSFontWeightRegular];
    NSMutableParagraphStyle *trunc = [NSMutableParagraphStyle new];
    trunc.lineBreakMode = NSLineBreakByTruncatingMiddle;
    for (NSInteger r = 0; r < (NSInteger)self.items.count; r++) {
        TweakItem *it = self.items[r];
        NSRect row = [self rectForRow:r];
        if (r == self.selected) {
            [dyn(1, 0.10, 0, 0.07) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:row xRadius:10 yRadius:10] fill];
        }

        // Icon: favicon, or a symbol (commands get a filled tile, like Arc).
        NSRect iconRect = NSMakeRect(NSMinX(row) + 14, NSMidY(row) - 10, 20, 20);
        NSImage *icon = [self.delegate iconForItem:it];
        if (it.kind == TweakItemCommand || it.kind == TweakItemPage) {
            NSRect tile = NSInsetRect(iconRect, -4, -4);
            [(it.kind == TweakItemCommand ? NSColor.labelColor : dyn(1, 0.14, 0, 0.08)) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:tile xRadius:7 yRadius:7] fill];
            NSImage *sym = [[NSImage imageWithSystemSymbolName:it.symbol accessibilityDescription:nil]
                            imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium]];
            NSColor *tint = it.kind == TweakItemCommand ? NSColor.windowBackgroundColor : NSColor.labelColor;
            [self drawSymbol:sym in:iconRect tint:tint];
        } else if (icon) {
            if (r == self.selected) {
                // Selected favicons sit on a white tile, like Arc.
                [NSColor.whiteColor setFill];
                [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(iconRect, -4, -4) xRadius:7 yRadius:7] fill];
            }
            [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        } else {
            NSImage *sym = [[NSImage imageWithSystemSymbolName:it.symbol accessibilityDescription:nil]
                            imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular]];
            [self drawSymbol:sym in:iconRect tint:NSColor.secondaryLabelColor];
        }

        // Title — detail, with the detail truncated first.
        CGFloat x = NSMaxX(iconRect) + 16, maxX = NSMaxX(row) - 16;
        NSString *right = it.kind == TweakItemCommand ? it.detail : nil;
        if (it.kind == TweakItemTab) {
            // "Switch to Tab" + arrow chip; bright when selected.
            BOOL sel = r == self.selected;
            NSRect chip = NSMakeRect(maxX - 28 + 4, NSMidY(row) - 14, 28, 28);
            [(sel ? NSColor.labelColor : dyn(1, 0.16, 0, 0.09)) setFill];
            [[NSBezierPath bezierPathWithRoundedRect:chip xRadius:7 yRadius:7] fill];
            NSImage *arrow = [[NSImage imageWithSystemSymbolName:@"arrow.right" accessibilityDescription:@"Switch to Tab"]
                              imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightSemibold]];
            [self drawSymbol:arrow in:chip tint:sel ? NSColor.windowBackgroundColor : NSColor.secondaryLabelColor];
            NSDictionary *ra = @{NSFontAttributeName: sel ? titleFont : detailFont,
                                 NSForegroundColorAttributeName: sel ? NSColor.labelColor : detailColor()};
            NSSize rs = [it.detail sizeWithAttributes:ra];
            [it.detail drawAtPoint:NSMakePoint(NSMinX(chip) - 12 - rs.width, NSMidY(row) - rs.height / 2) withAttributes:ra];
            maxX = NSMinX(chip) - 12 - rs.width - 16;
        }
        if (right.length) {
            NSDictionary *ra = @{NSFontAttributeName: detailFont, NSForegroundColorAttributeName: detailColor()};
            NSSize rs = [right sizeWithAttributes:ra];
            [right drawAtPoint:NSMakePoint(maxX - rs.width, NSMidY(row) - rs.height / 2) withAttributes:ra];
            maxX -= rs.width + 16;
        }
        NSDictionary *ta = @{NSFontAttributeName: titleFont, NSForegroundColorAttributeName: NSColor.labelColor, NSParagraphStyleAttributeName: trunc};
        NSString *title = it.title ?: @"";
        NSSize ts = [title sizeWithAttributes:ta];
        CGFloat titleW = MIN(ts.width, (maxX - x) * 0.6);
        if (!(it.kind == TweakItemHistory || it.kind == TweakItemBookmark || it.kind == TweakItemPage || it.kind == TweakItemSearch || it.kind == TweakItemURL)) titleW = MIN(ts.width, maxX - x);
        [title drawInRect:NSMakeRect(x, NSMidY(row) - ts.height / 2, titleW, ts.height) withAttributes:ta];
        NSString *detail = nil;
        if (it.kind == TweakItemHistory || it.kind == TweakItemBookmark || it.kind == TweakItemPage) detail = [self prettyURL:it.url];
        else if (it.kind == TweakItemSearch || it.kind == TweakItemURL) detail = it.detail;
        if (detail.length) {
            NSDictionary *da = @{NSFontAttributeName: detailFont, NSForegroundColorAttributeName: detailColor(), NSParagraphStyleAttributeName: trunc};
            NSString *d = [@"— " stringByAppendingString:detail];
            NSSize ds = [d sizeWithAttributes:da];
            CGFloat dx = x + titleW + 8;
            [d drawInRect:NSMakeRect(dx, NSMidY(row) - ds.height / 2, MAX(0, maxX - dx), ds.height) withAttributes:da];
        }
    }
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

@implementation TweakTintView
- (BOOL)isOpaque { return NO; }
- (NSView *)hitTest:(NSPoint)p { return nil; }
- (void)drawRect:(NSRect)r {
    [dyn(0.11, 0.94, 0.98, 0.94) setFill];
    NSRectFillUsingOperation(r, NSCompositingOperationSourceOver);
}
@end
