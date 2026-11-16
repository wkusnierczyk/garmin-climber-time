# Climber Time

[![build](https://github.com/wkusnierczyk/garmin-climber-time/actions/workflows/build.yml/badge.svg)](https://github.com/wkusnierczyk/garmin-climber-time/actions/workflows/build.yml)

A Garmin Connect IQ watch face: the time on the left, a climbing wall on the right, and a
miniature climber marking the seconds, one climb per minute. The design is
[`design/DESIGN.md`](design/DESIGN.md), whose behavioural reference is the browser simulator
[`design/climber-time-simulator.html`](design/climber-time-simulator.html) (open it in a browser).

## Status: prototype 0.0.1

A sideloadable prototype, not a release. It shows the correct time and the climber as in the
simulator, with the settings fixed:

- Difficulty cycles through grades 4 to 8, and each grade is climbed three times, as beginner,
  intermediate, then expert: 4B 4I 4E 5B ... 8E, then again. One climb per minute, so the
  cycle is 15 minutes and every hour starts at 4B. The three climbs of a grade are one route
  in one colour; the next grade brings a new route in a new colour.
- Each climb ends with a 3 s lower-off on the rope onto the next climb's start: the same route within a grade, a new one after the expert.
- Beginners fall onto the rope and restart; intermediates may fall once or miss a jump;
  experts top out (DESIGN.md §12).
- The wall is a panel on the right. Left of it, the time on one line (HHMM) sits above the
  grade and proficiency tags on one line, the time centred vertically, the tags below it, both
  right-aligned just short of the panel; the tags together are as wide as the minutes. Hours
  are white, minutes grey; the grade tag takes the route colour, the proficiency tag yellow (B),
  orange (I) or red (E). Other routes dim on the wall, seconds scale every 10 s.
- The other arrangements are in the code too (`Draw.LAYOUT`, `Draw.TIME_LINEAR`): the wall
  filling the right half, the panel with the time stacked (`Draw.TIME_LINEAR` false), and a tall
  centre panel with the time and tags stacked or in one line on either side. Premium may offer
  them as settings.

- Always-on shows the time under a fine checkerboard that swaps its pixels every minute, and the
  route's holds as dots that step a few pixels once a minute; no climber, wall or tags. That keeps
  the screen inside the AMOLED burn-in protector's limits: under 3 % of the pixels lit, and no
  pixel lit three minutes running (DESIGN.md §13.1).

Not in the prototype: settings and the custom digit font (the watch's Roboto Condensed Bold
vector font stands in).

## Devices

Every Connect IQ watch with a screen of at least 360 px in each direction: 52 products, all
AMOLED. The holds and the climber need that resolution, and the routes need colour, so smaller
screens, every MIP screen among them, are left out by size rather than by display type. Watches
below Connect IQ 5 are left out too (Venu, Venu Mercedes-Benz Collection, D2 Air).

| Screen | Products |
|---|---|
| Round 360 | Venu 2S, Forerunner 265s |
| Round 390 | epix Pro (Gen 2) 42 mm, MARQ (Gen 2) and Aviator, Venu 3S, Venu 4 41 mm, vívoactive 5 and 6, Approach S50, Approach S70 42 mm, Descent G2, Descent Mk3 / Mk3i 43 mm, Forerunner 70, Forerunner 165 and 165 Music, Forerunner 170 and 170 Music, Forerunner 570 42 mm, Instinct 3 AMOLED 45 mm, Instinct Crossover AMOLED |
| Round 416 | epix (Gen 2) / quatix 7 Sapphire, epix Pro (Gen 2) 47 mm / quatix 7 Pro, fēnix 8 43 mm, fēnix 9 43 mm and 9 Pro 43 mm, fēnix E, Venu 2 and 2 Plus, Approach S72 43 mm, D2 Air X10, D2 Mach 1, Forerunner 265, Instinct 3 AMOLED 50 mm |
| Round 454 | epix Pro (Gen 2) 51 mm / D2 Mach 1 Pro / tactix 7 AMOLED, fēnix 8 47/51 mm / tactix 8 / quatix 8, fēnix 8 Pro 47/51 mm / MicroLED / quatix 8 Pro, fēnix 9 47/51 mm and 9 Pro 47 mm, MARQ (Gen 3), Venu 3, Venu 4 45 mm / D2 Air X15, Approach S70 47 mm, Approach S72 47 mm, D2 Mach 2 and 2 Pro, Descent Mk3i 51 mm, Forerunner 570 47 mm, Forerunner 965, Forerunner 970 |
| Round 466 | fēnix 9 Pro 51 mm |
| Rectangular 448 × 486 | Venu X1 |

## Build and sideload

Needs the Connect IQ SDK (the Makefile follows the SDK manager's current SDK), the developer
key at `../garmin-keys/developer_key`, `git-lfs`, and `libmtp` (`brew install libmtp`) for
sideloading.

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

`make sideload` waits up to 5 minutes for the watch to appear, then retries detection and
installation with doubling gaps; a watch just plugged in or restarted can take a while to offer
MTP. Tune with `WAIT`, `EVERY`, `TRIES` and `BACKOFF`.

```sh
make build      # ClimberTime.prg for DEVICE (default epix2pro47mm)
make run        # build and load into the simulator
make sideload   # build for the watch connected by USB and copy it over
make test       # run the (:test) functions in the simulator
make golden     # recompute the tests' expected values from the browser simulator (Chrome)
make export     # export/ClimberTime-<version>.iq, the signed store bundle, version from manifest.xml
make help       # every target and variable, with the values they have now
```

## CI

Every push to `main` or a release branch (`dev-*`) and every pull request runs [`.github/workflows/build.yml`](.github/workflows/build.yml):

- **consistency checks**: `make check-help` and `make help`, with no SDK;
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

The push runs [`.github/workflows/release.yml`](.github/workflows/release.yml):

| Job | What it does |
| :-- | :-- |
| `version check` | [`tools/release-notes.py`](tools/release-notes.py), with no SDK: refuses the tag unless it is `v` plus a version `manifest.xml` is not ahead of, `CHANGELOG.md` has a dated section for it, and `store/lite/` has a non-empty `description.txt` and, when the tag is the manifest's version, `whats-new-<version>.txt`. Run it locally before tagging: `tools/release-notes.py vX.Y.Z`. |
| `signed bundle` | `make export` in the CI image, signed with the real developer key: `ClimberTime-<version>.iq`, checked against the manifest's version. |
| `draft release` | a **draft** release for the tag, with that `CHANGELOG.md` section and the bundle. |

Publishing the draft and uploading the bundle to the store stay manual: the store publishes on upload,
and its version field is free text, so type the manifest's version exactly and paste the *What's New*.
The store texts in [`store/`](store/) are plain text, since the store renders no Markdown.

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
