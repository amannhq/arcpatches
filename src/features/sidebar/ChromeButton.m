// The shared Arc-style icon button (ChromeButton.h).
#import "ChromeButton.h"
#import <QuartzCore/QuartzCore.h>

static BOOL reduceMotion(void) { return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; }

void TweakChromeSetFill(NSView *view, CALayer *layer, NSColor *color, BOOL animated) {
    if (!layer) return;
    __block CGColorRef to = NULL;
    [view.effectiveAppearance performAsCurrentDrawingAppearance:^{ to = CGColorRetain(color.CGColor); }];
    if (to && layer.backgroundColor && CGColorEqualToColor(layer.backgroundColor, to)) { CGColorRelease(to); return; }
    // Views' own layers don't animate implicitly: animate from what is on screen now.
    if (animated && !reduceMotion() && view.window) {
        CALayer *shown = layer.presentationLayer ?: layer;
        CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        a.fromValue = (__bridge id)(shown.backgroundColor ?: NSColor.clearColor.CGColor);
        a.toValue = (__bridge id)to;
        a.duration = ArcDurationFast;
        a.timingFunction = ArcEaseOut();
        [layer addAnimation:a forKey:@"arcFill"];
    } else {
        [layer removeAnimationForKey:@"arcFill"];
    }
    layer.backgroundColor = to;
    CGColorRelease(to);
}

void TweakChromeCrossfade(CALayer *layer) {
    if (!layer || reduceMotion()) return;
    CATransition *t = [CATransition animation];
    t.type = kCATransitionFade;
    t.duration = ArcDurationMedium;
    [layer addAnimation:t forKey:@"arcCrossfade"];
}

void TweakChromeFade(NSView *v, BOOL shown) {
    if (shown && v.hidden) { v.alphaValue = 0; v.hidden = NO; }
    if (v.hidden) return;
    ArcAnimate(ArcDurationFast, shown, ^(__unused NSAnimationContext *ctx) { v.animator.alphaValue = shown ? 1 : 0; },
               ^{ if (v.alphaValue < 0.01) v.hidden = YES; });
}

@interface TweakChromeButton ()
@property (nonatomic, readwrite) BOOL hovering;
@property (nonatomic) BOOL pressed;
@end

@implementation TweakChromeButton

+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label pointSize:(CGFloat)size
                          radius:(CGFloat)radius target:(id)target action:(SEL)action {
    TweakChromeButton *b = [[self alloc] initWithFrame:NSZeroRect];
    b.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightRegular];
    ArcRound(b.layer, radius);
    b.target = target;
    b.action = action;
    [b setLabel:label];
    b.symbol = symbol;
    return b;
}

- (instancetype)initWithFrame:(NSRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.bordered = NO;
    self.title = @"";
    self.imagePosition = NSImageOnly;
    self.imageScaling = NSImageScaleNone;
    self.refusesFirstResponder = YES;   // never take focus from the page
    self.focusRingType = NSFocusRingTypeNone;
    [(NSButtonCell *)self.cell setHighlightsBy:NSNoCellMask];   // our pressed state replaces AppKit's darkening
    self.wantsLayer = YES;
    ArcRound(self.layer, ArcRadiusMedium);
    [self updateLook:NO];
    return self;
}

- (void)setLabel:(NSString *)label {
    self.toolTip = label;
    self.accessibilityLabel = label;
}

- (void)setSymbol:(NSString *)symbol { [self setSymbol:symbol animated:NO]; }

- (void)setSymbol:(NSString *)symbol animated:(BOOL)animated {
    if ([symbol isEqualToString:_symbol]) return;
    _symbol = [symbol copy];
    if (animated && self.window) TweakChromeCrossfade(self.layer);
    self.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:self.accessibilityLabel];
}

// AppKit draws the image in a private subview; turn that view's layer about its centre.
- (void)spinIcon {
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) return;
    NSView *icon = nil;
    for (NSView *v in self.subviews)
        if ([NSStringFromClass(v.class) containsString:@"ImageView"]) { icon = v; break; }
    if (!icon) return;
    icon.wantsLayer = YES;
    CALayer *l = icon.layer;
    NSRect f = icon.frame;
    l.anchorPoint = CGPointMake(0.5, 0.5);
    l.position = CGPointMake(NSMidX(f), NSMidY(f));
    CABasicAnimation *turn = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    turn.fromValue = @0;
    turn.toValue = @(icon.isFlipped ? 2 * M_PI : -2 * M_PI);   // clockwise on screen
    turn.duration = ArcSpinDuration;
    turn.timingFunction = ArcEaseOut();
    [l addAnimation:turn forKey:@"arcpatches.spin"];
}

