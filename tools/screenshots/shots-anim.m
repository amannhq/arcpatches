// Frame sequences of ArcPatches' microinteractions for the website, at 30 fps, from the
// real views in each state. Between states the frames follow what the code animates, with
// ArcStyle.h's durations and curves: fades and crossfades are blends of the two states'
// renders, reload's turn rotates the real icon, and the palette's scale-and-fade (applied
// to the whole panel) is left to frame.swift through panel.json.
//   <dir>/<name>/000.png …   one panel per frame
//   <dir>/<name>/panel.json  {"alpha": […], "scale": […]} per frame, when the panel itself animates
#import "shots.h"
#import "../../src/features/sidebar/SidebarViews.h"

static const double kFPS = 30;

typedef struct { double x1, y1, x2, y2; } Ease;
static const Ease kEaseOut = {0.2, 0.8, 0.2, 1}, kEaseIn = {0.4, 0, 1, 1}, kLinear = {0, 0, 1, 1};   // ArcEaseOut, ArcEaseIn

// A CSS-style cubic bezier: solve x(s) = t, return y(s).
static double ease(Ease e, double t) {
    double lo = 0, hi = 1, s = t;
    for (int i = 0; i < 40; i++) {
        s = (lo + hi) / 2;
        double x = 3 * (1 - s) * (1 - s) * s * e.x1 + 3 * (1 - s) * s * s * e.x2 + s * s * s;
        if (x < t) lo = s; else hi = s;
    }
    return 3 * (1 - s) * (1 - s) * s * e.y1 + 3 * (1 - s) * s * s * e.y2 + s * s * s;
}
static NSInteger frameCount(NSTimeInterval d) { return MAX(1, lround(d * kFPS)); }

static NSImage *snap(NSView *v) {
    [v layoutSubtreeIfNeeded];
    NSBitmapImageRep *rep = [v bitmapImageRepForCachingDisplayInRect:v.bounds];
    [v cacheDisplayInRect:v.bounds toBitmapImageRep:rep];
    NSImage *img = [[NSImage alloc] initWithSize:v.bounds.size];
    [img addRepresentation:rep];
    return img;
}

@interface ShotSequence : NSObject
@property (nonatomic, copy) NSString *dir;
@property (nonatomic) NSInteger count;
@property (nonatomic, strong) NSMutableArray *alpha, *scale;
@end

@implementation ShotSequence

+ (instancetype)named:(NSString *)name in:(NSString *)dir {
    ShotSequence *s = [self new];
    s.dir = [dir stringByAppendingPathComponent:name];
    [NSFileManager.defaultManager removeItemAtPath:s.dir error:nil];
    [NSFileManager.defaultManager createDirectoryAtPath:s.dir withIntermediateDirectories:YES attributes:nil error:nil];
    s.alpha = [NSMutableArray array]; s.scale = [NSMutableArray array];
    return s;
}

// One frame: `draw` paints into a 2x bitmap the size of `size` points.
- (void)frame:(NSSize)size alpha:(double)a scale:(double)sc draw:(void (^)(NSRect r))draw {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:(NSInteger)size.width * 2
        pixelsHigh:(NSInteger)size.height * 2 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
        colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    rep.size = size;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    draw(NSMakeRect(0, 0, size.width, size.height));
    [NSGraphicsContext restoreGraphicsState];
    NSString *path = [self.dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%03ld.png", (long)self.count++]];
    [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
    [self.alpha addObject:@(a)]; [self.scale addObject:@(sc)];
}

// `a` blended into `b` by t, exactly (premultiplied sum), so any translucent parts stay right.
- (void)blend:(NSImage *)a to:(NSImage *)b t:(double)t alpha:(double)al scale:(double)sc {
    [self frame:a.size alpha:al scale:sc draw:^(NSRect r) {
        [a drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationPlusLighter fraction:1 - t];
        [b drawInRect:r fromRect:NSZeroRect operation:NSCompositingOperationPlusLighter fraction:t];
    }];
}
- (void)hold:(NSImage *)img seconds:(NSTimeInterval)d {
    for (NSInteger i = 0; i < frameCount(d); i++) [self blend:img to:img t:0 alpha:1 scale:1];
}
- (void)from:(NSImage *)a to:(NSImage *)b seconds:(NSTimeInterval)d ease:(Ease)e {
    NSInteger n = frameCount(d);
    for (NSInteger i = 1; i <= n; i++) [self blend:a to:b t:ease(e, (double)i / n) alpha:1 scale:1];
}
- (void)writePanelTimeline {
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"alpha": self.alpha, @"scale": self.scale} options:0 error:nil];
    [json writeToFile:[self.dir stringByAppendingPathComponent:@"panel.json"] atomically:YES];
}
@end

static NSView *panelCard(CGFloat w, CGFloat h) { return ShotCard(NSMakeSize(w, h), ShotPanelColor(), 0, NO); }

static NSView *pillCard(TweakSidebarURLBar **barOut, ShotPillState s) {
    NSView *card = panelCard(ShotSidebarWidth, ShotRowHeight + 8);
    TweakSidebarURLBar *bar = ShotPill(s, 4, nil, YES);
    [card addSubview:bar];
    if (barOut) *barOut = bar;
    return card;
}

// Hover the pill: the fill deepens and copy link and site controls fade in (ArcDurationFast,
// ease-out); leaving fades them out (ease-in).
static void pillHover(NSString *dir) {
    NSImage *rest = snap(pillCard(NULL, ShotPillRest)), *hover = snap(pillCard(NULL, ShotPillHover));
    ShotSequence *s = [ShotSequence named:@"pill-hover" in:dir];
    [s hold:rest seconds:0.4];
    [s from:rest to:hover seconds:ArcDurationFast ease:kEaseOut];
    [s hold:hover seconds:1.2];
    [s from:hover to:rest seconds:ArcDurationFast ease:kEaseIn];
    [s hold:rest seconds:0.4];
}

