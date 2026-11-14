#import "SiteControlsViews.h"
#import "ChromeButton.h"
#import <QuartzCore/QuartzCore.h>

static void setFill(NSView *v, NSColor *color) {
    [v.effectiveAppearance performAsCurrentDrawingAppearance:^{ v.layer.backgroundColor = color.CGColor; }];
}

#pragma mark - Button

@interface TweakSiteButton ()
@property (nonatomic, readwrite) BOOL hovering, pressed;
@end

@implementation TweakSiteButton

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.bordered = NO;
    self.title = @"";
    self.refusesFirstResponder = YES;
    self.focusRingType = NSFocusRingTypeNone;
    [(NSButtonCell *)self.cell setHighlightsBy:NSNoCellMask];   // our pressed fill replaces AppKit's darkening
    self.wantsLayer = YES;
    ArcRound(self.layer, ArcRadiusMedium);
    return self;
}

// Subclasses pick their fills.
- (NSColor *)restFill { return NSColor.clearColor; }
- (NSColor *)hoverFill { return ArcFillColor(ArcFillHover); }

- (void)updateFill:(BOOL)animated {
    NSColor *c = self.pressed ? ArcFillColor(ArcFillPressed) : self.hovering ? self.hoverFill : self.restFill;
    TweakChromeSetFill(self, self.layer, c, animated);
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
}

// The pointer may have left (or the popover closed) during a click: look again.
- (void)syncHover {
    NSWindow *w = self.window;
    BOOL inside = w && !self.isHiddenOrHasHiddenAncestor
        && NSPointInRect([self convertPoint:w.mouseLocationOutsideOfEventStream fromView:nil], self.bounds);
    if (inside == self.hovering) return;
    self.hovering = inside;
    [self updateFill:YES];
}

- (void)mouseEntered:(NSEvent *)e { [self syncHover]; }
- (void)mouseExited:(NSEvent *)e { [self syncHover]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; [self updateFill:NO]; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateFill:NO]; }

// NSButton tracks the click inside -mouseDown:, so the pressed fill wraps it.
- (void)mouseDown:(NSEvent *)e {
    if (!self.isEnabled) return;
    self.pressed = YES;
    [self updateFill:NO];
    [CATransaction flush];
    [super mouseDown:e];
    self.pressed = NO;
    [self updateFill:YES];
    [self syncHover];
}

@end

#pragma mark - Tile

@implementation TweakSiteTile

+ (instancetype)tileWithImage:(NSImage *)image label:(NSString *)label target:(id)target action:(SEL)action {
    TweakSiteTile *t = [[self alloc] initWithFrame:NSZeroRect];
    t.image = image;
    t.imagePosition = NSImageOnly;
    t.imageScaling = NSImageScaleProportionallyDown;
    t.target = target;
    t.action = action;
    t.toolTip = label;
    t.accessibilityLabel = label;
    t.contentTintColor = NSColor.labelColor;
    t.radius = ArcRadiusMedium;
    [t updateFill:NO];
    return t;
}

+ (instancetype)tileWithSymbol:(NSString *)symbol label:(NSString *)label target:(id)target action:(SEL)action {
    TweakSiteTile *t = [self tileWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:label]
                                     label:label target:target action:action];
    t.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:ArcTileIcon weight:NSFontWeightRegular];
    return t;
}

- (void)setRadius:(CGFloat)radius { _radius = radius; ArcRound(self.layer, radius); }
- (NSColor *)restFill { return ArcFillColor(ArcFillTile); }

@end

#pragma mark - Row

@interface TweakSiteRow ()
@property (nonatomic, strong) NSView *circle;
@end

@implementation TweakSiteRow

