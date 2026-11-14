// Shared helpers for arcpatches.
#import <AppKit/AppKit.h>

typedef NS_ENUM(NSInteger, TweakURLBarMode) {
    TweakURLBarModeTop = 0,      // Dia's stock bar above each pane
    TweakURLBarModeHidden = 1,   // bar hidden, optionally revealed on hover
    TweakURLBarModeSidebar = 2,  // bar hidden, URL field shown in the tab sidebar
};

// Settings (stored in Dia's own defaults domain under "arcpatches.*").
@interface TweakSettings : NSObject
+ (TweakURLBarMode)urlBarMode;
+ (void)setURLBarMode:(TweakURLBarMode)mode;
+ (BOOL)revealOnHover;
+ (BOOL)cmdLFocusesSidebar;
+ (BOOL)sidebarShowsFullURL;
+ (BOOL)sidebarShowsNavButtons;
+ (BOOL)topBarWhenSidebarHidden;
+ (BOOL)boolForKey:(NSString *)key;
+ (void)setBool:(BOOL)value forKey:(NSString *)key;
+ (void)setString:(NSString *)value forKey:(NSString *)key;
+ (void)toggleHiding;                    // ⌃⌘U
@end

extern NSNotificationName const TweakSettingsDidChangeNotification;
extern NSString *const TweakKeyRevealOnHover;
extern NSString *const TweakKeyCmdLFocusesSidebar;
extern NSString *const TweakKeySidebarFullURL;
extern NSString *const TweakKeySidebarNavButtons;
extern NSString *const TweakKeySidebarPillButtons;   // copy-link and site-controls buttons on hover
extern NSString *const TweakKeyTopBarWhenSidebarHidden;
extern NSString *const TweakKeyHideAI;
extern NSString *const TweakKeyBlockAI;
extern NSString *const TweakKeyBlockTelemetry;
extern NSString *const TweakKeyDisableOnDeviceAI;
extern NSString *const TweakKeyNoBackgroundNetworking;
extern NSString *const TweakKeyRendererLimit;
extern NSString *const TweakKeyNewTabPalette;
extern NSString *const TweakKeyCommandBarStyle;
extern NSString *const TweakKeyExtraShortcuts;
extern NSString *const TweakKeyProfileNumberMods;
extern NSString *const TweakKeyHideWindowButtonsInFullScreen;   // TopRow.m
extern NSString *const TweakKeySidebarToggleButton;
extern NSString *const TweakKeyTopRowProfileName;   // Dia's profile name in the top row (Arc shows none)

typedef NS_ENUM(NSInteger, TweakCommandBarStyle) {
    TweakCommandBarStyleOff = 0,       // Dia's defaults
    TweakCommandBarStyleDiaEditor = 1, // Dia's own editor, re-anchored (TweakPalette)
    TweakCommandBarStyleNative = 2,    // arcpatches's Arc-style command bar
};

// Runtime helpers.
NSView *TweakChildOfClass(NSView *parent, NSString *className);
NSView *TweakDescendantOfClass(NSView *root, NSString *className);
// Runs the enabled main-menu item bound to key + exactly mods (⌘, ⌥, ⌃, ⇧), the way choosing it
// would. Dia's own commands share one generic action, so the shortcut is what identifies them.
BOOL TweakPerformMenuShortcut(NSString *key, NSEventModifierFlags mods);
Class TweakFindClass(NSString *prefix, NSString *suffix);
// Replaces -[cls sel] with imp, returning the previous implementation
// (the inherited one if cls didn't override sel).
IMP TweakHook(Class cls, SEL sel, IMP imp);