- (void)setSelected:(BOOL)selected {
    if (_selected == selected) return;
    _selected = selected;
    [self updateLook:YES];
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled == self.isEnabled) return;
    [super setEnabled:enabled];
    if (!enabled) self.pressed = NO;
    [self updateLook:YES];
}

#pragma mark Look

- (void)updateLook:(BOOL)animated {
    BOOL enabled = self.isEnabled;
    ArcFill fill = self.pressed ? ArcFillPressed : self.selected ? ArcFillSelected : ArcFillHover;
    BOOL filled = enabled && (self.pressed || self.selected || self.hovering);
    TweakChromeSetFill(self, self.layer, filled ? ArcFillColor(fill) : NSColor.clearColor, animated);
    NSColor *tint = ArcIconColor(enabled);
    self.contentTintColor = self.pressed ? [tint colorWithAlphaComponent:0.7] : tint;
}

- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self updateLook:NO]; }

#pragma mark Hover

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    for (NSTrackingArea *t in self.trackingAreas) [self removeTrackingArea:t];
    [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect owner:self userInfo:nil]];
    [self syncHover];   // Dia moved us under a still pointer: no enter/exit comes
}

// Dia relayouts and re-parents the sidebar often, which can drop an exit event: every
// hover event re-reads where the pointer really is.
- (void)syncHover {
    NSWindow *w = self.window;
    BOOL inside = NO;
    if (w && !self.isHiddenOrHasHiddenAncestor && self.alphaValue > 0.01) {
        NSPoint p = [self convertPoint:w.mouseLocationOutsideOfEventStream fromView:nil];
        inside = NSPointInRect(p, self.bounds);
    }
    if (inside == self.hovering) return;
    self.hovering = inside;
    [self updateLook:YES];
}

// Fading out (alpha already 0, `hidden` still NO): never take a stray click.
- (NSView *)hitTest:(NSPoint)p { return self.alphaValue < 0.01 ? nil : [super hitTest:p]; }

- (void)mouseEntered:(NSEvent *)e { [self syncHover]; }
- (void)mouseExited:(NSEvent *)e { [self syncHover]; }
- (void)mouseMoved:(NSEvent *)e { [self syncHover]; }
- (void)viewDidHide { [super viewDidHide]; self.hovering = NO; self.pressed = NO; [self updateLook:NO]; }
- (void)viewDidUnhide { [super viewDidUnhide]; [self syncHover]; }
- (void)viewDidMoveToWindow { [super viewDidMoveToWindow]; self.hovering = NO; [self updateLook:NO]; [self syncHover]; }

#pragma mark Press

// NSButton tracks the click inside -mouseDown:, so the pressed look wraps it.
- (void)mouseDown:(NSEvent *)e {
    if (!self.isEnabled) return;
    self.pressed = YES;
    [self updateLook:NO];
    [CATransaction flush];
    [super mouseDown:e];
    self.pressed = NO;
    [self updateLook:YES];
    [self syncHover];
}

// Middle click: pressed while down, the action on release inside (it reads the event's
// type from NSApp.currentEvent, e.g. back/forward/reload "in a new tab").
// Tracked here, like NSButton tracks a left click, so the pressed look can't stick.
- (void)otherMouseDown:(NSEvent *)e {
    if (e.buttonNumber != 2 || !self.isEnabled) { [super otherMouseDown:e]; return; }
    self.pressed = YES;
    [self updateLook:NO];
    NSEvent *up = nil;
    while ((up = [self.window nextEventMatchingMask:NSEventMaskOtherMouseUp | NSEventMaskOtherMouseDragged])) {
        if (up.type == NSEventTypeOtherMouseUp && up.buttonNumber == 2) break;
    }
    self.pressed = NO;
    [self updateLook:YES];
    if (up && self.isEnabled && NSPointInRect([self convertPoint:up.locationInWindow fromView:nil], self.bounds))
        [self sendAction:self.action to:self.target];
    [self syncHover];
}

@end
