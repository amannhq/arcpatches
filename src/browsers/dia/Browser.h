// Dia (The Browser Company): the browser descriptor. Everything ArcPatches knows
// about Dia's identity and internals by name lives here, so a Dia update that
// renames a class is a one-line change. Swift classes are "Module.Class"; private
// ones are matched by a mangled prefix + suffix (TweakFindClass).
#import <Foundation/Foundation.h>

#define TWEAK_BROWSER_DIA "dia"   // the id features list in TweakFeature.browsers

extern NSString *const kDiaBrowserID;       // "dia"
extern NSString *const kDiaBundleID;        // company.thebrowser.dia
extern NSString *const kDiaDisplayName;     // Dia
extern NSString *const kDiaAppPath;         // /Applications/Dia.app
extern NSString *const kDiaProfileFolder;   // ~/Library/Application Support/<this>/User Data

// ~/Library/Application Support/Dia/User Data (Chromium's user data dir).
NSString *TweakDiaUserDataDir(void);

#pragma mark - Windows and panes

extern NSString *const kDiaPlatformWindowClass;          // a browser window
extern NSString *const kDiaContentPaneClass;             // one web pane
extern NSString *const kDiaGesturalContentClass;         // the pane's web content
extern NSString *const kDiaInfoBarClass;
extern NSString *const kDiaWebContentsHostClass;
extern NSString *const kDiaFlippedViewClass;             // ARCUI's generic container
extern NSString *const kDiaWindowStandardButtonsClass;   // the traffic lights in the sidebar header
extern NSString *const kDiaToggleSidebarAction;          // selector of Dia's Hide/Show Sidebar menu item

#pragma mark - Top navigation bar

extern NSString *const kDiaNavigationBarClass;
extern NSString *const kDiaNavigationCapsuleButtonClass;
extern NSString *const kDiaAssistantBarClass;            // the bar's URL field
extern NSString *const kDiaInteractiveIconControlName;   // back/forward/reload (substring)
extern NSString *const kDiaTabLoadingKey;                // scripting tab's "loading" key (Dia.sdef)

#pragma mark - Tab sidebar

extern NSString *const kDiaSidebarHeaderClass;
extern NSString *const kDiaProfileIndicatorSuffix;        // the header's profile name ("Personal"), private class
extern NSString *const kDiaSidebarFooterClass;
extern NSString *const kDiaSidebarRootPrefix;            // + suffix: SidebarContainerRootView
extern NSString *const kDiaSidebarRootSuffix;
extern NSString *const kDiaLibraryCellClass;             // "Chats" in the footer
extern NSString *const kDiaNewTabCellClass;

#pragma mark - URL editor (BoostCommandBar) and its popover

extern NSString *const kDiaPopoverRootPrefix;            // + suffix: DynamicPopover's RootView
extern NSString *const kDiaPopoverRootSuffix;
extern NSString *const kDiaPopoverModule;                // any DynamicPopover view (substring)
extern NSString *const kDiaEditorRootClass;
extern NSString *const kDiaEditorToolbarClass;
extern NSString *const kDiaEditorSuggestionsClass;
extern NSString *const kDiaEditorTextViewPrefix;         // + suffix: the editor's text view
extern NSString *const kDiaEditorTextViewSuffix;

#pragma mark - AI surfaces

extern NSString *const kDiaNewTabPageContentClass;
extern NSString *const kDiaTabPopoverActionButtonClass;  // tab hover card actions
extern NSString *const kDiaAssistantCapabilitiesToolbarClass;
extern NSString *const kDiaAssistantPanelRootClass;
extern NSString *const kDiaPersonalityModulePrefix;
extern NSString *const kDiaPersonalizationModulePrefix;
extern NSString *const kDiaPowerUpModulePrefix;

#pragma mark - Settings window

extern NSString *const kDiaPreferencesListClass;

#pragma mark - Objective-C (ADK / Chromium bridge)

extern NSString *const kDiaBrowserClass;
extern NSString *const kDiaChromiumBrowserClass;
extern NSString *const kDiaTabGroupPropertiesClass;
extern NSString *const kDiaNavigationControllerClass;
extern NSString *const kDiaAppConfigurationClass;
extern NSString *const kDiaAIServiceClass;

#pragma mark - Site controls

extern NSString *const kDiaSiteControlsIdentifier;       // accessibility id of the bar's site control center button
extern NSString *const kDiaSiteDetailsURLPrefix;         // + percent-encoded origin: Chromium's per-site settings
extern NSString *const kDiaPinnedExtensionsViewClass;    // the bar's pinned extensions (one view per extension inside)
extern NSString *const kDiaCaptureScreenshotAction;      // selector of Dia's screenshot menu item, if it has one
extern NSString *const kDiaExtensionDetailsURLPrefix;    // + extension id: Chromium's extension details page