// Dia scripting bridge: the active tab object for a window (DiaAppleScriptTab), or nil.
id TweakActiveTabForWindow(NSWindow *window);
NSString *TweakURLForWindow(NSWindow *window);
void TweakNavigateWindow(NSWindow *window, NSString *url);  // url is final; typed text goes through TweakResolveInput first
void TweakOpenInNewTab(NSWindow *window, NSString *url);
void TweakFocusTab(NSString *windowId, NSString *tabId);
NSString *TweakResolveURL(NSString *input);     // typed text → URL, or nil if it reads as a search
NSString *TweakResolveInput(NSString *input);   // same, but searches fall back to Google
BOOL TweakLooksLikeAddress(NSString *input);    // "github.com", "localhost:3000", "nas:5000/x", "[::1]"

// Modules.
void TweakNavBarInstall(void);
BOOL TweakNavBarShouldHideInWindow(NSWindow *window);
void TweakNavBarPerform(NSWindow *window, NSInteger index);  // 0 back, 1 forward, 2 reload
BOOL TweakNavBarOpenEditor(NSWindow *window, NSRect anchorInWindow);  // Dia's URL editor, placed at anchor
void TweakSidebarInstall(void);
BOOL TweakSidebarHasURLBar(NSWindow *window);
BOOL TweakSidebarFocusURLBar(NSWindow *window);
void TweakPreferencesInstall(void);
void TweakPrivacyPatchArgv(void);   // call before main()
void TweakPrivacyInstall(void);
NSUInteger TweakBlockedRequestCount(void);
NSArray<NSString *> *TweakAIHosts(void);
NSArray<NSString *> *TweakTelemetryHosts(void);
void TweakPerformanceInstall(void);   // call before main()
NSArray<NSString *> *TweakPerformanceSwitches(void);
void TweakPaletteInstall(void);
void TweakHandoffInstall(void);       // "Use Passkeys in Original Dia…"
void TweakSiteIconsInstall(void);     // the command bar's own copy of site favicons
BOOL TweakPaletteOpen(NSWindow *window);          // ⌘T: Dia's editor centred, commits open a new tab
void TweakPaletteEditorClosed(NSWindow *window);
BOOL TweakCommandBarShow(NSWindow *window, BOOL newTab);   // ⌘T palette, or ⌘L editor at the content's top
BOOL TweakCommandBarShowEditor(NSWindow *window, NSRect pillInWindow);   // ⌘L editor dropped from the URL pill
TweakCommandBarStyle TweakCommandBarCurrentStyle(void);
NSString *TweakPatchVersion(void);
void TweakHealthWrite(void);
void TweakKickCompanionOnQuit(void);

// Extra shortcuts (Shortcuts.m): actions are {id, title, detail, run, default}.
NSArray<NSDictionary *> *TweakShortcutActions(void);
NSDictionary *TweakShortcutFor(NSString *actionId);        // nil if cleared
void TweakSetShortcut(NSString *actionId, NSDictionary *shortcut);
NSString *TweakShortcutDisplay(NSDictionary *shortcut);
NSEventModifierFlags TweakProfileNumberMods(void);         // 0: off
BOOL TweakShortcutsHandle(NSEvent *keyDown);
// Click, then press a shortcut; saves it for the action.
@interface TweakShortcutRecorder : NSButton
@property (nonatomic, copy, readonly) NSString *actionId;
- (instancetype)initWithActionId:(NSString *)actionId;
- (void)sync;
@end

// Arc shortcuts (ArcShortcuts.m): ⌘⇧C, ⌘⇧⌥C, ⌘S. On by default, outside the extra-shortcuts
// switch; each is skipped while Dia's menu gives its keys to another command.
NSArray<NSDictionary *> *TweakArcShortcutSettings(void);   // Settings rows: {key, title, detail}
BOOL TweakArcShortcutsHandle(NSEvent *keyDown, NSWindow *browserWindow);
void TweakArcShortcutsInstall(void);

// Tab tidying (Tabs.m), for the window's active profile.
void TweakTabsInstall(void);   // call before main()
BOOL TweakTabsAvailable(void);
void TweakTabsSortByDomain(NSWindow *window);
void TweakTabsGroupByDomain(NSWindow *window);

void TweakDevDumpInstall(void);   // DevDump.m: view tree on request, for debugging
