# Changelog

Everything in Climber Time that a user could notice, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project follows
[semantic versioning](https://semver.org/spec/v2.0.0.html). A section is a code release, tagged `vX.Y.Z`,
and the face's version is the one in `manifest.xml`. A release that changes only the tooling leaves
that version where it was, and carries the bundle at it.

Each section is headed `## X.Y.Z -- YYYY-MM-DD`, two hyphens and the date the tag is pushed: the
release workflow takes the section with that heading as the release's notes, and refuses a tag
without one (`tools/release-notes.py`).

Issue numbers in parentheses point at
[the tracker](https://github.com/wkusnierczyk/garmin-climber-time/issues), where the reasoning behind
each change is recorded in full.

## 0.2.1 -- 2026-11-18

A fix to the tags under the time.

### Fixed

* The letters in the grade and skill tags (4 to 8, and B, I or E) sat high in their boxes and, on
  the smaller screens, touched the outline. They are now a little smaller and centred in their
  boxes, and the outlined skill tag looks as large as the filled grade tag beside it. (#62)

## 0.2.0 -- 2026-11-18

17 more watches: Climber Time now runs on screens of at least 260 px in each direction, MIP
included, 69 watches in all.

### Added

* 15 MIP watches: the fēnix 7, 7 Pro, 7X and 7X Pro (with quatix 7 and 7X Solar, tactix 7 and
  Enduro 2), the fēnix 8 Solar (with tactix 8 Solar 51 mm) and 9 Pro Solar, the Enduro 3 and 4,
  and the Forerunner 255, 255 Music and 955 / Solar. On MIP the wall has no panel and the holds sit
  on black, and with the wrist down the whole face stays on, redrawn once a minute. (#56)
* The Venu Sq 2 and Sq 2 Music, a 320 × 360 rectangle. (#56)

## 0.1.0 -- 2026-11-16

The first release of Climber Time, the free Lite edition, for 52 AMOLED watches with screens of at
least 360 px in each direction.

### Added

* The wall fills the right half of the screen; left of it, the time on one line (HHMM), hours white
  and minutes in the route colour, in Roboto Condensed bold bitmap fonts sized for each screen.
  (#17, #30)
* Grade and skill tags under the minutes: grades 4 to 8, each climbed by a beginner (B), an
  intermediate (I) and an expert (E), one climb a minute, so every hour starts at 4B. (#30, #41, #45)
* One route per grade round, in one colour picked at random and never the previous round's. (#15)
* The climber climbs to its skill: a beginner falls onto the rope and never reaches the top, an
  intermediate may fall once or miss a jump, an expert tops out. Every climb ends with a 3 s
  lower-off on the rope.
* Always-on: the time, with grey minutes, under a checkerboard that swaps every minute, and the
  route's holds as dots that move a few pixels once a minute: at most about 2.4 % of the screen lit,
  no pixel lit three minutes running. (#4, #30)
* A launcher icon at each watch's own size, and a store cover: a climber in a high step. (#19)
* No settings; 12- or 24-hour time follows the watch.
