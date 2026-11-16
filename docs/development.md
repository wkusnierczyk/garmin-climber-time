# Development

How to build, test and release Climber Time: [build and sideload](#build-and-sideload), the
[tools](#tools), [tests](#tests), the [layouts in the code](#layouts-in-the-code), [CI](#ci) and
[releases](#releases). The fonts and the images have their own pages, [fonts](fonts.md) and
[graphics](graphics.md).

## Build and sideload

Needs the Connect IQ SDK (the Makefile follows the SDK manager's current SDK), the developer
key at `../garmin-keys/developer_key`, `git-lfs`, and `libmtp` (`brew install libmtp`) for
sideloading.

`make sideload` waits up to 5 minutes for the watch to appear, then retries detection and
installation with doubling gaps; a watch just plugged in or restarted can take a while to offer
MTP. Tune with `WAIT`, `EVERY`, `TRIES` and `BACKOFF`.

```sh
make build      # ClimberTime.prg for DEVICE (default epix2pro47mm)
make run        # build and load into the simulator
make sideload   # build for the watch connected by USB and copy it over
make test       # run the (:test) functions in the simulator
make fonts      # regenerate the bitmap fonts and their size table (see docs/fonts.md)
make golden     # recompute the tests' expected values from the browser simulator (Chrome)
make export     # export/ClimberTime-<version>.iq, the signed store bundle, version from manifest.xml
make help       # every target and variable, with the values they have now
```

## Tools

Building the fonts needs [`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp) 0.3.0 or newer on
`PATH`. `make install-ttf2bmp` downloads its release binary for macOS (arm64 or Intel) or Linux
(x86-64) into `~/.local/bin` (`BIN_DIR`), which must be on `PATH`; `make check-ttf2bmp` checks it.

It also needs [`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler)
0.3.0 or newer on `PATH`. It is not on PyPI: `make install-garmin-font-scaler` installs it from its
tag with `pip`, in a virtual environment of its own (`~/.local/share/venvs/garmin-font-scaler`,
`FONT_SCALER_VENV`), linked into `~/.local/bin` (`BIN_DIR`), which must be on `PATH`;
`make check-garmin-font-scaler` checks it. It needs `git`, and a Python 3 that can make a virtual
environment with `pip`: it tries `/usr/bin/python3`, then `python3` (Homebrew's cannot on some Macs);
pick another with `FONT_SCALER_PYTHON=/path/to/python3`. On Ubuntu that takes `python3-venv`; on a
Mac, Apple's Python and `git` need the Xcode command-line tools (`xcode-select --install`).

The store images and the launcher icons need
[`garmin-graphics-generator`](https://github.com/wkusnierczyk/garmin-graphics-generator), which
`make install-garmin-graphics-generator` installs the same way, in its own environment
(see [graphics](graphics.md#store-and-readme-images)).

## Tests

`make test` runs the `(:test)` functions in `source/tests/` in the Connect IQ simulator. They compare
the watch with the browser simulator, [`design/climber-time-simulator.html`](../design/climber-time-simulator.html),
the design's behavioural reference, never with the watch's own output: the expected values in
`source/tests/ClimbGolden.mc` are computed from it. `make golden` recomputes them in headless Chrome
(`CHROME`, Google Chrome's path on macOS by default) with
[`tools/make-golden.py`](../tools/make-golden.py); run it after a change to the simulator.

## Layouts in the code

The build draws one arrangement ([`DESIGN.md`](../design/DESIGN.md) §14.3): the wall fills the right
half of the screen; left of it, the time on one line (HHMM) sits above the grade and proficiency tags
on one line, the time centred vertically, the tags below it, both right-aligned just short of the
wall; the tags together are as wide as the minutes. The others are in the code too (`Draw.LAYOUT`,
`Draw.TIME_LINEAR` in [`source/Draw.mc`](../source/Draw.mc)): a floating panel, the time stacked
(`Draw.TIME_LINEAR` false), and a tall centre panel with the time and tags stacked or in one line on
either side. Premium may offer them as settings.

## CI

Every push to `main` or a release branch (`dev-*`) and every pull request runs [`.github/workflows/build.yml`](../.github/workflows/build.yml):

- **consistency checks**: `make check-help`, `make help`, `make check-fonts` and `make check-icons`, with no SDK;
- **build and export**: `make build` for one product per screen family (`tools/ci-devices.py`), then
  `make export`, which builds every product in `manifest.xml`;
- **unit tests**: `make test` in the simulator, under a virtual display.

The two SDK jobs run in our own tester image, `ghcr.io/wkusnierczyk/connectiq-tester` (SDK 9.3.0
and the device definitions), pinned by digest. It is a private package, so for a pull request from a
fork the two SDK jobs are skipped and only the consistency checks run. CI signs with a throwaway key, never the developer key.

## Releases

A `v*` tag is a release of the repository: one tag, one draft GitHub release, one `CHANGELOG.md`
section. The face's version is the one in `manifest.xml`. Every release goes through a release branch
`dev-<version>`; its last PR, `[DOCS] Release as X.Y.Z`, sets the manifest's version, adds the
`CHANGELOG.md` section headed `## X.Y.Z -- YYYY-MM-DD` (the date the tag is pushed) and the store's
*What's New*, `store/lite/whats-new-<version>.txt`. Once `main` has been fast-forwarded to the branch:

```sh
git switch main && git pull --ff-only
git tag vX.Y.Z && git push origin vX.Y.Z
```

The push runs [`.github/workflows/release.yml`](../.github/workflows/release.yml):

| Job | What it does |
| :-- | :-- |
| `version check` | refuses a tag that is not on `main`; then [`tools/release-notes.py`](../tools/release-notes.py), with no SDK: refuses the tag unless it is `v` plus a version `manifest.xml` is not ahead of, `CHANGELOG.md` has a dated, non-empty section for it, and `store/lite/` has a non-empty `description.txt` and, when the tag is the manifest's version, `whats-new-<version>.txt`. Run it locally before tagging: `tools/release-notes.py vX.Y.Z`. |
| `signed bundle` | `make export` in the CI image, signed with the real developer key: `ClimberTime-<version>.iq`, checked against the manifest's version. |
| `draft release` | a **draft** release for the tag, with that `CHANGELOG.md` section and the bundle. |

Publishing the draft and uploading the bundle to the store stay manual: the store publishes on upload,
and its version field is free text, so type the manifest's version exactly and paste the *What's New*.
The store texts in [`store/`](../store/) are plain text, since the store renders no Markdown.

The key is a secret of the `release` environment, `DEVELOPER_KEY`, the DER key base64-encoded, and
never a repository secret. The environment's only deployment rule admits `v*` tags, so GitHub refuses
the secret to any job on any other ref; no branch rule goes beside it. Who can push a `v*` tag can
sign a release: before adding a collaborator, add a tag ruleset restricting `v*`. Set the key once:

```sh
base64 < ../garmin-keys/developer_key | gh secret set DEVELOPER_KEY --env release
gh secret list --env release   # names DEVELOPER_KEY
gh secret list                 # stays empty
```

The DER file, `developer_key`, not the PEM: the workflow checks which one it got and says so.
