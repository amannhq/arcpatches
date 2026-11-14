// TweakChromeButton: the one Arc-style icon button every piece of sidebar chrome uses
// (top-row toggle, back, forward, reload, and the URL pill's hover buttons). A rounded
// square fill fades in under the pointer, gets stronger while pressed or selected, and
// goes away when disabled. Only size, radius and icon size differ between uses.
#import "ArcStyle.h"

static const CGFloat TweakChromeTopRowSize = 32;   // Arc's top-row hover square
static const CGFloat TweakChromeTopRowIcon = 15;

// Fades `layer`'s background to `color` (resolved in `view`'s appearance) over
// ArcDurationFast, from whatever is on screen now; instant when not animated.
void TweakChromeSetFill(NSView *view, CALayer *layer, NSColor *color, BOOL animated);
// Fades between the layer's old and new contents (text or symbol swaps).
void TweakChromeCrossfade(CALayer *layer);
// Fades a reveal-on-hover view in or out. It is `hidden` only once faded out (and not
// wanted back meanwhile), and a TweakChromeButton at zero alpha refuses clicks.
void TweakChromeFade(NSView *view, BOOL shown);

@interface TweakChromeButton : NSButton
+ (instancetype)buttonWithSymbol:(NSString *)symbol label:(NSString *)label pointSize:(CGFloat)size
                          radius:(CGFloat)radius target:(id)target action:(SEL)action;
@property (nonatomic, readonly) BOOL hovering;
@property (nonatomic) BOOL selected;      // its popover or menu is open: ArcFillSelected
@property (nonatomic, copy) NSString *symbol;
- (void)setSymbol:(NSString *)symbol animated:(BOOL)animated;
- (void)setLabel:(NSString *)label;      // tooltip and accessibility label
- (void)syncHover;                        // re-reads where the pointer really is
@end
