#import "SiteControlsViews.h"
#import "SidebarViews.h"

static void trackHover(NSView *v) {
    for (NSTrackingArea *t in v.trackingAreas) [v removeTrackingArea:t];
    [v addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:v userInfo:nil]];
}

static void setFill(NSView *v, NSColor *color) {
    [v.effectiveAppearance performAsCurrentDrawingAppearance:^{ v.layer.backgroundColor = color.CGColor; }];
}

#pragma mark - Tile

@interface TweakSiteTile ()
@property (nonatomic) BOOL hovering;
@end

@implementation TweakSiteTile

+ (instancetype)tileWithImage:(NSImage *)image label:(NSString *)label target:(id)target action:(SEL)action {
    TweakSiteTile *t = [[self alloc] initWithFrame:NSZeroRect];
    t.bordered = NO;
    t.title = @"";
    t.image = image;
    t.imagePosition = NSImageOnly;
    t.imageScaling = NSImageScaleProportionallyDown;
    t.target = target;
    t.action = action;
    t.toolTip = label;
    t.accessibilityLabel = label;
    t.refusesFirstResponder = YES;
    t.focusRingType = NSFocusRingTypeNone;
    t.contentTintColor = NSColor.labelColor;
    t.wantsLayer = YES;
    t.radius = 8;
    t.layer.cornerCurve = kCACornerCurveContinuous;
    [t updateFill];
    return t;
}

+ (instancetype)tileWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action {
    TweakSiteTile *t = [self tileWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label]
                                     label:label target:target action:action];
    t.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightRegular];
    return t;
}

- (void)setRadius:(CGFloat)radius { _radius = radius; self.layer.cornerRadius = radius; }
- (void)updateTrackingAreas { [super updateTrackingAreas]; trackHover(self); }
- (void)mouseEntered:(NSEvent *)e { self.hovering = YES; [self updateFill]; }
- (void)mouseExited:(NSEvent *)e { self.hovering = NO; [self updateFill]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateFill]; }
- (void)updateFill { setFill(self, self.hovering ? TweakPillFill(0.14, 0.09) : TweakPillFill(0.07, 0.045)); }

@end

#pragma mark - Row

@interface TweakSiteRow ()
@property (nonatomic) BOOL hovering;
@property (nonatomic, strong) NSView *circle;
@end

@implementation TweakSiteRow

+ (instancetype)rowWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle target:(id)target action:(SEL)action {
    TweakSiteRow *r = [[self alloc] initWithFrame:NSMakeRect(0, 0, 100, 44)];
    r.bordered = NO;
    r.title = @"";
    r.target = target;
    r.action = action;
    r.accessibilityLabel = subtitle.length ? [NSString stringWithFormat:@"%@, %@", title, subtitle] : title;
    r.refusesFirstResponder = YES;
    r.focusRingType = NSFocusRingTypeNone;
    r.wantsLayer = YES;
    r.layer.cornerRadius = 8;
    r.layer.cornerCurve = kCACornerCurveContinuous;

    r.circle = [[NSView alloc] initWithFrame:NSMakeRect(6, 6, 32, 32)];
    r.circle.wantsLayer = YES;
    r.circle.layer.cornerRadius = 16;
    [r addSubview:r.circle];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium];
    icon.contentTintColor = NSColor.labelColor;
    icon.frame = r.circle.bounds;
    [r.circle addSubview:icon];

    NSTextField *t = [NSTextField labelWithString:title ?: @""];
    t.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    t.lineBreakMode = NSLineBreakByTruncatingTail;
    NSTextField *s = [NSTextField labelWithString:subtitle ?: @""];
    s.font = [NSFont systemFontOfSize:11];
    s.textColor = NSColor.secondaryLabelColor;
    s.lineBreakMode = NSLineBreakByTruncatingMiddle;
    t.autoresizingMask = s.autoresizingMask = NSViewWidthSizable;
    BOOL two = subtitle.length > 0;
    t.frame = NSMakeRect(48, two ? 22 : 13, 52, 17);
    s.frame = NSMakeRect(48, 6, 52, 15);
    s.hidden = !two;
    [r addSubview:t];
    [r addSubview:s];
    [r updateFill];
    return r;
}

- (BOOL)isFlipped { return NO; }
- (NSView *)hitTest:(NSPoint)p { return NSPointInRect([self.superview convertPoint:p toView:self], self.bounds) ? self : nil; }
- (void)updateTrackingAreas { [super updateTrackingAreas]; trackHover(self); }
- (void)mouseEntered:(NSEvent *)e { self.hovering = YES; [self updateFill]; }
- (void)mouseExited:(NSEvent *)e { self.hovering = NO; [self updateFill]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateFill]; }
- (void)drawRect:(NSRect)r {}   // no button bezel or title: the subviews are the content

- (void)updateFill {
    setFill(self, self.hovering ? TweakPillFill(0.08, 0.05) : NSColor.clearColor);
    setFill(self.circle, TweakPillFill(0.12, 0.07));
}

@end

#pragma mark - Header and badge

NSTextField *TweakSiteSectionHeader(NSString *title) {
    NSTextField *l = [NSTextField labelWithString:title];
    l.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    l.textColor = NSColor.secondaryLabelColor;
    return l;
}

@interface TweakSiteBadge : NSView
@end

@implementation TweakSiteBadge
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; setFill(self, TweakPillFill(0.08, 0.05)); }
@end

NSView *TweakSiteSecurityBadge(BOOL secure) {
    TweakSiteBadge *b = [[TweakSiteBadge alloc] initWithFrame:NSZeroRect];
    b.wantsLayer = YES;
    NSString *text = secure ? @"Secure" : @"Not secure";
    NSImageView *icon = [NSImageView imageViewWithImage:
        [NSImage imageWithSystemSymbolName:secure ? @"lock.fill" : @"lock.open" accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightMedium];
    icon.contentTintColor = secure ? NSColor.secondaryLabelColor : NSColor.systemOrangeColor;
    NSTextField *l = [NSTextField labelWithString:text];
    l.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    l.textColor = NSColor.secondaryLabelColor;
    [l sizeToFit];
    CGFloat h = 26, x = 10;
    icon.frame = NSMakeRect(x, (h - 14) / 2, 14, 14);
    x += 14 + 5;
    l.frame = NSMakeRect(x, (h - NSHeight(l.frame)) / 2, NSWidth(l.frame), NSHeight(l.frame));
    b.frame = NSMakeRect(0, 0, NSMaxX(l.frame) + 11, h);
    b.layer.cornerRadius = h / 2;
    [b addSubview:icon];
    [b addSubview:l];
    b.accessibilityElement = YES;
    b.accessibilityRole = NSAccessibilityStaticTextRole;
    b.accessibilityLabel = text;
    setFill(b, TweakPillFill(0.08, 0.05));
    return b;
}
