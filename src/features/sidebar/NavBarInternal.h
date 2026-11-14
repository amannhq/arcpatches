// Private to the top-bar hiding (NavBar.m) and Dia's URL editor anchoring (NavBarEditor.m).
#import "Common.h"

NSView *TweakNavBarFocusedPane(NSWindow *window);
void TweakNavBarSetRevealed(NSView *pane, BOOL revealed);   // shows or hides the bar as an overlay now
void TweakNavBarEditorInstall(void);
void TweakNavBarEditorTick(void);   // from NavBar's timer: ends the anchor once the editor closed
BOOL TweakNavBarEditorAnchored(void);   // an editor session is anchored away from the top bar
void TweakNavBarUpdateTimer(void);   // starts or stops NavBar's timer to match what needs it

// Posted (object nil) when whether a window's top bar should hide may have changed: the
// sidebar URL bar was attached or removed, or a sidebar slid in or out. Private to the
// sidebar feature, unlike TweakSettingsDidChangeNotification which reruns every feature.
extern NSNotificationName const TweakSidebarTopBarNeedsUpdateNotification;

// Back/forward availability and loading for the window's focused pane, read from Dia's
// hidden bar. `known` is NO when Dia's controls can't tell; then both stay enabled.
typedef struct { BOOL canGoBack, canGoForward, known, loading; } TweakNavState;
TweakNavState TweakNavBarState(NSWindow *window);
