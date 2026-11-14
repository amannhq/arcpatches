// ArcStyle: ArcPatches' design tokens, modelled on Arc's sidebar UI.
// Every view ArcPatches draws takes its sizes, radii, colours, type and motion from
// here, never from magic numbers, so the whole UI stays consistent and can be tuned in
// one place. Values are in points, measured from Arc 1.x on macOS (2x screenshots,
// halved). See docs/design-language.md for the reasoning behind each group.
#import <AppKit/AppKit.h>

#pragma mark - Spacing (4-pt grid)

static const CGFloat ArcSpace1 = 4;
static const CGFloat ArcSpace2 = 8;
static const CGFloat ArcSpace3 = 12;
static const CGFloat ArcSpace4 = 16;
static const CGFloat ArcSidebarInset = 6;        // URL pill, favourites and tabs share one edge

#pragma mark - Radii (all continuous corners)

static const CGFloat ArcRadiusChip = 6;          // 22-pt icon squares in palette rows
static const CGFloat ArcRadiusSmall = 7;         // icon buttons inside the URL pill
static const CGFloat ArcRadiusMedium = 8;        // top-row hover fill, popover tiles, footer chips
static const CGFloat ArcRadiusPill = 10;         // the URL pill, favourite tiles
static const CGFloat ArcRadiusPopover = 14;      // popovers and panels

#pragma mark - Sizes

static const CGFloat ArcTopRowButton = 32;       // toggle, back, forward, reload: hit area and hover fill
static const CGFloat ArcTopRowIcon = 15;         // their SF Symbol point size (regular)
static const CGFloat ArcPillHeight = 36;
static const CGFloat ArcPillButton = 28;         // copy link, site controls
static const CGFloat ArcPillIcon = 13;
static const CGFloat ArcPopoverWidth = 272;
static const CGFloat ArcTileHeight = 34;         // popover action / extension tiles
static const CGFloat ArcRowIconCircle = 30;      // popover settings rows
static const CGFloat ArcFaviconSize = 16;        // site icons in lists and fields
static const CGFloat ArcChipSize = 22;           // rounded square behind a row's action icon

#pragma mark - Command palette (⌘T) and URL editor (⌘L)

static const CGFloat ArcPaletteWidth = 520;
static const CGFloat ArcPaletteMargin = 24;      // kept clear on each side of the web content
static const CGFloat ArcPaletteTopFraction = 0.30;   // top edge, down from the content's top
static const CGFloat ArcPaletteSearchHeight = 52;
static const CGFloat ArcPaletteSearchIcon = 15;  // magnifying glass point size
static const CGFloat ArcPaletteSearchInset = 18; // its leading inset
static const CGFloat ArcPaletteRowHeight = 34;
static const CGFloat ArcPaletteRowGap = 6;
static const CGFloat ArcRowTitleShare = 0.6;     // most a title takes when a "— detail" follows
static const CGFloat ArcPaletteAppearScale = 0.98;   // grows from this when it appears
static const CGFloat ArcEditorWidthRatio = 1.55; // editor width per point of sidebar width
static const CGFloat ArcEditorMinWidth = 300;
static const CGFloat ArcEditorMaxWidth = 420;
static const CGFloat ArcEditorRowHeight = 44;
static const CGFloat ArcEditorPopoverInset = 0;  // Dia's editor popover: frame offset from the pill

#pragma mark - Type (system font)

NSFont *ArcFontURL(void);                        // 13 regular: the pill's host
NSFont *ArcFontRowTitle(void);                   // 13 medium
NSFont *ArcFontRowSubtitle(void);                // 11 regular
NSFont *ArcFontSectionHeader(void);              // 12 semibold
NSFont *ArcFontChip(void);                       // 12 medium: "Secure", "Copied"
NSFont *ArcFontPaletteField(void);               // 17 regular: the palette's search field
NSFont *ArcFontPaletteRow(void);                 // 14 medium: palette and editor row titles
NSFont *ArcFontPaletteDetail(void);              // 13 regular: "— github.com" after a title
NSFont *ArcFontAccessory(void);                  // 13 medium: "Switch to Tab"

#pragma mark - Colour

typedef NS_ENUM(NSInteger, ArcFill) {
    ArcFillRest,        // the pill at rest
    ArcFillHover,       // any control under the pointer
    ArcFillPressed,     // mouse down
    ArcFillSelected,    // a control whose popover or menu is open
    ArcFillTile,        // popover tiles at rest
};
// White over dark chrome, black over light, at Arc's alphas.
NSColor *ArcFillColor(ArcFill fill);
NSColor *ArcIconColor(BOOL enabled);             // secondary label, or tertiary when disabled
NSColor *ArcTextSecondary(void);
NSColor *ArcHairline(void);                      // popover dividers
NSColor *ArcTextTertiary(void);                  // row details at a readable ~6:1 on panels
NSColor *ArcPanelTint(void);                     // near-opaque wash over a panel's blur
NSColor *ArcPanelBorder(void);                   // a floating panel's hairline edge
NSColor *ArcTextSelection(void);                 // selected text in our fields

#pragma mark - Motion

static const NSTimeInterval ArcDurationFast = 0.12;   // hover fills, icon fades
static const NSTimeInterval ArcDurationMedium = 0.2;  // button appear/disappear, crossfades
static const NSTimeInterval ArcFeedbackHold = 1.2;    // "Copied" stays this long
CAMediaTimingFunction *ArcEaseOut(void);              // things appearing
CAMediaTimingFunction *ArcEaseIn(void);               // things leaving

// Animates `changes` with Arc's timing, or applies them at once when the user asked
// macOS to reduce motion.
void ArcAnimate(NSTimeInterval duration, BOOL appearing, void (^changes)(NSAnimationContext *ctx), void (^done)(void));

#pragma mark - Helpers

// Rounds `layer` with continuous corners at `radius`.
void ArcRound(CALayer *layer, CGFloat radius);
NSImage *ArcSymbol(NSString *name, CGFloat pointSize, NSFontWeight weight, NSString *label);
