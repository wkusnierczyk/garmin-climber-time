#!/usr/bin/env python3
"""Capture the face's store and README images, or a contact sheet of them for review (#7).

Adapted from Matrix Time's tools/make-graphics.py (wkusnierczyk/garmin-matrix-time#125).
Capturing and composing are not this project's work: `garmin-graphics-generator` runs
the Connect IQ simulator in a container under Xvfb -- no GUI, no desktop simulator, no
macOS permission -- returns each frame as the device's screen and as the SDK's watch
render around it, and composes renders into a hero. What is here is what is specific
to this face: which moments, under which names, at which sizes, on which product.

A moment, not a run of the clock. The face takes everything from the clock -- the grade
and proficiency from the minute, the climber's pose from the second, the wall's other
routes from the day -- so a frame of grade 8 or of a fall needs that minute and that
second, which a capture against the real clock would land on by luck. Each frame is
therefore a build of its own, compiled through graphics.jungle with capture/Frame.mc
rewritten to name its moment, all of them in one container, the tree copied and never
written to. The face reads the clock and the display mode through source/Now.mc, which
the capture build replaces with capture/Now.mc; everything it draws is its own code in
the real simulator. That makes the captures deterministic, unlike Matrix Time's: the
same face draws the same images.

  ClimberTimeCapture.png           the first frame's raw screen, nothing composited
  ClimberTime1.png .. 6.png        watch renders at 200px, for the store gallery and
                                   the README
  ClimberTimeHero-draft.png        the hero frames scattered across 1440x720
  ClimberTimeHero-draft-small.png  the same composition at 900x450

The hero is a draft: its placement is random, so look at it and run again if it is
poor. No target writes ClimberTimeHero.png, the name a published hero would take, so
an adopted one survives a capture run (wkusnierczyk/garmin-matrix-time#130).

--preview DIR writes no store image. It captures the same frames, and any --at moments
besides, keeps each watch render at full size, and lays them out on DIR/contact-sheet.png
for review: what the gallery would show, and what to pick from.

Usage:
  tools/make-graphics.py                       regenerate the images in store/lite/graphics
  tools/make-graphics.py --preview DIR         the contact sheet instead, into DIR
  tools/make-graphics.py --preview DIR --at 09:05:30 --at 09:00:fall --at 09:05:always-on
  tools/make-graphics.py --background none     keep the transparency instead of white

Needs Docker running, the tester image CI uses (private: docker login ghcr.io), and
garmin-graphics-generator GENERATOR_VERSION or newer for the python3 running this.
"""
import argparse
import calendar
import datetime
import os
import re
import shutil
import sys
import tempfile
from importlib.metadata import PackageNotFoundError, version
from itertools import takewhile
from typing import List, NamedTuple, Optional

PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GRAPHICS = os.path.join(PROJECT, "store", "lite", "graphics")

# The product every capture is taken on: the Makefile's DEVICE default, and the one CI
# compiles and tests, so the images show what is verified. Its screen is 416x416.
DEFAULT_DEVICE = "epix2pro47mm"

# The image CI builds and tests in (.github/workflows/build.yml): SDK 9.3.0 and the device
# definitions, pinned by digest. Bump the two together. It is built for amd64 only, so an
# arm64 machine runs it emulated (the Makefile's PLATFORM).
DEFAULT_IMAGE = (
    "ghcr.io/wkusnierczyk/connectiq-tester@sha256:"
    "43c0f915cf5dbb721c87dabf36bcb0109ce33d42414e05c9472b53bc0b14914e"
)

# The capture build, and the file in it each frame rewrites (see the module docstring).
JUNGLE = "monkey.jungle;graphics.jungle"
FRAME_SOURCE = "capture/Frame.mc"

# The day every frame is on. The wall's other routes are seeded by the day (DESIGN.md
# §6.3), so a fixed one keeps the images from changing with the date they were made on.
DATE = datetime.date(2026, 11, 16)

# A frozen frame needs no time to settle; this only covers the face appearing.
SETTLE = 2.0


class Moment(NamedTuple):
    """What one frame shows: a minute, and a second or a fall, woken or always-on."""

    hour: int
    minute: int
    second: int = 0
    fall: bool = False
    always_on: bool = False

    def epoch(self) -> int:
        """Wall-clock seconds since the epoch, as if UTC, which is how Frame.mc takes them."""
        moment = datetime.datetime.combine(
            DATE, datetime.time(self.hour, self.minute, self.second)
        )
        return calendar.timegm(moment.timetuple())

    def clock(self) -> str:
        """The moment as --at spells it."""
        if self.always_on:
            return f"{self.hour:02d}:{self.minute:02d}:always-on"
        if self.fall:
            return f"{self.hour:02d}:{self.minute:02d}:fall"
        return f"{self.hour:02d}:{self.minute:02d}:{self.second:02d}"

    def tags(self) -> str:
        """The grade and proficiency tags the face shows in this minute (DESIGN.md §8.3)."""
        return f"{4 + (self.minute // 3) % 5}{'BIE'[self.minute % 3]}"


