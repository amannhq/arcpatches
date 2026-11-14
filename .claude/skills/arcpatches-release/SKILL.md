---
name: arcpatches-release
description: How an ArcPatches release is cut (VERSION, CHANGELOG, tag, the ARCPATCHES_UPDATE_PRIVATE_KEY signing secret) and what the in-app self-updater needs to see it. Use when preparing a release, bumping the version, setting up update signing, or debugging "ArcPatches never offers an update".
---

# Releasing ArcPatches

`.github/workflows/release.yml` runs on a pushed `v*` tag. It runs the tests, builds with `installer/build.sh --no-install`, and can optionally Developer-ID sign and notarize. It then signs `ArcPatches.zip` and publishes a GitHub release with `ArcPatches.zip`, `.sig` and `.sha256`.

## Prepare (an agent may do these, on a branch)

1. **`VERSION`:** the new `X.Y.Z` (no `v`), on one line.
2. **`CHANGELOG.md`:** a section whose heading is exactly `## X.Y.Z`.
   - The workflow checks it with `grep -qx "## $(cat VERSION)"`, so `## 0.1.0 (unreleased)` fails the release.
   - The section body becomes the release notes.
3. Run `./tests/run.sh` and `./installer/build.sh --no-install`.
4. Commit: `chore(release): vX.Y.Z`.

## Publish (a human does this; agents never push)

```bash
git tag vX.Y.Z && git push origin vX.Y.Z
```
The tag must equal `v$(cat VERSION)`, or the workflow stops.

## Signing setup (once)

- Run `./scripts/make-update-key.sh`:
  - It writes the ed25519 public key to `installer/update-public-key.txt`. Commit that file, because it is built into the app's Info.plist.
  - It keeps the private key in `~/.config/arcpatches/update-private-key`.
- Store the private key as the repo secret **`ARCPATCHES_UPDATE_PRIVATE_KEY`** with the `gh secret set …` command the script prints. The release fails without it.
- Never print, commit or paste the private key. Rotating it means older installs reject new updates until they are updated by hand.
- Optional, for a Developer ID signed and notarized build: `APPLE_CERTIFICATE_P12`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_APP_PASSWORD`, `APPLE_TEAM_ID`.

## Self-update and repo visibility

- `installer/Sources/SelfUpdater.swift` asks `https://api.github.com/repos/<ArcPatchesRepo>/releases/latest` with no auth token. The repo comes from `ARCPATCHES_REPO` at build time and defaults to `amannhq/arcpatches`.
- For a **private** repo, GitHub answers **404** to unauthenticated requests, and the updater treats 404 as "no releases yet". Installed copies therefore silently report themselves up to date and never update. The asset downloads would fail the same way.
- `amannhq/arcpatches` is public (since 2026-11-14), so self-update works. If the repo ever goes private again, publish releases from a separate public repo set through `ARCPATCHES_REPO`. Shipping a token inside the app is not an acceptable fix.

## Also check

- Drafts and prereleases are ignored by the updater. Only the latest full release counts.
- `make-update-key.sh` hard-codes `--repo amannhq/arcpatches` in the hint it prints. Adjust it if the repo moves.
