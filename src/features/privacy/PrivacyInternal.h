// Private to the privacy feature (Privacy.m, PrivacyHosts.m, PrivacyArgv.m, PrivacyUI.m).
#import "Common.h"

NSArray<NSString *> *TweakPrivacyBlockedHosts(void);   // per the Block AI / Block telemetry settings
void TweakPrivacyInstallNetwork(void);                 // URLSession layer; before main()
void TweakPrivacyInstallUI(void);                      // hides AI surfaces; on the main queue
