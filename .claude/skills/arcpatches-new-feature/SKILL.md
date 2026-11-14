---
name: arcpatches-new-feature
description: Checklist for adding a new ArcPatches feature folder under src/features/ (supported browsers, settings key, preferences row, Health entry, tests, docs). Use when adding a feature or a new hook into the browser, or when reviewing a feature PR for completeness.
---

# Adding a feature

Read the "Project layout" section of `CONTRIBUTING.md` and one small existing feature first. `src/features/tabs/` and `src/features/performance/` are good examples. Sibling branches often edit the shared files at the same time, so keep every shared-file edit small and additive: append lines and don't reorder.

## Checklist

1. **Folder.** Create `src/features/<name>/<Name>.m`. Add `<Name>Internal.h` only if the folder has more than one `.m`. Keep each file under about 250 lines and split it if larger. No new dependencies: AppKit, QuartzCore and sqlite3 only.
2. **Supported browsers.** Declare the feature in its main `.m`:
   ```objc
   const TweakFeature TweakFeatureFoo = {"foo", {TWEAK_BROWSER_DIA}, earlyOrNULL, installOrNULL};
   ```
   - Use `early` only for hooks that must exist before `main()`, such as argv or URLSession setup. Everything else goes in `install`, which runs on the main queue once AppKit is up.
   - Add `extern const TweakFeature TweakFeatureFoo;` to `src/core/Features.h`.
   - Add `&TweakFeatureFoo` to `kFeatures[]` in `src/core/ArcPatches.m`, in install order.
3. **Browser internals by name.** Put every class name in the browser descriptor (`src/browsers/dia/Browser.h` and `.m`) as a `kDia…Class`, `…Prefix`/`…Suffix`, `…Module` or `…Name` constant. Never put a literal in the feature.
   - Look classes up with `NSClassFromString`, or with `TweakFindClass(prefix, suffix)` for private Swift classes.
   - Hook with `TweakHook(cls, sel, imp)`. Keep the returned original IMP and call it.
   - Fail soft: if a class or method is missing, `NSLog(@"[arcpatches] …; <feature> inactive")` and return.
4. **Static check.** Run `scripts/check-classes.sh /Applications/Dia.app`, which must report 0 missing. Check each new selector with `strings -a … | grep -Fx '<selector>'`. See the `dia-class-check` skill.
5. **Settings key.** Declare `extern NSString *const TweakKeyFoo;` in `src/core/Common.h`. Define it in the feature's own `.m` as `NSString *const TweakKeyFoo = @"arcpatches.foo";`, the way `Privacy.m` and `Shortcuts.m` do. Keys live in Dia's defaults domain. Give the key a default in the `registerDefaults` dictionary in `src/core/Common.m`.
   - Read the value with `[TweakSettings boolForKey:]` or `NSUserDefaults`.
   - Listen for `TweakSettingsDidChangeNotification` to apply changes live.
6. **Preferences row.** In `src/features/preferences/PrefsPane.m`, add `[self rowWithTitle:… detail:… control:[self switchForKey:TweakKeyFoo] key:TweakKeyFoo]` in the right section. Write the detail in plain words. Use `setRow:enabled:` in the sync method if the row depends on another setting.
7. **Health entry.** In `src/core/Health.m`, add one line to `checks`, such as `@"Foo": @(<the classes/methods the feature needs exist>)`, using the same runtime lookups the feature uses. The installer app shows this list, and a `false` asks the user for attention.
8. **Public API.** If other modules call into the feature, declare it in `Common.h` under "Modules". Otherwise keep it `static`.
9. **Tests.** `./tests/run.sh` must pass, and it builds with `-Werror`. Pure logic (parsing, ranking, URL handling) should get a test that runs without a browser. Never launch the browser to test. See the `arcpatches-build-test` skill.
10. **Docs.** Add a bullet under "Features" in `README.md` if the feature is user-visible, and a row to the matrix in `docs/browsers.md` (plus the feature id in `installer/Sources/Browsers.swift` for each browser it supports; `tests/run.sh` checks the two agree). Add a line to the top `CHANGELOG.md` section.
11. **Live-only assumptions.** List them in the PR or report, for example: "hook fires when X", "view is placed at Y", "selector signature is Z". Static checks cannot confirm these.
