#import "ArcStyle.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Type

NSFont *ArcFontURL(void) { return [NSFont systemFontOfSize:13 weight:NSFontWeightRegular]; }
NSFont *ArcFontRowTitle(void) { return [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; }
NSFont *ArcFontRowSubtitle(void) { return [NSFont systemFontOfSize:11 weight:NSFontWeightRegular]; }
NSFont *ArcFontSectionHeader(void) { return [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold]; }
NSFont *ArcFontChip(void) { return [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]; }

#pragma mark - Colour

static BOOL isDark(NSAppearance *a) {
    return [[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
}

NSColor *ArcFillColor(ArcFill fill) {
    // {dark white alpha, light black alpha}
    static const CGFloat alphas[][2] = {
        [ArcFillRest] = {0.08, 0.05},
        [ArcFillHover] = {0.11, 0.07},
        [ArcFillPressed] = {0.16, 0.10},
        [ArcFillSelected] = {0.14, 0.09},
        [ArcFillTile] = {0.07, 0.045},
    };
    CGFloat dark = alphas[fill][0], light = alphas[fill][1];
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) {
        return isDark(a) ? [NSColor colorWithWhite:1 alpha:dark] : [NSColor colorWithWhite:0 alpha:light];
    }];
}

NSColor *ArcIconColor(BOOL enabled) { return enabled ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor; }
NSColor *ArcTextSecondary(void) { return NSColor.secondaryLabelColor; }
NSColor *ArcHairline(void) { return [NSColor.separatorColor colorWithAlphaComponent:0.6]; }

#pragma mark - Motion

CAMediaTimingFunction *ArcEaseOut(void) { return [CAMediaTimingFunction functionWithControlPoints:0.2 :0.8 :0.2 :1]; }
CAMediaTimingFunction *ArcEaseIn(void) { return [CAMediaTimingFunction functionWithControlPoints:0.4 :0 :1 :1]; }

void ArcAnimate(NSTimeInterval duration, BOOL appearing, void (^changes)(NSAnimationContext *ctx), void (^done)(void)) {
    BOOL reduce = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
        ctx.duration = reduce ? 0 : duration;
        ctx.timingFunction = appearing ? ArcEaseOut() : ArcEaseIn();
        ctx.allowsImplicitAnimation = !reduce;
        changes(ctx);
    } completionHandler:done];
}

#pragma mark - Helpers

void ArcRound(CALayer *layer, CGFloat radius) {
    layer.cornerRadius = radius;
    layer.cornerCurve = kCACornerCurveContinuous;
}

NSImage *ArcSymbol(NSString *name, CGFloat pointSize, NSFontWeight weight, NSString *label) {
    NSImage *img = [NSImage imageWithSystemSymbolName:name accessibilityDescription:label];
    return [img imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight]];
}