// Copy link: the host crossfades to "Copied" and the link icon to a checkmark
// (ArcDurationMedium, a linear CATransition fade), held for ArcFeedbackHold, then back.
static void copyLink(NSString *dir) {
    NSImage *hover = snap(pillCard(NULL, ShotPillHover));
    TweakSidebarURLBar *bar;
    NSView *card = pillCard(&bar, ShotPillHover);
    bar.showingFeedback = YES;
    bar.label.stringValue = @"Copied";
    [bar.linkButton setSymbol:@"checkmark" animated:NO];
    NSImage *copied = snap(card);
    ShotSequence *s = [ShotSequence named:@"copy-link" in:dir];
    [s hold:hover seconds:0.5];
    [s from:hover to:copied seconds:ArcDurationMedium ease:kLinear];
    [s hold:copied seconds:ArcFeedbackHold - ArcDurationMedium];
    [s from:copied to:hover seconds:ArcDurationMedium ease:kLinear];
    [s hold:hover seconds:0.6];
}

// Reload: one clockwise turn of the icon (ArcSpinDuration, ease-out), then, while the
// page loads, the icon crossfades to stop (ArcDurationMedium) and back when it's done.
static void reloadSpin(NSString *dir) {
    NSView *card = panelCard(ShotSidebarWidth, ShotRowHeight + 8);
    TweakNavButtons *nav = ShotAddTopRow(card, 4, ShotTopRowDefault);
    TweakChromeButton *reload = nav.subviews[2];
    NSImage *idle = snap(card);
    NSImage *icon = snap(reload);
    NSRect iconFrame = [card convertRect:reload.bounds fromView:reload];
    iconFrame.origin.y = NSHeight(card.bounds) - NSMaxY(iconFrame);   // the snapshot's flipped card → bottom-up
    reload.hidden = YES;
    NSImage *base = snap(card);
    reload.hidden = NO;
    [reload setSymbol:@"xmark" animated:NO];
    NSImage *stop = snap(card);

    ShotSequence *s = [ShotSequence named:@"reload-spin" in:dir];
    [s hold:idle seconds:0.4];
    NSInteger n = frameCount(ArcSpinDuration);
    for (NSInteger i = 1; i <= n; i++) {
        double turn = ease(kEaseOut, (double)i / n) * 2 * M_PI;
        [s frame:idle.size alpha:1 scale:1 draw:^(NSRect r) {
            [base drawInRect:r];
            NSAffineTransform *t = [NSAffineTransform transform];
            [t translateXBy:NSMidX(iconFrame) yBy:NSMidY(iconFrame)];
            [t rotateByRadians:-turn];   // clockwise on screen
            [t translateXBy:-NSMidX(iconFrame) yBy:-NSMidY(iconFrame)];
            [t concat];
            [icon drawInRect:iconFrame];
        }];
    }
    [s from:idle to:stop seconds:ArcDurationMedium ease:kLinear];
    [s hold:stop seconds:1.0];
    [s from:stop to:idle seconds:ArcDurationMedium ease:kLinear];
    [s hold:idle seconds:0.5];
}

// ⌘T: the panel grows from ArcPaletteAppearScale and fades in (ArcDurationMedium, ease-out),
// then ↓ moves the highlight row by row. (Escape's fade-out is left out: a whole-panel fade per
// frame would double the file; the loop restarts from the hidden state.)
static void paletteAppear(NSString *dir) {
    NSMutableArray<NSImage *> *rows = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) [rows addObject:snap(ShotPalette(i, 4))];
    ShotSequence *s = [ShotSequence named:@"palette" in:dir];
    for (NSInteger i = 0; i < frameCount(0.3); i++) [s blend:rows[0] to:rows[0] t:0 alpha:0 scale:ArcPaletteAppearScale];
    NSInteger n = frameCount(ArcDurationMedium);
    for (NSInteger i = 1; i <= n; i++) {
        double e = ease(kEaseOut, (double)i / n);
        [s blend:rows[0] to:rows[0] t:0 alpha:e scale:ArcPaletteAppearScale + (1 - ArcPaletteAppearScale) * e];
    }
    [s hold:rows[0] seconds:0.6];
    for (NSInteger i = 1; i < 4; i++) [s hold:rows[i] seconds:0.4];
    [s hold:rows[3] seconds:0.4];
    [s writePanelTimeline];
}

// Full screen with window buttons hidden: at the top edge the title strip slides down
// (ArcDurationMedium, ease-out) and slides away when the pointer leaves (ease-in).
static void fullScreenStrip(NSString *dir) {
    CGFloat h = ArcFullScreenStripHeight;
    ShotSequence *s = [ShotSequence named:@"fullscreen-strip" in:dir];
    NSImage *hidden = snap(ShotFullScreenRow(YES, -h)), *shown = snap(ShotFullScreenRow(YES, 0));
    [s hold:hidden seconds:0.5];
    NSInteger n = frameCount(ArcDurationMedium);
    for (NSInteger i = 1; i <= n; i++) [s hold:snap(ShotFullScreenRow(YES, -h + h * ease(kEaseOut, (double)i / n))) seconds:1 / kFPS];
    [s hold:shown seconds:1.2];
    for (NSInteger i = 1; i <= n; i++) [s hold:snap(ShotFullScreenRow(YES, -h * ease(kEaseIn, (double)i / n))) seconds:1 / kFPS];
    [s hold:hidden seconds:0.4];
}

void ShotAnimations(NSString *dir) {
    pillHover(dir);
    copyLink(dir);
    reloadSpin(dir);
    paletteAppear(dir);
    fullScreenStrip(dir);
}
