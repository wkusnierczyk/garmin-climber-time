# Graphics

The face's images, and how each is made: the [launcher icon](#launcher-icon) and the store cover,
the [store and README images](#store-and-readme-images), and the [hero](#the-hero). All of them are
generated, never edited by hand, except the hero, which an image model composes.

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
checks it. Like `make install-garmin-font-scaler` (see [Development](development.md#tools)), it needs `git` and a
Python 3 that can make a virtual environment with `pip`, tried in the same order; pick another with
`GRAPHICS_VENV_PYTHON=/path/to/python3`. Pillow is pinned because `make check-icons` compares the
icons' pixels, which only the Pillow they were drawn with reproduces.

Run `make graphics` again whenever what the face draws changes: nothing reports the images stale.
The hero's placement is random, so look at the draft and run it again if it is poor.

### The hero

The published hero, `store/lite/graphics/ClimberTimeHero.png` (exactly 1440 x 720, as the store
requires), is not the draft: an image model composed it from the four gallery watches, rendered full
size by `make preview`, with the prompt in [`tools/hero-prompt.txt`](../tools/hero-prompt.txt), so that
they read as real watches at different angles. The output, trimmed to 2:1, is scaled to the hero and
to the 900 x 450 `ClimberTimeHero-small.png`. `make graphics` never overwrites either. Compose it
again whenever the gallery changes.
