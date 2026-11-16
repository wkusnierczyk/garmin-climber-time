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

Not in the prototype: settings, an always-on scene (the same face is drawn in every display
mode) and the custom digit font (the watch's Roboto Condensed Bold vector font stands in).

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

`make sideload` waits up to 5 minutes for the watch to appear, then retries detection and
installation with doubling gaps; a watch just plugged in or restarted can take a while to offer
MTP. Tune with `WAIT`, `EVERY`, `TRIES` and `BACKOFF`.

```sh
make build      # ClimberTime.prg for DEVICE (default epix2pro47mm)
make run        # build and load into the simulator
make sideload   # build for the watch connected by USB and copy it over
make test       # run the (:test) functions in the simulator
make export     # export/ClimberTime-<version>.iq, the signed store bundle, version from manifest.xml
make help       # every target and variable, with the values they have now
```

## CI

Every push to `main` and every pull request runs [`.github/workflows/build.yml`](.github/workflows/build.yml):

- **consistency checks**: `make check-help` and `make help`, with no SDK;
- **build and export**: `make build` for one product per screen family (`tools/ci-devices.py`), then
  `make export`, which builds all 52 products;
- **unit tests**: `make test` in the simulator, under a virtual display.

The two SDK jobs run in our own tester image, `ghcr.io/wkusnierczyk/connectiq-tester` (SDK 9.3.0
and the device definitions), pinned by digest. It is a private package, so a pull request from a
fork runs the consistency checks only. CI signs with a throwaway key, never the developer key.
