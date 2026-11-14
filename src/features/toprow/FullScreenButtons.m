#import "FullScreenButtons.h"
#import "ArcStyle.h"
#import <objc/runtime.h>

static const void *kTrackerKey = &kTrackerKey;
static const void *kMinimizeOffKey = &kMinimizeOffKey;

@interface TweakHeaderTracker : NSObject
@property (nonatomic, weak) NSView *header;
@property (nonatomic, copy) void (^changed)(NSView *header);
@property (nonatomic) BOOL hovered;
@end

@implementation TweakHeaderTracker

// Dia relayouts the header often enough to drop an exit event: always re-read where the
// pointer really is rather than trusting enter/exit alone.
- (void)sync {
    NSView *h = self.header;
    NSWindow *w = h.window;
    BOOL inside = w && !h.isHiddenOrHasHiddenAncestor &&
        NSPointInRect([h convertPoint:w.mouseLocationOutsideOfEventStream fromView:nil], h.bounds);
    if (inside == self.hovered) return;
    self.hovered = inside;
    void (^changed)(NSView *) = self.changed;
    dispatch_async(dispatch_get_main_queue(), ^{ if (h && changed) changed(h); });
}

- (void)mouseEntered:(NSEvent *)e { [self sync]; }
- (void)mouseExited:(NSEvent *)e { [self sync]; }
- (void)mouseMoved:(NSEvent *)e { [self sync]; }

@end

void TweakTopRowTrackHeader(NSView *header, void (^changed)(NSView *header)) {
    TweakHeaderTracker *t = objc_getAssociatedObject(header, kTrackerKey);
    if (t) { [t sync]; return; }
    t = [TweakHeaderTracker new];
    t.header = header;
    t.changed = changed;
    objc_setAssociatedObject(header, kTrackerKey, t, OBJC_ASSOCIATION_RETAIN);
    // InVisibleRect: follows the header's size without re-adding the area on every layout.
    [header addTrackingArea:[[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveAlways | NSTrackingInVisibleRect
          owner:t userInfo:nil]];
    [t sync];
}

BOOL TweakTopRowHeaderHovered(NSView *header) {
    return [(TweakHeaderTracker *)objc_getAssociatedObject(header, kTrackerKey) hovered];
}

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

void TweakTopRowFadeIn(NSView *buttons) {
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) { buttons.alphaValue = 1; return; }
    buttons.alphaValue = 0;
    ArcAnimate(ArcDurationMedium, YES, ^(NSAnimationContext *ctx) { buttons.animator.alphaValue = 1; }, nil);
}
