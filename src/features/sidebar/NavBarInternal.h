// Private to the top-bar hiding (NavBar.m) and Dia's URL editor anchoring (NavBarEditor.m).
#import "Common.h"

NSView *TweakNavBarFocusedPane(NSWindow *window);
void TweakNavBarSetRevealed(NSView *pane, BOOL revealed);   // shows or hides the bar as an overlay now
void TweakNavBarEditorInstall(void);
void TweakNavBarEditorTick(void);   // from NavBar's timer: ends the anchor once the editor closed
