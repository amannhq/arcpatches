#import "FullScreenButtons.h"
#import "ArcStyle.h"
#import <objc/runtime.h>

static const void *kStripKey = &kStripKey;
static const void *kMinimizeOffKey = &kMinimizeOffKey;
static const NSTimeInterval kPollInterval = 0.08;   // cheap: one pointer read while in full screen

#pragma mark - Strip

@interface TweakFullScreenStrip : NSVisualEffectView
@property (nonatomic, weak) NSWindow *owner;
@property (nonatomic, strong) NSTimer *poll;
@property (nonatomic) BOOL shown;
@end

@implementation TweakFullScreenStrip

- (instancetype)initForWindow:(NSWindow *)w {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    _owner = w;
    self.material = NSVisualEffectMaterialTitlebar;
    self.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    self.state = NSVisualEffectStateActive;
    self.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    // Real AppKit window buttons: they act on the window they're in.
    NSWindowButton kinds[] = {NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton};
    for (int i = 0; i < 3; i++) {
        NSButton *b = [NSWindow standardWindowButton:kinds[i] forStyleMask:w.styleMask];
        if (!b) continue;
        b.enabled = kinds[i] != NSWindowMiniaturizeButton;
        [self addSubview:b];
    }
    return self;
}

// Lights at the macOS titlebar positions: 20 pt apart, vertically centred.
- (void)layout {
    [super layout];
    CGFloat x = ArcFullScreenStripInset;
    for (NSView *b in self.subviews) {
        NSSize s = b.frame.size;
        b.frame = NSMakeRect(x, round((NSHeight(self.bounds) - s.height) / 2), s.width, s.height);
        x += ArcFullScreenStripSpacing;
    }
}

- (NSRect)frameShown:(BOOL)shown in:(NSView *)host {
    CGFloat h = ArcFullScreenStripHeight, top = host.isFlipped ? 0 : NSHeight(host.bounds) - h;
    CGFloat off = shown ? 0 : h;
    return NSMakeRect(0, host.isFlipped ? top - off : top + off, NSWidth(host.bounds), h);
}

- (void)setShown:(BOOL)shown animated:(BOOL)animated {
    NSWindow *w = self.owner;
    NSView *host = w.contentView.superview;
    if (!host || shown == _shown) return;
    _shown = shown;
    if (shown) {
        self.frame = [self frameShown:NO in:host];
        [host addSubview:self positioned:NSWindowAbove relativeTo:nil];
    }
    __weak typeof(self) weakSelf = self;
    ArcAnimate(animated ? ArcDurationMedium : 0, shown, ^(NSAnimationContext *ctx) {
        weakSelf.animator.frame = [weakSelf frameShown:shown in:host];
    }, ^{
        if (!weakSelf.shown) [weakSelf removeFromSuperview];
    });
}

// Shown while the pointer is at the top edge (or up in the menu bar), kept while it stays
// over the strip, hidden once it moves below.
- (void)check {
    NSWindow *w = self.owner;
    if (!w || !(w.styleMask & NSWindowStyleMaskFullScreen)) { [self setShown:NO animated:NO]; return; }
    NSPoint p = NSEvent.mouseLocation;
    NSRect f = w.frame;
    BOOL overWindowColumn = p.x >= NSMinX(f) && p.x <= NSMaxX(f);
    BOOL atTop = overWindowColumn && p.y >= NSMaxY(f) - 1;
    BOOL overStrip = overWindowColumn && p.y >= NSMaxY(f) - ArcFullScreenStripHeight - ArcSpace2;
    BOOL want = NSApp.isActive && w.isVisible && (atTop || (self.shown && overStrip));
    [self setShown:want animated:YES];
}

- (void)start {
    if (self.poll) return;
    __weak typeof(self) weakSelf = self;
    self.poll = [NSTimer scheduledTimerWithTimeInterval:kPollInterval repeats:YES block:^(__unused NSTimer *t) { [weakSelf check]; }];
    self.poll.tolerance = kPollInterval / 2;
}

- (void)stop {
    [self.poll invalidate];
    self.poll = nil;
    [self setShown:NO animated:NO];
}

@end

void TweakFullScreenStripSetActive(NSWindow *window, BOOL active) {
    if (!window) return;
    TweakFullScreenStrip *strip = objc_getAssociatedObject(window, kStripKey);
    if (active && !strip) {
        strip = [[TweakFullScreenStrip alloc] initForWindow:window];
        objc_setAssociatedObject(window, kStripKey, strip, OBJC_ASSOCIATION_RETAIN);
    }
    if (active) [strip start]; else [strip stop];
}

#pragma mark - Minimize

void TweakTopRowSetMinimizeAllowed(NSWindow *window, BOOL allowed) {
    NSButton *mini = [window standardWindowButton:NSWindowMiniaturizeButton];
    if (!mini) return;
    BOOL ours = [objc_getAssociatedObject(window, kMinimizeOffKey) boolValue];
    if (!allowed && mini.enabled) {
        mini.enabled = NO;
        objc_setAssociatedObject(window, kMinimizeOffKey, @YES, OBJC_ASSOCIATION_RETAIN);
    } else if (allowed && ours) {
        mini.enabled = YES;
        objc_setAssociatedObject(window, kMinimizeOffKey, nil, OBJC_ASSOCIATION_RETAIN);
    }
}
