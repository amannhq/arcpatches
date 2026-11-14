# Contributing to ArcPatches

Thanks for helping. This guide covers how the project is organised, how to work on it safely, and what a pull request needs before it's merged.

## Ground rules

- Be kind and constructive. Everyone here follows the [Code of Conduct](CODE_OF_CONDUCT.md).
- Report security problems privately, as described in [SECURITY.md](SECURITY.md), not in issues.
- Never commit anything from a browser's app bundle: binaries, frameworks, icons or other artwork. CI checks for this.
- Only contribute code you wrote or have the right to license under MIT. Don't paste code from projects with incompatible or missing licenses.

## Ways to contribute

- **Report a bug** with the *Bug report* template. Include the browser version, the macOS version, the ArcPatches version, and the health list from the app.
- **Propose a patch** with the *New patch* template. A screenshot of how Arc does it, next to the current browser, is the most useful thing you can add.
- **Pick up an issue** labelled `good first issue` or `help wanted`. Comment first so two people don't do the same work.
- **Improve the docs.** Typos, unclear steps and outdated screenshots all count.

## Project layout

| Path | Contents |
| --- | --- |
| `src/` | `arcpatches.dylib`, which is loaded into the browser. Objective-C, with one area per file or folder: sidebar, command bar, privacy and so on. |
| `companion/` | The ArcPatches menu bar app (Swift). It clones, patches, re-signs and restores the browser, and updates itself. |
| `tools/` | `insert-dylib.c` (adds the weak load command), release signing, and development probes. |
| `tests/run.sh` | Tests that need no browser. CI runs them on every push and pull request. |
| `.github/` | CI, the release pipeline, and issue and PR templates. |

## Development setup

You need a Mac with Apple silicon, macOS 14 or later, and Xcode or the Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/amannhq/arcpatches.git
cd arcpatches
./tests/run.sh                         # builds everything and runs the tests
./companion/build.sh --no-install      # builds build/ArcPatches.app without installing it
```

### Trying a change in the browser

Test on a **separate copy** of the browser, never on the one you browse with:

```bash
./build.sh --launch    # builds ~/Applications/Dia Arc.app from /Applications/Dia.app
```

Things to know:
- The copy shares the original's profile, so quit the original first.
- If `/Applications/Dia.app` is already modified by another tool, restore the stock app first. Stacking two patchers makes results meaningless.

### Finding what to hook

The browser's UI is native AppKit. Most patches find a view by its class and change it after layout.

1. Look up class names in the binary with `strings -a /Applications/Dia.app/Contents/MacOS/Dia | grep _TtC`. Swift class names are mangled: for example `TabSidebar.SidebarHeaderView` is `_TtC10TabSidebar17SidebarHeaderView`.
2. Inspect the live view tree with the probes in `tools/`. `tools/inspect.m` dumps views with their classes and frames.
3. Hook as little as you can: one method, usually `layout`, with the original always called first. Check that the class exists before hooking it. If it's missing, switch the feature off and report it through the health list rather than crashing.

## Coding guidelines

- **Fail safe.** Every hook must cope with a missing class, a nil view, or a method that has changed. A browser update must never crash on launch because of ArcPatches.
- **No layout loops.** Don't set frames that the browser immediately resets. Guard against re-entrancy when you adjust layout from inside `layout`.
- **Main thread.** All AppKit work happens on the main thread.
- **Settings.** Every feature has an on/off switch stored under the `arcpatches.` prefix and appears in the Settings pane. Defaults must keep the browser usable.
- **Small files.** Aim for files under about 250 lines, and split by responsibility.
- **Style.** Match the surrounding code: `Tweak…` helpers, 4-space indent, and short comments that explain *why*, not *what*.
- **No new dependencies** without discussing them in an issue first.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org):

```
feat(sidebar): add copy-link button to the URL pill
fix(installer): keep the backup when re-signing fails
docs: explain how to find a view to hook
```

Keep each commit focused. Write the subject in the imperative and keep it under 72 characters. Add a body when the reason isn't obvious from the diff.

## Pull requests

`main` is protected: every change goes through a pull request, and CI must pass before it can merge.

1. Fork the repo, or create a branch if you have access, named like `feat/…`, `fix/…` or `docs/…`.
2. Keep each PR to one change. Several small PRs are easier to review than one large one.
3. Fill in the PR template: What, Why, Proof, Tested on, and the checklist.
4. **Proof is required for visible changes:** a screenshot for static UI and a short recording for anything animated. Show before and after when you change existing behaviour.
5. Test with the feature on and off, after relaunching the browser, and with tabs both in the sidebar and at the top if the feature touches either.
6. `./tests/run.sh` must pass.

PRs are squash-merged, so the PR title becomes the commit message. Write it as a conventional commit.

## Releases

Maintainers release by bumping `VERSION`, adding a section to `CHANGELOG.md`, and pushing a `vX.Y.Z` tag. CI then builds, signs and publishes the release. Contributors don't need to touch `VERSION` or `CHANGELOG.md`.

## Questions

Use [GitHub Discussions](https://github.com/amannhq/arcpatches/discussions) for questions and ideas, and issues for bugs and concrete proposals.
