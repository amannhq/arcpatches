---
name: dia-class-check
description: Check that the Dia (or other browser) classes and selectors ArcPatches looks up by name still exist in an installed build, by reading its binaries' strings read-only. Use after a Dia update, when adding or renaming a class in src/browsers/<id>/Browser.m, when a feature relies on a new private class or selector, or when the Health list reports a failure.
---

# Browser class check

ArcPatches finds the browser's private AppKit classes by name at runtime. If an update renames one, only that feature turns off, and Health reports it. This check catches the rename statically.

## Run it

```bash
scripts/check-classes.sh /Applications/Dia.app    # exit 0 all found, 1 missing, 2 usage error
```

`./tests/run.sh` also runs it as an optional last step when `/Applications/Dia.app` exists. In CI it is skipped.

How it works:
- It reads the app's `CFBundleIdentifier`, then picks the descriptor under `src/browsers/*/Browser.m` that declares that bundle id. Other browsers' classes are never checked against Dia.
- The haystack is `strings -a` of every Mach-O file under `Contents/MacOS` and `Contents/Frameworks`: the main executable, `ArcCore.framework`, the dylibs and the helpers.

How each kind of constant is matched:

| Shape | Example | Matched as |
| --- | --- | --- |
| `Module.Class` | `TabSidebar.SidebarHeaderView` | mangled `_TtC10TabSidebar17SidebarHeaderView`, the runtime name `NSClassFromString` resolves |
| plain name | `ArcBrowser` | an exact strings line (ObjC / `@objc` class) |
| `kXxxPrefix` + `kXxxSuffix` | `_TtC10TabSidebar` + `SidebarContainerRootView` | one name that starts with the prefix and ends with the suffix, the same rule as `TweakFindClass` |
| prefix ending in `.` | `Personalization.` | any `_TtC<n>Personalization…` class |
| `*Module` / `*Name` | `DynamicPopover` | substring, the same rule as the code's `containsString:` |
| identity | bundle id, app path, display name, profile folder | skipped |

It also checks any `@"Module.Class"` or `@"_Tt…"` literal in `src/` outside `src/browsers/`. Features should use descriptor constants, so a literal hit there is a smell.

## When something is MISSING

1. Search for the replacement by hand:
   ```bash
   strings -a /Applications/Dia.app/Contents/MacOS/Dia /Applications/Dia.app/Contents/Frameworks/ArcCore.framework/Versions/A/ArcCore | grep -i '<part of the name>'
   ```
   Swift classes are mangled: `_TtC<len><Module><len><Class>`. Nested ones use `_TtCC`. Private ones carry a per-build hash, as in `_TtC10TabSidebarP33_<32 hex>24SidebarContainerRootView`. Never hard-code the hash. Use a prefix + suffix pair with `TweakFindClass`.
2. Update the one constant in `src/browsers/dia/Browser.m`, then re-run the script and `./tests/run.sh`.
3. If the class is truly gone, make the feature fail soft (`NSLog` and return) and make sure its Health entry turns false. Don't silence the check.

## Selectors

The script checks class names only. For a selector you hook or call, check its name by hand:
```bash
strings -a <binary> | grep -Fx 'browser:createTabGroupWithSessionIds:properties:completion:'
```
A hit only proves the name exists somewhere. The owning class and the type signature still need live verification. List them as such.

## Limits (say these when reporting)

- A string being present doesn't prove the class registers at runtime, that it is the class you expect, or that a hooked method keeps its signature.
- Generic Swift classes have no static ObjC name, so only a substring check is possible for them.
- Only read the app. Never launch, quit, copy into or modify it.
