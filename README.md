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
- The wall fills the right half of the screen. Left of it, the time on one line (HHMM) sits
  above the grade and proficiency tags on one line, the time centred vertically, the tags below
  it, both right-aligned just short of the wall; the tags together are as wide as the minutes.
  Hours are white; the minutes and both tags take the route colour. Other routes dim on the
  wall, seconds scale every 10 s.
- The other arrangements are in the code too (`Draw.LAYOUT`, `Draw.TIME_LINEAR`): a floating
  panel, the time stacked (`Draw.TIME_LINEAR` false), and a tall centre panel with the time and
  tags stacked or in one line on either side. Premium may offer them as settings.

- Always-on shows the time under a fine checkerboard that swaps its pixels every minute, and the
  route's holds as dots that step a few pixels once a minute; no climber, wall or tags. That keeps
  the screen inside the AMOLED burn-in protector's limits: under 3 % of the pixels lit, and no
  pixel lit three minutes running (DESIGN.md §13.1).

Not in the prototype: settings.

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

## Fonts

The time and the tags are drawn in bitmap fonts of
[Roboto Condensed](https://fonts.google.com/specimen/Roboto+Condensed) Bold, under the SIL Open Font
License 1.1 ([`resources/fonts/OFL-RobotoCondensed.txt`](resources/fonts/OFL-RobotoCondensed.txt)).
A Connect IQ watch draws a bitmap font at the one size it was made at, so every screen resolution in
[Devices](#devices) has its own pair, in `resources-<shape>-<width>x<height>/fonts/`, which the
compiler picks for each product by its screen:

- **`Time`**, the digits 0 to 9, each drawn centred in a fixed cell 1.04 times as wide as `0`
  (DESIGN.md §4.2; the typeface's digits share one advance anyway).
- **`Tag`**, the grades 4 to 8 and the proficiencies B, I and E.

The typeface is `RobotoCondensed[wght].ttf`, a variable font, from
[google/fonts](https://github.com/google/fonts/tree/69d0549e8fc7ad72e1531734c81237be401ec4fd/ofl/robotocondensed)
at commit `69d0549e8fc7ad72e1531734c81237be401ec4fd` (2026-03-12), with its `OFL.txt`. The TTF's own name table says
"Licensed under the Apache License, Version 2.0", as Roboto once was; google/fonts publishes this
file under the OFL 1.1 (`ofl/robotocondensed/`, with `OFL.txt`), and that is the licence it ships under here.
[`resources/fonts/RobotoCondensed-Bold.ttf`](resources/fonts/RobotoCondensed-Bold.ttf) is its bold
instance, weight 700, made with [`fonttools`](https://github.com/fonttools/fonttools) 4.60.2:

```sh
fonttools varLib.instancer "RobotoCondensed[wght].ttf" wght=700 --update-name-table -o RobotoCondensed-Bold.ttf
```

[`ttf2bmp`](https://github.com/wkusnierczyk/ttf2bmp) turns it into `.fnt` and `.png` pairs, and
[`garmin-font-scaler`](https://github.com/wkusnierczyk/garmin-font-scaler) runs it once per resolution,
from the sizes in `resources/fonts/fonts.xml`, the glyphs in `resources/fonts/charsets.json`, and the
resolutions in `resources/fonts/resolutions.json`: a target's size is the reference size times
min(W / W<sub>ref</sub>, H / H<sub>ref</sub>), rounded.

The reference resolution is 448x486, the Venu X1's rectangle, as `resources/fonts/resolutions.json`
declares it. The sizes are the design's (DESIGN.md §4.1, as the simulator draws them): the time 0.19 H,
shrunk if four cells would not fit between the bezel and the wall, then 1.1 times the time size 0.94; the
tags so that their two boxes span the minutes' two cells. That is a fixed share of the screen's height on
every screen in the list, and with the rectangle as the reference the scaler's factor is the ratio of the
heights on every round screen too, so every size it derives is the design's. With a round reference, the
rectangle's factor would be the ratio of the widths, and its time 8 % too small. The epix Pro (Gen 2)
47 mm the face is tried on, at 416x416, therefore gets derived sizes, 81 and 48: the sizes the watch's
vector font drew there before the bitmaps. `make check-fonts` holds every size to the design.

The table below lists every font size, generated by `garmin-font-scaler --table` into
[`fonts.md`](fonts.md) and copied here by `make fonts`; never edit it by hand.

<!-- fonts.md: start -->
| Resolution |   Shape   | Element |         Font         | Size |
| ---------: | :-------- | :------ | :------------------- | ---: |
|  360 x 360 | round     | Tag     | RobotoCondensed bold |   41 |
|  360 x 360 | round     | Time    | RobotoCondensed bold |   70 |
|  390 x 390 | round     | Tag     | RobotoCondensed bold |   45 |
|  390 x 390 | round     | Time    | RobotoCondensed bold |   76 |
|  416 x 416 | round     | Tag     | RobotoCondensed bold |   48 |
|  416 x 416 | round     | Time    | RobotoCondensed bold |   81 |
|  454 x 454 | round     | Tag     | RobotoCondensed bold |   52 |
|  454 x 454 | round     | Time    | RobotoCondensed bold |   89 |
|  466 x 466 | round     | Tag     | RobotoCondensed bold |   54 |
|  466 x 466 | round     | Time    | RobotoCondensed bold |   91 |
|  448 x 486 | rectangle | Tag     | RobotoCondensed bold |   56 |
|  448 x 486 | rectangle | Time    | RobotoCondensed bold |   95 |
<!-- fonts.md: end -->

To change a size, a glyph or a resolution, edit `resources/fonts/`, then:

```sh
make fonts         # every resources-<family>/fonts/, the copies in resources/fonts/, fonts.md and the table above
make check-fonts   # the configuration, the bitmaps, the design's sizes and this table agree (no SDK, no font tools)
```

`make fonts` records the SHA-256 of the typeface and of every bitmap in [`fonts.sha256`](fonts.sha256),
and `make check-fonts` holds them to it. Where the SDK's device definitions are present (locally, or
in CI's build job), it also checks that every product in `manifest.xml` belongs to a family with fonts,
since one without would compile with the reference's sizes from `resources/fonts/`; without them it
says it skipped that check.

`make fonts` needs both tools (see [Build and sideload](#build-and-sideload)). It also copies the reference
resolution's bitmaps into `resources/fonts/`, which the scaler does not refresh.

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

The store images and the launcher icons need
[`garmin-graphics-generator`](https://github.com/wkusnierczyk/garmin-graphics-generator), which
`make install-garmin-graphics-generator` installs the same way, in its own environment
(see *Store and README images*).

`make sideload` waits up to 5 minutes for the watch to appear, then retries detection and
installation with doubling gaps; a watch just plugged in or restarted can take a while to offer
MTP. Tune with `WAIT`, `EVERY`, `TRIES` and `BACKOFF`.

```sh
make build      # ClimberTime.prg for DEVICE (default epix2pro47mm)
make run        # build and load into the simulator
make sideload   # build for the watch connected by USB and copy it over
make test       # run the (:test) functions in the simulator
make fonts      # regenerate the bitmap fonts and their size table (see Fonts)
make golden     # recompute the tests' expected values from the browser simulator (Chrome)
make export     # export/ClimberTime-<version>.iq, the signed store bundle, version from manifest.xml
make help       # every target and variable, with the values they have now
```

## Store and README images

`make graphics` captures the store gallery, the README's screenshot and a draft hero into
`store/lite/graphics/`, on the epix Pro (Gen 2) 47 mm. `make preview` captures the same frames at
full size onto a labelled contact sheet, `.dev/scratchpad/preview/contact-sheet.png`, for review and
for picking the gallery; `AT="09:05:30 09:00:fall 09:05:always-on"` adds moments of your own
(`HH:MM:SS`, the first fall of a minute, or the always-on scene).

Each image is a moment: a minute and a second, a fall, or always-on, listed in
`tools/make-graphics.py`. The face takes everything from the clock, so the capture build
(`graphics.jungle`) freezes it there, and draws with the face's own code in the real simulator; it
is never shipped. The captures run the simulator in a container, so they need Docker and nothing
else: no desktop simulator and no screen-recording permission. The container is CI's tester image, a
private package (`docker login ghcr.io`); it is amd64 only, and on an arm64 Mac it runs emulated, a
minute or so per image. They also need
[`garmin-graphics-generator`](https://github.com/wkusnierczyk/garmin-graphics-generator) 0.8.1 or
newer, with Pillow 11.3.0. It is not on PyPI: `make install-garmin-graphics-generator` installs both
from its tag with `pip`, in a virtual environment of its own
(`~/.local/share/venvs/garmin-graphics-generator`, `GRAPHICS_VENV`), whose Python the image and icon
targets then run in (`GRAPHICS_PYTHON`, which defaults to it when it exists, else to `python3`); `make check-garmin-graphics-generator`
checks it. Like `make install-garmin-font-scaler` (see *Build and sideload*), it needs `git` and a
Python 3 that can make a virtual environment with `pip`, tried in the same order; pick another with
`GRAPHICS_VENV_PYTHON=/path/to/python3`. Pillow is pinned because `make check-icons` compares the
icons' pixels, which only the Pillow they were drawn with reproduces.

Run `make graphics` again whenever what the face draws changes: nothing reports the images stale.
The hero's placement is random, so look at the draft and run it again if it is poor.

The published hero, `store/lite/graphics/ClimberTimeHero.png` (exactly 1440 x 720, as the store
requires), is not the draft: an image model composed it from the four gallery watches, rendered full
size by `make preview`, with the prompt in [`tools/hero-prompt.txt`](tools/hero-prompt.txt), so that
they read as real watches at different angles. The output, trimmed to 2:1, is scaled to the hero and
to the 900 x 450 `ClimberTimeHero-small.png`. `make graphics` never overwrites either. Compose it
again whenever the gallery changes.

## Launcher icon

A white climber in a high step, on black: one foot rocked up beside the hip, one hand low and one reaching up.
The launcher icon's size is set per device, from 38 x 38 to 70 x 70, and not per screen, so each
size is drawn on its own by `tools/launcher_icon.py` (never scaled from one image) into
`resources-icon-<size>/`, and `monkey.jungle` maps each product to its own. The store cover,
`store/lite/graphics/ClimberTimeCover.png`, is the same drawing at 500 x 500. `make icons`
regenerates all of it, this table included, after a change to the devices or the drawing, and
`make check-icons` checks it with no SDK (in CI too). Both need
[`garmin-graphics-generator`](https://github.com/wkusnierczyk/garmin-graphics-generator) 0.8.1 or
newer for `GRAPHICS_PYTHON`, as `make graphics` does: `make install-garmin-graphics-generator`.

Each supported product is mapped to the icon its device asks for:

| Product                 |    Icon |
| :---------------------- | ------: |
| approachs7047mm         | 70 x 70 |
| d2airx10                | 70 x 70 |
| venu2                   | 70 x 70 |
| venu2plus               | 70 x 70 |
| venu3                   | 70 x 70 |
| venu3s                  | 70 x 70 |
| approachs7247mm         | 65 x 65 |
| d2mach2                 | 65 x 65 |
| d2mach2pro              | 65 x 65 |
| fenix847mm              | 65 x 65 |
| fenix8pro47mm           | 65 x 65 |
| fenix947mm              | 65 x 65 |
| fenix9pro47mm           | 65 x 65 |
| fenix9pro51mm           | 65 x 65 |
| fr57047mm               | 65 x 65 |
| fr965                   | 65 x 65 |
| fr970                   | 65 x 65 |
| marq3                   | 65 x 65 |
| venu445mm               | 65 x 65 |
| venux1                  | 65 x 65 |
| venu2s                  | 61 x 61 |
| approachs7042mm         | 60 x 60 |
| approachs7243mm         | 60 x 60 |
| d2mach1                 | 60 x 60 |
| descentg2               | 60 x 60 |
| descentmk343mm          | 60 x 60 |
| descentmk351mm          | 60 x 60 |
| epix2                   | 60 x 60 |
| epix2pro42mm            | 60 x 60 |
| epix2pro47mm            | 60 x 60 |
| epix2pro51mm            | 60 x 60 |
| fenix843mm              | 60 x 60 |
| fenix943mm              | 60 x 60 |
| fenix9pro43mm           | 60 x 60 |
| fenixe                  | 60 x 60 |
| fr265                   | 60 x 60 |
| fr265s                  | 60 x 60 |
| instinct3amoled45mm     | 60 x 60 |
| instinct3amoled50mm     | 60 x 60 |
| marq2                   | 60 x 60 |
| marq2aviator            | 60 x 60 |
| approachs50             | 56 x 56 |
| vivoactive5             | 56 x 56 |
| fr165                   | 54 x 54 |
| fr165m                  | 54 x 54 |
| fr170                   | 54 x 54 |
| fr170m                  | 54 x 54 |
| fr57042mm               | 54 x 54 |
| fr70                    | 54 x 54 |
| venu441mm               | 54 x 54 |
| vivoactive6             | 54 x 54 |
| instinctcrossoveramoled | 38 x 38 |

## CI

Every push to `main` or a release branch (`dev-*`) and every pull request runs [`.github/workflows/build.yml`](.github/workflows/build.yml):

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

The push runs [`.github/workflows/release.yml`](.github/workflows/release.yml):

| Job | What it does |
| :-- | :-- |
| `version check` | refuses a tag that is not on `main`; then [`tools/release-notes.py`](tools/release-notes.py), with no SDK: refuses the tag unless it is `v` plus a version `manifest.xml` is not ahead of, `CHANGELOG.md` has a dated, non-empty section for it, and `store/lite/` has a non-empty `description.txt` and, when the tag is the manifest's version, `whats-new-<version>.txt`. Run it locally before tagging: `tools/release-notes.py vX.Y.Z`. |
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