class Shot(NamedTuple):
    """One image of the inventory: what it shows, and whether the hero includes it."""

    label: str
    moment: Moment
    hero: bool


# The gallery, in the order the files are numbered: across a minute (start, mid-climb, a
# fall, the lower-off), across the grades (4B, 6I, 8E), and the always-on scene. The
# minute sets the grade and the proficiency: grade 4 + (minute / 3) mod 5, proficiency
# minute mod 3 (DESIGN.md §8.3), so :00 is 4B, :07 6I and :14 8E, whatever the hour.
# The beginner falls on every attempt that leaves time for another (§12), so 4B has a
# fall. The climb runs to :56, and the last 3 s are the lower-off (§11.3).
#
# Six images for the gallery; the hero takes four, as every extra watch shrinks them all
# (playbook, reference/graphics.md). Change the hour, the moments or the picks here.
SHOTS = (
    Shot("6I mid-climb", Moment(10, 7, 24), hero=True),
    Shot("4B fall", Moment(10, 0, fall=True), hero=True),
    Shot("8E mid-climb", Moment(10, 14, 40), hero=True),
    Shot("6I start", Moment(10, 7, 0), hero=False),
    Shot("6I lower-off", Moment(10, 7, 58), hero=False),
    Shot("always-on", Moment(10, 7, always_on=True), hero=True),
)

CAPTURE_NAME = "ClimberTimeCapture.png"
GALLERY_NAME = "ClimberTime{index}.png"
# Not ClimberTimeHero.png: that is the published hero's name, which this never writes.
HERO_NAME = "ClimberTimeHero-draft.png"
HERO_SMALL_NAME = "ClimberTimeHero-draft-small.png"

# Matrix Time's sizes. The gallery's 200px is the width of the images Matrix Time's
# listing has; the hero's 1440x720 is the only size the store takes.
GALLERY_WIDTH = 200
HERO_SIZE = (1440, 720)
HERO_SMALL_SIZE = (900, 450)
SIZE_VARIATION = 5
ORIENTATION_VARIATION = 20
MAX_OVERLAP = 20

SHEET_NAME = "contact-sheet.png"
SHEET_COLUMNS = 3

# 0.6.0 brought several builds in one container, each with files laid over a copy of the
# tree, and the contact sheet; 0.8.1 is the release this was written and run against, and
# the minimum, as for the family's other targets. The Makefile checks the same version.
GENERATOR = "garmin_graphics_generator"
GENERATOR_VERSION = "0.8.1"
INSTALL_HINT = """garmin-graphics-generator {version} or newer is needed, and {problem}.

    make install-garmin-graphics-generator

installs it, with the pinned Pillow, in its own environment, which make then runs this in;
this run used {python}. Or pass make GRAPHICS_PYTHON=/path/to/python3."""

FRAME_TEMPLATE = """import Toybox.Lang;

// Written by tools/make-graphics.py for one capture build: {label}.
module Frame {{
    const MOMENT = {epoch};
    const ALWAYS_ON = {always_on};
    const FALL = {fall};
}}
"""

AT_PATTERN = re.compile(r"(\d{1,2}):(\d{2}):(\d{2}|fall|always-on)")


def as_numbers(text: str):
    """A version as a tuple of integers, for comparing one release with another."""
    numbers = []
    for part in text.split("."):
        digits = "".join(takewhile(str.isdigit, part))
        if not digits:
            break
        numbers.append(int(digits))
    return tuple(numbers)


def load_generator():
    """Checks the shared generator is new enough, and returns what this uses of it."""

    def fail(problem):
        sys.exit(
            INSTALL_HINT.format(
                version=GENERATOR_VERSION, problem=problem, python=sys.executable
            )
        )

    try:
        installed = version(GENERATOR)
    except PackageNotFoundError:
        fail("it is not installed")
    if as_numbers(installed) < as_numbers(GENERATOR_VERSION):
        fail(f"{installed} is installed")
    try:
        from garmin_graphics_generator import sheet, variants
        from garmin_graphics_generator.capture import CaptureError
        from garmin_graphics_generator.core import WatchHeroGenerator
        from garmin_graphics_generator.shots import Build, ShotsError, take_builds
    except ImportError as error:
        fail(f"importing it failed: {error}")
    return {
        "Build": Build,
        "take_builds": take_builds,
        # Both: cutting the frames raises CaptureError, which is no ShotsError.
        "errors": (ShotsError, CaptureError),
        "hero": WatchHeroGenerator,
        "sheet": sheet,
        "variants": variants,
    }


