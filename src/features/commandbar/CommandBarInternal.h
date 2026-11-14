// Private to the command bar: its views (CommandBarView.m) and its controller
// (CommandBar.m, with typing and activation in CommandBarInput.m).
#import "Common.h"
#import "CommandSources.h"

typedef NS_ENUM(NSInteger, TweakCommandBarMode) { TweakCommandBarNewTab, TweakCommandBarCurrentTab };

static const CGFloat kWidth = 760;
static const CGFloat kInputHeight = 64;
static const CGFloat kRowHeight = 44;
static const CGFloat kListInset = 8;
static const NSUInteger kMaxRows = 8;

static inline NSColor *dyn(CGFloat dw, CGFloat da, CGFloat lw, CGFloat la) {
    return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *a) {
        BOOL dark = [[a bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        return dark ? [NSColor colorWithWhite:dw alpha:da] : [NSColor colorWithWhite:lw alpha:la];
    }];
}

/// Secondary text in the bar (URLs, "— Search Google", shortcuts, inactive "Switch to Tab").
/// Tuned to ~6.4:1 contrast on the bar in both dark and light mode (macOS's tertiary label was ~2:1).
static inline NSColor *detailColor(void) { return dyn(1, 0.58, 0, 0.64); }

#pragma mark - Views

@class TweakResultsView;
@protocol TweakResultsViewDelegate
- (void)resultsView:(TweakResultsView *)v activate:(NSInteger)row;
- (NSImage *)iconForItem:(TweakItem *)item;
@end

@interface TweakResultsView : NSView
@property (nonatomic, copy) NSArray<TweakItem *> *items;
@property (nonatomic) NSInteger selected;
@property (nonatomic, weak) id<TweakResultsViewDelegate> delegate;
@end

@interface TweakCommandPanel : NSPanel
@end

// Near-opaque fill over the blur. The blur alone takes on the page behind it, so a
// white page turned the dark bar light gray and its white text unreadable.
@interface TweakTintView : NSView
@end

#pragma mark - Controller

@interface TweakCommandBar : NSObject <NSTextFieldDelegate, NSWindowDelegate, TweakResultsViewDelegate>
@property (nonatomic, strong) TweakCommandPanel *panel;
@property (nonatomic, strong) NSVisualEffectView *background;
@property (nonatomic, strong) NSTextField *field;
@property (nonatomic, strong) NSImageView *fieldIcon;
@property (nonatomic, strong) NSBox *divider;
@property (nonatomic, strong) TweakResultsView *results;
@property (nonatomic, strong) TweakCommandSources *sources;
@property (nonatomic, weak) NSWindow *host;
@property (nonatomic) TweakCommandBarMode mode;
@property (nonatomic, copy) NSString *typed;       // what the user typed (without inline completion)
@property (nonatomic) BOOL suppressCompletion;     // after a deletion
@property (nonatomic, copy) NSString *completionText;   // the field with the inline completion accepted
@property (nonatomic, copy) NSString *completionURL;    // where that goes
@property (nonatomic, copy) NSString *shownQuery;       // the query the listed results belong to
@end

@interface TweakCommandBar ()
+ (instancetype)shared;
- (void)showInWindow:(NSWindow *)window mode:(TweakCommandBarMode)mode;
- (void)layoutForRows:(NSUInteger)rows;
- (void)close;
@end

// Typing, completion and activation (CommandBarInput.m).
@interface TweakCommandBar (Input)
- (void)runQuery;
- (void)showItems:(NSArray<TweakItem *> *)items;
- (void)updateFieldIcon;
- (void)activateRow:(NSInteger)row forceNewTab:(BOOL)forceNewTab;
@end
