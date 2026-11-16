# Climber Time

[![build](https://github.com/wkusnierczyk/garmin-climber-time/actions/workflows/build.yml/badge.svg)](https://github.com/wkusnierczyk/garmin-climber-time/actions/workflows/build.yml)

<!-- TODO (#52): the Connect IQ Store link goes here once the listing is live. -->

![Climber Time on four watches](store/lite/graphics/ClimberTimeHero-small.png)

A Garmin Connect IQ watch face with a climbing wall: the time on the left, a wall of holds on the
right, and a tiny climber who marks the seconds, one climb per minute. Every 15 minutes the climber
works up through grades 4 to 8, each grade's route climbed by a beginner, an intermediate and an
expert in turn.

## Edition

**Climber Time Lite** is free.

## Features

<img src="store/lite/graphics/ClimberTime1.png" align="right" width="200" alt="Climber Time at 10:07, grade 6 by an intermediate, mid-climb">

- **The wall** fills the right half of the screen. Left of it, **the time** on one line (HHMM),
  hours white and minutes in the route colour, in Roboto Condensed bold, centred vertically.
- **The grade and skill tags** under the minutes and as wide as them, in the route colour: grades
  4 to 8, each climbed three times, by a beginner (B), an intermediate (I), then an expert (E):
  4B 4I 4E 5B ... 8E. One climb a minute, so every hour starts at 4B.
- **One route per grade round, in one colour**, picked at random from the gym's colours and never
  the previous round's; the colour says nothing about the difficulty. The other routes dim on the
  wall, and a scale on it ticks every 10 s of the climb.
- **The climber climbs to its skill**: a beginner falls onto the rope and restarts, never reaching
  the top; an intermediate may fall once or miss a jump; an expert tops out. Every climb ends with a
  3 s lower-off on the rope onto the next climb's start: the same route within a grade, a new one
  after the expert ([`DESIGN.md`](design/DESIGN.md) §11.3, §12).
- **Always-on**: the time, hours white and minutes grey, under a fine checkerboard that swaps its
  pixels every minute, and the route's holds as dots that step a few pixels once a minute; no
  climber, wall or tags. That keeps the screen far inside the AMOLED burn-in protector's limits (10 %
  of the pixels lit, no pixel lit three minutes): at most about 2.4 % lit, no pixel lit more than two
  minutes running ([`DESIGN.md`](design/DESIGN.md) §13.1).
- **No settings**: the face is drawn as designed; 12- or 24-hour time follows the watch.

## Devices

52 AMOLED watches with a screen of at least 360 px in each direction, on Connect IQ 5 or newer:
see [the list](docs/devices.md).

## Build

```sh
make build      # ClimberTime.prg for the epix Pro (Gen 2) 47 mm, or DEVICE=<product>
make sideload   # build for the watch connected by USB and copy it over
make help       # every target and variable
```

What these need, the tests and the releases are in [Development](docs/development.md).

## More

- [Devices](docs/devices.md): every supported watch, by screen, and why the others are left out.
- [Fonts](docs/fonts.md): the bitmap fonts, their licence and their sizes on every screen.
- [Graphics](docs/graphics.md): the launcher icon, the store and README images, and the hero.
- [Development](docs/development.md): build, sideload, test, CI, releases and the developer key.
- [Design](design/DESIGN.md), with its behavioural reference, the
  [browser simulator](design/climber-time-simulator.html) (open it in a browser).
- [Changelog](CHANGELOG.md).