def parse_at(text: str) -> Shot:
    """An --at moment: HH:MM:SS, HH:MM:fall or HH:MM:always-on."""
    match = AT_PATTERN.fullmatch(text)
    if not match:
        raise argparse.ArgumentTypeError(
            f"{text!r} is not HH:MM:SS, HH:MM:fall or HH:MM:always-on"
        )
    hour, minute, rest = int(match[1]), int(match[2]), match[3]
    if hour > 23 or minute > 59 or (rest.isdigit() and int(rest) > 59):
        raise argparse.ArgumentTypeError(f"{text!r} is no time of day")
    if rest == "fall":
        moment = Moment(hour, minute, fall=True)
    elif rest == "always-on":
        moment = Moment(hour, minute, always_on=True)
    else:
        moment = Moment(hour, minute, int(rest))
    return Shot("", moment, hero=False)


def frame_source(shot: Shot) -> str:
    """capture/Frame.mc for one shot's build."""
    return FRAME_TEMPLATE.format(
        label=f"{shot.label}, {shot.moment.clock()}",
        epoch=shot.moment.epoch(),
        always_on="true" if shot.moment.always_on else "false",
        fall="true" if shot.moment.fall else "false",
    )


def capture(tools, shots: List[Shot], arguments, work: str):
    """Every shot a build, in one container; returns each one's frame, in order."""
    builds = [
        tools["Build"](f"{index:02d}", JUNGLE, {FRAME_SOURCE: frame_source(shot)})
        for index, shot in enumerate(shots, start=1)
    ]
    if not arguments.silent:
        print(f"Capturing {len(builds)} moments of {arguments.device}:")
        for shot in shots:
            print(f"  {shot.moment.clock():<17} {shot.label}".rstrip())
    try:
        captured = tools["take_builds"](
            project=PROJECT,
            product=arguments.device,
            output_directory=os.path.join(work, "shots"),
            work_directory=os.path.join(work, "work"),
            builds=builds,
            count=1,
            settle=SETTLE,
            image=arguments.image,
            platform=arguments.platform or None,
        )
    except tools["errors"] as error:
        sys.exit(f"capture failed: {error}")
    return [frames[0] for frames in captured]


def flatten(image, background):
    """Puts an image on a solid background, or leaves its transparency alone."""
    if background == "none":
        return image
    from PIL import Image

    flattened = Image.new("RGBA", image.size, background)
    flattened.alpha_composite(image.convert("RGBA"))
    return flattened.convert("RGB")


def report(path: str, quiet: bool) -> None:
    """Says what was written, relative to the project where it is inside it."""
    if not quiet:
        relative = os.path.relpath(path, PROJECT)
        print(f"  {path if relative.startswith(os.pardir) else relative}")


def write_graphics(tools, shots, frames, arguments):
    """The raw capture, the gallery and the draft hero, into store/lite/graphics."""
    from PIL import Image

    os.makedirs(GRAPHICS, exist_ok=True)
    quiet = arguments.silent
    # A gallery image left from a longer SHOTS would otherwise survive beside the new ones.
    # Only the numbered ones: ClimberTimeHero.png, made by hand, lives here too.
    numbered = re.compile(re.escape(GALLERY_NAME).replace(r"\{index\}", r"[0-9]+") + "$")
    for name in os.listdir(GRAPHICS):
        if numbered.match(name):
            os.remove(os.path.join(GRAPHICS, name))
    if not quiet:
        print(f"Writing {os.path.relpath(GRAPHICS, PROJECT)}:")

    path = os.path.join(GRAPHICS, CAPTURE_NAME)
    with Image.open(frames[0].screen_path) as screen:
        screen.save(path)
    report(path, quiet)

    for index, frame in enumerate(frames, start=1):
        path = os.path.join(GRAPHICS, GALLERY_NAME.format(index=index))
        with Image.open(frame.watch_path) as watch:
            height = round(GALLERY_WIDTH * watch.height / watch.width)
            resized = watch.convert("RGBA").resize(
                (GALLERY_WIDTH, height), Image.LANCZOS
            )
        flatten(resized, arguments.background).save(path)
        report(path, quiet)

    # The banner is the hero scaled, not composed again: the placement is random, and
    # the banner is meant to be the same picture, smaller. generate_resized_files is not
    # called, as it would write a copy of each input under the input's own name.
    hero_inputs = [frame.watch_path for shot, frame in zip(shots, frames) if shot.hero]
    (
        tools["hero"]()
        .set_input_paths(hero_inputs)
        .set_output_directory(GRAPHICS)
        .set_hero_filename(HERO_NAME)
        .set_hero_size(*HERO_SIZE)
        .set_variations(SIZE_VARIATION, ORIENTATION_VARIATION)
        .set_max_overlap(MAX_OVERLAP)
        .prepare_output_directory()
        .process_input_images()
        .generate_hero_composition()
    )
    path = os.path.join(GRAPHICS, HERO_NAME)
    with Image.open(path) as hero:
        composed = hero.convert("RGBA")
    flatten(composed, arguments.background).save(path)
    report(path, quiet)
    path = os.path.join(GRAPHICS, HERO_SMALL_NAME)
    flatten(composed.resize(HERO_SMALL_SIZE, Image.LANCZOS), arguments.background).save(
        path
    )
    report(path, quiet)