+ (instancetype)rowWithSymbol:(NSString *)symbol title:(NSString *)title subtitle:(NSString *)subtitle target:(id)target action:(SEL)action {
    CGFloat h = ArcRowHeight, d = ArcRowIconCircle, inset = (h - d) / 2;
    TweakSiteRow *r = [[self alloc] initWithFrame:NSMakeRect(0, 0, 100, h)];
    r.target = target;
    r.action = action;
    r.accessibilityLabel = subtitle.length ? [NSString stringWithFormat:@"%@, %@", title, subtitle] : title;

    r.circle = [[NSView alloc] initWithFrame:NSMakeRect(inset, inset, d, d)];
    r.circle.wantsLayer = YES;
    r.circle.layer.cornerRadius = d / 2;
    [r addSubview:r.circle];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:ArcPillIcon weight:NSFontWeightMedium];
    icon.contentTintColor = NSColor.labelColor;
    icon.frame = r.circle.bounds;
    [r.circle addSubview:icon];

    NSTextField *t = [NSTextField labelWithString:title ?: @""];
    t.font = ArcFontRowTitle();
    t.lineBreakMode = NSLineBreakByTruncatingTail;
    NSTextField *s = [NSTextField labelWithString:subtitle ?: @""];
    s.font = ArcFontRowSubtitle();
    s.textColor = ArcTextSecondary();
    s.lineBreakMode = NSLineBreakByTruncatingMiddle;
    t.autoresizingMask = s.autoresizingMask = NSViewWidthSizable;
    BOOL two = subtitle.length > 0;
    CGFloat x = inset + d + ArcSpace2, th = ceil(t.cell.cellSize.height), sh = ceil(s.cell.cellSize.height);
    CGFloat sy = round((h - th - sh) / 2);   // the pair centred, subtitle below (unflipped)
    t.frame = NSMakeRect(x, two ? sy + sh : round((h - th) / 2), 100 - x, th);
    s.frame = NSMakeRect(x, sy, 100 - x, sh);
    s.hidden = !two;
    [r addSubview:t];
    [r addSubview:s];
    [r updateFill:NO];
    return r;
}

- (BOOL)isFlipped { return NO; }
- (NSView *)hitTest:(NSPoint)p { return NSPointInRect([self.superview convertPoint:p toView:self], self.bounds) ? self : nil; }
- (void)drawRect:(NSRect)r {}   // no button bezel or title: the subviews are the content

- (void)updateFill:(BOOL)animated {
    [super updateFill:animated];
    setFill(self.circle, ArcFillColor(ArcFillHover));
}

@end

#pragma mark - Header and badge

NSTextField *TweakSiteSectionHeader(NSString *title) {
    NSTextField *l = [NSTextField labelWithString:title];
    l.font = ArcFontSectionHeader();
    l.textColor = ArcTextSecondary();
    return l;
}

@interface TweakSiteBadge : NSView
@end

@implementation TweakSiteBadge
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; setFill(self, ArcFillColor(ArcFillRest)); }
@end

NSView *TweakSiteSecurityBadge(BOOL secure) {
    TweakSiteBadge *b = [[TweakSiteBadge alloc] initWithFrame:NSZeroRect];
    b.wantsLayer = YES;
    NSString *text = secure ? @"Secure" : @"Not secure";
    CGFloat iconPt = ArcFontRowSubtitle().pointSize, iconBox = iconPt + 3, h = ArcBadgeHeight, x = ArcSpace2 + 2;
    NSImageView *icon = [NSImageView imageViewWithImage:
        [NSImage imageWithSystemSymbolName:secure ? @"lock.fill" : @"lock.open" accessibilityDescription:nil]];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:iconPt weight:NSFontWeightMedium];
    icon.contentTintColor = secure ? ArcTextSecondary() : NSColor.systemOrangeColor;
    NSTextField *l = [NSTextField labelWithString:text];
    l.font = ArcFontChip();
    l.textColor = ArcTextSecondary();
    [l sizeToFit];
    icon.frame = NSMakeRect(x, (h - iconBox) / 2, iconBox, iconBox);
    x += iconBox + ArcSpace1;
    l.frame = NSMakeRect(x, (h - NSHeight(l.frame)) / 2, NSWidth(l.frame), NSHeight(l.frame));
    b.frame = NSMakeRect(0, 0, NSMaxX(l.frame) + ArcSpace2 + 2, h);
    ArcRound(b.layer, h / 2);
    [b addSubview:icon];
    [b addSubview:l];
    b.accessibilityElement = YES;
    b.accessibilityRole = NSAccessibilityStaticTextRole;
    b.accessibilityLabel = text;
    setFill(b, ArcFillColor(ArcFillRest));
    return b;
}
