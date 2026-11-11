# Climber Time

A Garmin Connect IQ watch face: the time on the left, a climbing wall on the right, and a
miniature climber marking the seconds, one route per minute. The design is
[`design/DESIGN.md`](design/DESIGN.md), whose behavioural reference is the browser simulator
[`design/second-ascent-simulator.html`](design/second-ascent-simulator.html) (open it in a browser).

## Status: prototype 0.0.1

A sideloadable prototype, not a release. It shows the correct time and the climber as in the
simulator, with the settings fixed:

- Difficulty cycles through grades 4 to 8, and each grade is climbed three times, as beginner,
  intermediate, then expert: 4B 4I 4E 5B ... 8E, then again. One route per minute, so the
  cycle is 15 minutes and every hour starts at 4B.
- Each climb ends with a 3 s lower-off on the rope onto the next route's start.
- Beginners fall onto the rope and restart; intermediates may fall once or miss a jump;
  experts top out (DESIGN.md §12).
- The wall fills the right half of the screen. On the left, the time on one line (HHMM) sits
  above the grade and proficiency tags on one line, the two lines centred vertically and
  right-aligned close to the middle; the tags together are as wide as the minutes. Other routes
  dim on the wall, seconds scale every 10 s.
- The other arrangements are in the code too (`Draw.LAYOUT`, `Draw.TIME_LINEAR`): a floating
  panel on the right, and a tall centre panel with the time and tags stacked or in one line on
  either side. The full face will offer them as settings.

Not in the prototype: settings, an always-on scene (the same face is drawn in every display
mode), the custom digit font (the watch's Roboto Condensed Bold vector font stands in), and
every product other than the epix Pro (Gen 2) 47 mm.

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
```
