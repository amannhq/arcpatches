#import "Browser.h"

NSString *const kDiaBrowserID = @TWEAK_BROWSER_DIA;
NSString *const kDiaBundleID = @"company.thebrowser.dia";
NSString *const kDiaDisplayName = @"Dia";
NSString *const kDiaAppPath = @"/Applications/Dia.app";
NSString *const kDiaProfileFolder = @"Dia";

NSString *TweakDiaUserDataDir(void) {
    NSString *rel = [NSString stringWithFormat:@"Library/Application Support/%@/User Data", kDiaProfileFolder];
    return [NSHomeDirectory() stringByAppendingPathComponent:rel];
}

NSString *const kDiaPlatformWindowClass = @"Window.PlatformWindow";
NSString *const kDiaContentPaneClass = @"ContentPane.ContentPaneView";
NSString *const kDiaGesturalContentClass = @"GesturalNavigation.GesturalNavigationEventInterceptorView";
NSString *const kDiaInfoBarClass = @"InfoBar.InfoBarStackView";
NSString *const kDiaWebContentsHostClass = @"WebContentsPaneHostView";
NSString *const kDiaFlippedViewClass = @"ARCUI.FlippedView";
NSString *const kDiaWindowStandardButtonsClass = @"ARCUI.WindowStandardButtons";
NSString *const kDiaToggleSidebarAction = @"toggleSidebar:";

NSString *const kDiaNavigationBarClass = @"NavigationBar.NavigationBarView";
NSString *const kDiaNavigationCapsuleButtonClass = @"NavigationBar.NavigationBarCapsuleButton";
NSString *const kDiaAssistantBarClass = @"NavigationBar.AssistantBarView";
NSString *const kDiaInteractiveIconControlName = @"InteractiveIconControl";
NSString *const kDiaTabLoadingKey = @"loading";

NSString *const kDiaSidebarHeaderClass = @"TabSidebar.SidebarHeaderView";
NSString *const kDiaProfileIndicatorSuffix = @"ProfileIndicatorWrapperView";
NSString *const kDiaSidebarFooterClass = @"TabSidebar.SidebarContainerFooterView";
NSString *const kDiaSidebarRootPrefix = @"_TtC10TabSidebar";
NSString *const kDiaSidebarRootSuffix = @"SidebarContainerRootView";
NSString *const kDiaLibraryCellClass = @"TabSidebar.LibraryCellView";
NSString *const kDiaNewTabCellClass = @"TabList.NewTabCellView";

NSString *const kDiaPopoverRootPrefix = @"_TtCC14DynamicPopover";
NSString *const kDiaPopoverRootSuffix = @"RootView";
NSString *const kDiaPopoverModule = @"DynamicPopover";
NSString *const kDiaEditorRootClass = @"BoostCommandBar.RootView";
NSString *const kDiaEditorToolbarClass = @"BoostCommandBar.ToolbarView";
NSString *const kDiaEditorSuggestionsClass = @"BoostCommandBar.SuggestionsView";
NSString *const kDiaEditorTextViewPrefix = @"_TtCC15BoostCommandBar17TextContainerView";
NSString *const kDiaEditorTextViewSuffix = @"TextView";

NSString *const kDiaNewTabPageContentClass = @"NewTabPage.NewTabPageContentView";
NSString *const kDiaTabPopoverActionButtonClass = @"TabUI.TabPopoverActionButton";
NSString *const kDiaAssistantCapabilitiesToolbarClass = @"AssistantCapabilitiesUI.AssistantCapabilitiesToolbarView";
NSString *const kDiaAssistantPanelRootClass = @"AssistantPanelUIBase.AssistantPanelRootView";
NSString *const kDiaPersonalityModulePrefix = @"AssistantPersonalityUI.";
NSString *const kDiaPersonalizationModulePrefix = @"Personalization.";
NSString *const kDiaPowerUpModulePrefix = @"PowerUp.";

NSString *const kDiaPreferencesListClass = @"Preferences.SidebarListView";

NSString *const kDiaBrowserClass = @"ArcBrowser";
NSString *const kDiaChromiumBrowserClass = @"ADK.ChromiumBrowser";
NSString *const kDiaTabGroupPropertiesClass = @"ArcTabGroupProperties";
NSString *const kDiaNavigationControllerClass = @"ArcWebContentsNavigationController";
NSString *const kDiaAppConfigurationClass = @"ArcBrowserApplicationConfiguration";
NSString *const kDiaAIServiceClass = @"ArcAIService";

NSString *const kDiaSiteControlsIdentifier = @"siteControlCenterButton";
NSString *const kDiaSiteDetailsURLPrefix = @"chrome://settings/content/siteDetails?site=";