def write_preview(tools, shots, frames, arguments):
    """Each watch render at full size, and the contact sheet, into the preview directory."""
    variants, sheet = tools["variants"], tools["sheet"]
    directory = os.path.abspath(arguments.preview)
    # Only what an earlier preview wrote is removed, so a shorter run leaves no stale frame.
    if os.path.isdir(directory):
        for name in os.listdir(directory):
            if re.fullmatch(r"frame-\d+-.*\.png", name) or name == SHEET_NAME:
                os.remove(os.path.join(directory, name))
    os.makedirs(directory, exist_ok=True)
    quiet = arguments.silent
    if not quiet:
        print(f"Writing {directory}:")

    images = []
    for index, (shot, frame) in enumerate(zip(shots, frames), start=1):
        name = shot.label or shot.moment.clock()
        slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
        path = os.path.join(directory, f"frame-{index:02d}-{slug}.png")
        shutil.copyfile(frame.watch_path, path)
        report(path, quiet)
        images.append(path)

    # The gallery, then the extra moments, each a block of rows. A tile is labelled with
    # its file's number in the gallery, so a pick can be named by it.
    blocks = []
    gallery = len(SHOTS)
    for heading, first, last, number in (
        ("Gallery (make graphics)", 0, gallery, True),
        ("Extra moments (--at)", gallery, len(shots), False),
    ):
        if first == last:
            continue
        labels = []
        for index in range(first, last):
            shot = shots[index]
            tags = "" if shot.moment.always_on else f"  {shot.moment.tags()}"
            prefix = f"{index + 1}. " if number else ""
            title = f"{prefix}{shot.label}\n" if shot.label else ""
            labels.append(f"{title}{shot.moment.clock()}{tags}")
        rows = tuple(
            variants.Row(
                "",
                tuple(
                    variants.Tile(i, labels[i])
                    for i in range(start, min(start + SHEET_COLUMNS, len(labels)))
                ),
            )
            for start in range(0, len(labels), SHEET_COLUMNS)
        )
        plan = variants.Plan("cases", (), tuple({} for _ in labels), rows)
        blocks.append(sheet.Block(heading, plan, images[first:last]))
    path = sheet.compose(
        blocks,
        os.path.join(directory, SHEET_NAME),
        title=f"Climber Time on {arguments.device}, {DATE.isoformat()}",
    )
    report(path, quiet)


def main():
    parser = argparse.ArgumentParser(
        description="Capture Climber Time's store and README images into "
        "store/lite/graphics, or with --preview a contact sheet of them for review."
    )
    parser.add_argument(
        "-d",
        "--device",
        default=DEFAULT_DEVICE,
        help=f"Product to capture on (default: {DEFAULT_DEVICE})",
    )
    parser.add_argument(
        "--preview",
        metavar="DIR",
        help="Write the frames at full size and a contact sheet into DIR, and no "
        "store image",
    )
    parser.add_argument(
        "--at",
        action="append",
        type=parse_at,
        default=[],
        metavar="HH:MM:SS",
        help="With --preview, another moment to capture: HH:MM:SS, HH:MM:fall or "
        "HH:MM:always-on; repeat for more",
    )
    parser.add_argument(
        "--background",
        default="white",
        help="Background for the gallery and hero images, or 'none' to keep them "
        "transparent (default: white)",
    )
    parser.add_argument(
        "--platform",
        help="Container platform; linux/amd64 on an arm64 machine",
    )
    parser.add_argument(
        "--image",
        default=DEFAULT_IMAGE,
        help="Container image carrying the SDK and the device definitions "
        "(default: CI's)",
    )
    parser.add_argument(
        "-q", "--silent", action="store_true", help="Print nothing but errors"
    )
    arguments = parser.parse_args()
    if arguments.at and not arguments.preview:
        parser.error("--at is for --preview; the store images are the inventory's")

    tools = load_generator()
    shots = list(SHOTS) + arguments.at
    with tempfile.TemporaryDirectory(prefix="climber-graphics-") as work:
        frames = capture(tools, shots, arguments, work)
        if arguments.preview:
            write_preview(tools, shots, frames, arguments)
        else:
            write_graphics(tools, shots, frames, arguments)
    return 0


if __name__ == "__main__":
    sys.exit(main())
