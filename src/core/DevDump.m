// Developer aid: writes every window's view tree to
// ~/Library/Application Support/arcpatches/views.txt when another process posts the
// distributed notification below. Read-only: nothing in the browser changes.
//   swift -e 'import Foundation; DistributedNotificationCenter.default().postNotificationName(.init("dev.amannhq.arcpatches.dump"), object: nil, userInfo: nil, deliverImmediately: true)'
#import "Common.h"
#import <objc/message.h>

static NSString *const kDumpNotification = @"dev.amannhq.arcpatches.dump";

static void dumpView(NSView *v, NSMutableString *out, int depth) {
    if (depth > 40) return;
    NSRect f = v.frame;
    [out appendFormat:@"%*s%@ (%.0f,%.0f %.0fx%.0f)%@%@%@%@\n", depth * 2, "", NSStringFromClass(v.class),
        f.origin.x, f.origin.y, f.size.width, f.size.height,
        v.hidden ? @" hidden" : @"", v.alphaValue < 1 ? [NSString stringWithFormat:@" alpha=%.2f", v.alphaValue] : @"",
        v.trackingAreas.count ? [NSString stringWithFormat:@" tracking=%lu", (unsigned long)v.trackingAreas.count] : @"",
        [v isKindOfClass:NSTextField.class] ? [NSString stringWithFormat:@" \"%@\"", [(NSTextField *)v stringValue]] : @""];
    if ([v respondsToSelector:@selector(hovering)]) {
        NSPoint p = [v convertPoint:v.window.mouseLocationOutsideOfEventStream fromView:nil];
        [out appendFormat:@"%*s  hovering=%d pointer=%@\n", depth * 2, "", ((BOOL (*)(id, SEL))objc_msgSend)(v, @selector(hovering)), NSStringFromPoint(p)];
    }
    for (NSView *s in v.subviews) dumpView(s, out, depth + 1);
}

static void dumpAll(void) {
    NSMutableString *out = [NSMutableString string];
    for (NSWindow *w in NSApp.windows) {
        if (!w.isVisible) continue;
        [out appendFormat:@"=== %@ \"%@\" key=%d fullscreen=%d frame=%@\n", NSStringFromClass(w.class), w.title, w.isKeyWindow,
            (w.styleMask & NSWindowStyleMaskFullScreen) != 0, NSStringFromRect(w.frame)];
        if (w.contentView.superview) dumpView(w.contentView.superview, out, 0);
    }
    NSString *dir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/arcpatches"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [out writeToFile:[dir stringByAppendingPathComponent:@"views.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void TweakDevDumpInstall(void) {
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:kDumpNotification object:nil queue:NSOperationQueue.mainQueue
                                                           usingBlock:^(__unused NSNotification *n) { dumpAll(); }];
}
