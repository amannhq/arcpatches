// Dia's downloads button, in Arc's place: Dia puts it at the trailing end of the sidebar's
// top row, on top of back/forward/reload. Arc keeps downloads in the sidebar's bottom-left
// corner, so this moves Dia's own view (progress, popover and all) into the sidebar footer,
// just after the Library button. Dia may put it back when it rebuilds the row; every
// header and footer layout moves it again.
#import "Common.h"
#import "ArcStyle.h"
#import "Browser.h"
#import <objc/runtime.h>

NSString *const TweakKeyDownloadsInFooter = @"arcpatches.downloadsInFooter";

static void (*origFooterLayout)(id, SEL);
static NSHashTable<NSView *> *gFooters;
static BOOL gMoving;

// The footer and header share the sidebar container.
static NSView *downloadsFor(NSView *footer) {
    return TweakDescendantOfClass(footer.superview, kDiaDownloadsButtonClass);
}

static NSView *libraryIn(NSView *footer) {
    return TweakChildOfClass(footer, kDiaLibraryButtonClass);
}

static void place(NSView *footer) {
    if (gMoving || !footer.window || ![TweakSettings boolForKey:TweakKeyDownloadsInFooter]) return;
    NSView *downloads = downloadsFor(footer);
    if (!downloads) return;
    gMoving = YES;
    if (downloads.superview != footer) {
        NSStackView *stack = (NSStackView *)downloads.superview;
        if ([stack isKindOfClass:NSStackView.class] && [stack.arrangedSubviews containsObject:downloads])
            [stack removeArrangedSubview:downloads];
        [downloads removeFromSuperview];
        [footer addSubview:downloads positioned:NSWindowAbove relativeTo:nil];
    }
    NSView *library = libraryIn(footer);
    CGFloat x = library && !library.isHidden ? NSMaxX(library.frame) + ArcSpace1 : ArcSidebarInset;
    NSSize s = downloads.frame.size;
    if (s.width < 1 || s.height < 1) s = NSMakeSize(34, 34);
    NSRect f = NSMakeRect(round(x), round((NSHeight(footer.bounds) - s.height) / 2), s.width, s.height);
    if (!NSEqualRects(downloads.frame, f)) downloads.frame = f;
    gMoving = NO;
}

static void hookedFooterLayout(NSView *self, SEL _cmd) {
    origFooterLayout(self, _cmd);
    [gFooters addObject:self];
    place(self);
}

// The header calls this after its own layout, which may have put the button back.
void TweakDownloadsReplace(NSView *header) {
    for (NSView *footer in gFooters.allObjects)
        if (footer.superview == header.superview) {
            dispatch_async(dispatch_get_main_queue(), ^{ place(footer); });
            return;
        }
}

void TweakDownloadsInstall(void) {
    [NSUserDefaults.standardUserDefaults registerDefaults:@{TweakKeyDownloadsInFooter: @YES}];
    Class footer = NSClassFromString(kDiaSidebarFooterClass);
    if (!footer || !NSClassFromString(kDiaDownloadsButtonClass)) {
        NSLog(@"[arcpatches] sidebar footer or downloads button not found; downloads stay in the top row");
        return;
    }
    gFooters = [NSHashTable weakObjectsHashTable];
    origFooterLayout = (void *)TweakHook(footer, @selector(layout), (IMP)hookedFooterLayout);
}
