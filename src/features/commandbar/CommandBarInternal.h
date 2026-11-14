// Private to the command bar: its views (CommandBarView.m) and its controller
// (CommandBar.m, with typing and activation in CommandBarInput.m, placement and
// motion in CommandBarLayout.m).
#import "Common.h"
#import "CommandSources.h"
#import "ArcStyle.h"

typedef NS_ENUM(NSInteger, TweakCommandBarMode) { TweakCommandBarNewTab, TweakCommandBarCurrentTab };

static const NSUInteger kMaxRows = 8;

// Two layouts share one panel: the ⌘T palette, centred over the web content, and the
// ⌘L editor, dropped down from the sidebar's URL pill. All values come from ArcStyle.
typedef struct {
    CGFloat inputHeight;   // the field's row
    CGFloat rowHeight;
    CGFloat rowGap;
    CGFloat listInset;     // around the rows
    BOOL editor;
} TweakBarMetrics;

TweakBarMetrics TweakBarMetricsFor(BOOL editor);

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
@property (nonatomic) TweakBarMetrics metrics;
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
@property (nonatomic) NSRect anchor;               // screen: the pill (editor) or the web content (palette)
@property (nonatomic) BOOL pinnedToPill;           // the editor covers a pill rather than the content's top
@property (nonatomic) NSUInteger showGeneration;   // a newer show cancels an older fade-out
@end

@interface TweakCommandBar ()
+ (instancetype)shared;
- (void)showInWindow:(NSWindow *)window mode:(TweakCommandBarMode)mode anchor:(NSRect)anchor pinned:(BOOL)pinned;
- (void)close;
@end

// Placement, sizing and appear/dismiss motion (CommandBarLayout.m).
@interface TweakCommandBar (Layout)
- (void)applyStyleForMode;
- (void)layoutForRows:(NSUInteger)rows;
- (void)animateIn;
- (void)fadeOut;
@end

// The web content's frame on screen (all visible panes, without the sidebar), else the window's content.
NSRect TweakCommandBarContentRect(NSWindow *window);

// Typing, completion and activation (CommandBarInput.m).
@interface TweakCommandBar (Input)
- (void)runQuery;
- (void)showItems:(NSArray<TweakItem *> *)items;
- (void)updateFieldIcon;
- (void)showSuggestionsForCurrentPage;
- (void)activateRow:(NSInteger)row forceNewTab:(BOOL)forceNewTab;
@end
