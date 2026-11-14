// Private to the settings pane: the pane (PrefsPane.m), its building blocks
// (PrefsWidgets.m), and the Settings window plumbing (Preferences.m).
#import "Common.h"

// A rounded group of rows, like Dia's grouped settings.
@interface TweakGroupView : NSView
@end

@interface TweakFlippedView : NSView
@end

@interface TweakPrefsPane : NSView
@property (nonatomic, strong) NSPopUpButton *modePopup;
@property (nonatomic, strong) NSTextField *blockedLabel;
@property (nonatomic, strong) NSPopUpButton *rendererPopup;
@property (nonatomic, strong) NSPopUpButton *commandBarPopup;
@property (nonatomic, strong) NSPopUpButton *profileNumberPopup;
@property (nonatomic, strong) NSMutableArray<TweakShortcutRecorder *> *recorders;
@property (nonatomic, weak) NSScrollView *scroll;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSSwitch *> *switches;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSView *> *> *rowsByKey;
@end

// PrefsWidgets.m
@interface TweakPrefsPane (Widgets)
- (NSTextField *)label:(NSString *)s size:(CGFloat)size weight:(NSFontWeight)weight color:(NSColor *)color;
- (NSView *)rowWithTitle:(NSString *)title detail:(NSString *)detail control:(NSView *)control key:(NSString *)key;
- (NSView *)groupWithRows:(NSArray<NSView *> *)rows;
- (NSSwitch *)switchForKey:(NSString *)key;   // target: -switchChanged:
@end
