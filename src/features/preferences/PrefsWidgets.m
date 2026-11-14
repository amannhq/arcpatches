// The settings pane's building blocks: labels, rows, groups and switches.
#import "PrefsPane.h"

static NSColor *dyn(CGFloat darkWhite, CGFloat darkAlpha, CGFloat lightWhite, CGFloat lightAlpha) {
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) {
        BOOL dark = [[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        return dark ? [NSColor colorWithWhite:darkWhite alpha:darkAlpha] : [NSColor colorWithWhite:lightWhite alpha:lightAlpha];
    }];
}

@implementation TweakGroupView
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    self.layer.cornerRadius = 10;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.backgroundColor = dyn(1, 0.05, 0, 0.035).CGColor;
    self.layer.borderWidth = 1;
    self.layer.borderColor = dyn(1, 0.06, 0, 0.06).CGColor;
}
@end

@implementation TweakFlippedView
- (BOOL)isFlipped { return YES; }
@end

@implementation TweakPrefsPane (Widgets)

- (NSTextField *)label:(NSString *)s size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color {
    NSTextField *t = [NSTextField wrappingLabelWithString:s];
    t.font = [NSFont systemFontOfSize:size weight:weight];
    t.textColor = color;
    t.selectable = NO;
    return t;
}

- (NSView *)rowWithTitle:(NSString *)title detail:(NSString *)detail control:(NSView *)control key:(NSString *)key {
    NSStackView *texts = [NSStackView stackViewWithViews:@[[self label:title size:13 weight:NSFontWeightRegular color:NSColor.labelColor]]];
    texts.orientation = NSUserInterfaceLayoutOrientationVertical;
    texts.alignment = NSLayoutAttributeLeading;
    texts.spacing = 3;
    if (detail) [texts addArrangedSubview:[self label:detail size:11 weight:NSFontWeightRegular color:NSColor.secondaryLabelColor]];
    [texts setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [texts setHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *row = [NSStackView stackViewWithViews:@[texts, control]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 20;
    [control setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    if (key) self.rowsByKey[key] = @[texts, control];

    // Explicit padding (stack edge insets aren't honoured for wrapping labels).
    // Matches Dia's grouped settings: 12 pt above/below, 14 pt at the sides.
    NSView *cell = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [cell addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.topAnchor constraintEqualToAnchor:cell.topAnchor constant:12],
        [row.bottomAnchor constraintEqualToAnchor:cell.bottomAnchor constant:-12],
        [row.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:14],
        [row.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-14],
        [cell.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    ]];
    return cell;
}

- (NSView *)groupWithRows:(NSArray<NSView *> *)rows {
    TweakGroupView *g = [[TweakGroupView alloc] initWithFrame:NSZeroRect];
    g.wantsLayer = YES;
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < rows.count; i++) {
        if (i) {
            NSBox *sep = [[NSBox alloc] initWithFrame:NSZeroRect];
            sep.boxType = NSBoxSeparator;
            [items addObject:sep];
        }
        [items addObject:rows[i]];
    }
    NSStackView *stack = [NSStackView stackViewWithViews:items];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeWidth;
    stack.spacing = 0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [g addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:g.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],
    ]];
    for (NSView *sep in items)
        if ([sep isKindOfClass:NSBox.class])
            [sep.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor constant:14].active = YES;
    return g;
}

- (NSSwitch *)switchForKey:(NSString *)key {
    NSSwitch *s = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    s.controlSize = NSControlSizeSmall;
    s.target = self;
    s.action = @selector(switchChanged:);
    s.identifier = key;
    self.switches[key] = s;
    return s;
}

@end
