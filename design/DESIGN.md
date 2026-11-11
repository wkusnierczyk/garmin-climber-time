# Second Ascent. Design

Status: Design complete, ready to build  
Version: 1.0  
Date: 2026-10-15  
Owner: Wacek  
Platform: Garmin Connect IQ watch face, Monkey C  
Reference simulator: `second-ascent-simulator.html` (also published at https://claude.ai/artifact/L39yNMssUR76suoq4hqDpG)

"Second Ascent" is a working title (seconds, plus a climber ascending). See [Risks and open questions](#18-risks-and-open-questions) before naming the store listing.

## Contents

1. [Overview](#1-overview)
2. [Target devices](#2-target-devices)
3. [Screen layout](#3-screen-layout)
4. [Time display](#4-time-display)
5. [Wall and holds](#5-wall-and-holds)
6. [Routes](#6-routes)
7. [Route colour](#7-route-colour)
8. [Difficulty grades](#8-difficulty-grades)
9. [Climber figure](#9-climber-figure)
10. [Minute plan](#10-minute-plan)
11. [Motion within a minute](#11-motion-within-a-minute)
12. [Proficiency and falls](#12-proficiency-and-falls)
13. [Always-on and low-power modes](#13-always-on-and-low-power-modes)
14. [Settings](#14-settings)
15. [Implementation notes for Connect IQ](#15-implementation-notes-for-connect-iq)
16. [The simulator](#16-the-simulator)
17. [Testing and validation](#17-testing-and-validation)
18. [Risks and open questions](#18-risks-and-open-questions)
19. [Milestones](#19-milestones)
20. [Appendix A. Constants](#20-appendix-a-constants)
21. [Appendix B. Algorithms](#21-appendix-b-algorithms)

## 1. Overview

A watch face with the time as digits on the left and a climbing wall on the right. A miniature climber marks the seconds: one route per minute, climbed hold by hold, one limb move at a time. Each route has its own hold colour, so the colour changes as the minutes go by.

On top of that core, the face can tell a small story: routes get harder through the hour, the climber can fall and be caught by the rope, downclimb the route he just climbed, get lowered off at the quarter hours, and take a beer break on the hour.

The design was developed and tuned in a browser simulator (`second-ascent-simulator.html`). It reproduces the face pixel for pixel at each device resolution, ticks at 1 Hz like the watch, and implements every rule in this document. **The rules and constants in this document are authoritative.** The simulator is the behavioural reference: where this document is silent, match the simulator. If the two disagree, fix the simulator.

### 1.1 Goals

- Readable time at a glance, with digits that never shift sideways as they change.
- Seconds you can read roughly from the climber's height, with an optional fixed scale for orientation.
- Motion that is calm at 1× speed: one small move per second, with occasional events (a fall, a jump, a lower-off, a beer) that reward a second look.
- Every minute boundary is seamless: the climber's position at :59 → :00 never jumps.
- Deterministic: the whole face is a pure function of local time and settings, so any frame can be reproduced and tested.

### 1.2 Non-goals for v1

- Complications or data fields beyond the time (date, battery, heart rate).
- Real climbing data, route databases or gym integration.
- Sound or vibration.
- Animation above 1 Hz on the watch. Smooth motion exists in the simulator only, as a preview.

## 2. Target devices

| Class | Reference resolution | Notes |
|---|---|---|
| Round AMOLED | 454 × 454, 416 × 416 | Primary target. Always-on mode with the lit-pixel limit (§13.1). |
| Round MIP, 64 colours | 280 × 280, 260 × 260 | Colours quantize to the 64-colour palette. Per-second updates in low power go through partial updates (§13.2). |
| Rectangular AMOLED | 320 × 360 | Layout adapts (§3). Check the target list for current rectangular models. |

All geometry is expressed as fractions of the screen width W and height H, so other sizes scale. The device list is fixed in milestone M0.

## 3. Screen layout

### 3.1 Zones

- **Time zone** on the left: the digits (§4).
- **Wall zone** on the right: the wall, its holds, the climber, the rope, the scale ticks and the tags.

### 3.2 Wall area

User setting **Wall area**: a floating panel or the right half of the screen.

| | Floating panel, round | Floating panel, rect | Right half, round | Right half, rect |
|---|---|---|---|---|
| Wall x | 0.555 W to 0.555 W + width·W | 0.56 W to min(0.95 W, 0.56 W + 1.3·width·W) | 0.5 W to W | 0.5 W to W |
| Wall y | 0.17 H to 0.83 H | 0.07 H to 0.93 H | 0 to H (clipped by the bezel) | 0 to H |
| Route region x | wall inset by 12 % of wall width each side | same | 0.56 W to 0.80 W | 0.56 W to 0.93 W |
| Route region y | wall inset by 0.03 H top and bottom | same | 0.15 H to 0.86 H | 0.08 H to 0.94 H |
| Digits centre x | 0.30 W | 0.285 W | 0.27 W stacked, 0.25 W linear | same |
| Rope anchor y | wall top + max(3 px, 0.012 H) | same | route top − 0.035 H | same |

Wall **width** (floating panel only) is a setting from 0.22 to 0.36 of W, default 0.30. The floating panel has a corner radius of 0.03 W.

In right-half mode the route region stays where the bezel leaves room on a round screen; the rest of the half is wall and, on a fixed wall, unused holds (§5.4).

### 3.3 Tags

Two small tags sit side by side at mid-height (y = H/2), centred on the panel's right edge (floating panel) or in the strip right of the route ((route right + W)/2, right half):

- **Grade tag** (setting **Show grade tag**, default on): filled in the route colour, the grade number cut out in dark (route colour mixed 82 % toward black).
- **Proficiency tag** (setting **Show proficiency tag**, default on): filled in the wall colour, outlined in the route colour, letter B, I or E in the route colour.

Order is [grade][proficiency]. If one is hidden the other takes the first slot. Sizes in Appendix A.6. The climber is drawn over the tags.

### 3.4 Seconds scale

Setting **Seconds scale**: off, every 10 s (default), every 15 s or every 5 s. The ticks are **fixed**: evenly spaced between the bottom and top of the route region, identical every minute, for orientation only. They do not follow the climber's actual height (which varies with grade, jumps and falls).

- Tick at second s, for s = step, 2·step, … < 60: y = lerp(route bottom, route top, s/60).
- x = wall left + max(2 px, 0.008 W). Major ticks (s divisible by 15) are max(5 px, 0.016 W) long, minor ticks max(3 px, 0.008 W). Thickness max(1.5 px, 0.005 W). Colour: the current route colour.
- Every 10 s gives five ticks (10 … 50) with 30 as the only major tick.

## 4. Time display

### 4.1 Layout

Setting **Time layout**:

- **Stacked** (default): HH above MM. Font size 0.30 H × size. Hours centred at y = 0.365 H, minutes at 0.635 H.
- **Linear**: HHMM on one line, **no separator**. Font size 0.19 H × size, centred at y = 0.5 H.

**Size** is a setting from 0.8 to 1.2 (default 1.0). In both layouts the font shrinks if needed so the block fits within 2·min(digits x − 0.03 W, wall x − digits x − 0.03 W), keeping it clear of the bezel and the wall.

### 4.2 Fixed cells

Every digit is drawn centred in its own cell of width 1.04 × width("0"), whatever the font. Digits never shift as the time changes, even with proportional fonts. Vertical centring uses the ascent of "0". Draw each digit separately at its cell centre; never draw the time as one string.

### 4.3 Font

Roboto, bold by default. Alternatives offered in the simulator: Roboto Condensed, Rubik, Barlow Semi Condensed; weights bold, medium, regular. Requirement: **zeros without a dot or slash**. On the watch these are custom bitmap fonts with the digits only (§15.4).

### 4.4 Colour and format

| Setting | Values | Default |
|---|---|---|
| Hours colour | white (#F6F6F6), grey (#969C99), route colour | white |
| Minutes colour | route colour, white, grey | route colour |
| 24-hour | on, off (12-hour shows 1 to 12) | on |
| Leading zero on hours | on, off | on |

The leading-zero setting applies to both layouts: linear shows 0949 with it on and 949 with it off.

## 5. Wall and holds

### 5.1 Surface

Setting **Surface**: slate panel (#24292D, default), plywood (#5C4A37), or none (holds on black).

**T-nut grid** (setting, default on): dots on a staggered grid of spacing g = max(7 px, 1.15·dy₀), dot radius max(0.8 px, 0.07 g), rows offset alternately by 0.4 g and 0.9 g. Colour: the wall mixed 14 % toward white (slate) or black (plywood); #222222 on no wall. Clipped to the wall area. The grid depends only on dy₀ (§6.2), so it does not change with grade.

### 5.2 Hold types

All holds are drawn from primitives available on Connect IQ (ellipses, rounded rectangles, circles, polygons). s is the hold size.

| Type | Shape | Detail |
|---|---|---|
| Jug | ellipse 1.24 s × 0.84 s | darker pocket ellipse below centre (colour mixed 38 % to black); bolt dot if s > 8 px |
| Crimp | rounded rect 1.1 s × 0.4 s, rotated by rot/2 | |
| Sloper | ellipse 1.4 s × 1.0 s | lighter highlight (colour mixed 35 % to white), bolt dot if s > 8 px |
| Pinch | rounded rect 0.44 s × 1.1 s, rotated by rot | |
| Edge | thin rounded rect 1.6 s × max(1.5 px, 0.16 s), rotated by 0.3·rot | the "thin long line" of hard grades |
| Micro | circle radius max(1.2 px, 0.26 s) | tiny chip |
| Foot | ellipse 0.9 s × 0.64 s | footholds below the start |
| Dot, foot dot | circle radius 0.45 s, 0.32 s | used when **Hold shapes** = plain dots |

Rotation rot is uniform(−0.45, 0.45) rad. Bolt dots are colour mixed 60 % to black, radius max(1 px, 0.07 s).

**Volumes** (setting, default on, not with plain dots): triangles of radius 1.7 to 2.3 × hold size, rotated randomly, drawn behind the holds. On a per-minute wall they take the route colour mixed 45 % toward the wall; on a fixed wall they are neutral (wall mixed 13 % toward white).

### 5.3 Wall features

**No holds below the start.** Nothing is placed below the lowest start footholds (route bottom, level −4): not other routes' holds, not unused fixed-wall holds. The climber always starts at the bottom, so holds below him would make no sense.

Setting **Wall features**:

- **New holds every minute** (default). Each route generates its own holds (§6.4). Optionally **other routes on the wall** (setting, default on): three colours chosen per day, 11 holds each, scattered over the wall, drawn dim (their colour mixed 62 % toward the wall). Skipped when the colour equals the current route's, or within 1.3 hold sizes of a route hold.
- **Fixed wall, new path highlighted**. One fixed set of holds (§5.4). Each minute a path is picked through it (§6.5); path holds are drawn in the route colour, all others in a neutral grey (wall mixed 26 % toward white). The other-routes setting is disabled in this mode.

### 5.4 The fixed wall

Generated once from the **wall number** (setting `wallSeed`, default 1; "Generate new wall" increments it). It depends only on the wall number, the screen, the moves-per-minute setting, the wall area, width and climber size, never on the time or grade.

- One row per level k = −4 … L₀ (§6.2), at y = route bottom − (k+4)·dy₀ + uniform(−0.15, 0.15)·dy₀.
- Four holds per row, at x = route left + clamp((j + 0.5 + stagger + uniform(−0.2, 0.2))/4, 0.05, 0.95)·route width, with stagger −0.22 on even rows and +0.22 on odd rows.
- Types from the full mix (jug 0.25, crimp 0.20, sloper 0.15, pinch 0.15, edge 0.12, micro 0.13); size hs₀ × type factor × uniform(0.92, 1.08). Type factors: jug 1.3, sloper 1.15, pinch 1.0, crimp 0.85, edge 0.95, micro 0.62. Rows below 0 are footholds of size 0.65 hs₀.
- In right-half mode, up to 40 extra holds are scattered over the rest of the half (inside the bezel, outside the route region, from 0.04 H down to the route bottom). The path never uses them.
- Three neutral volumes.

### 5.5 Chalk

Setting **Chalk on used holds** (default off): holds the climber has already used on this attempt get a small white dab (55 % white, radius max(1 px, 0.2 s), up-left of centre). On a downclimb the holds above the hands are chalked instead. No chalk while the climber is on the rope or sitting.

### 5.6 Start and finish tape

Short strips in the route colour: one above the top hold, and one under each of the two start holds (levels 0 and 1). Width max(4 px, 0.9 hs₀), thickness max(1.5 px, 0.16 hs₀).

### 5.7 Rope and anchor

A ring at the rope anchor (§3.2), colour #969C98. The rope is a straight line from the anchor to the climber's harness (hip centre), colour #D6D4C8, width max(1 px, 0.025 c). It is shown whenever the climber hangs on it (falls, lower-offs) and, with setting **Show rope while climbing** (default off), all the time.

## 6. Routes

### 6.1 Levels and limbs

A route is a ladder of **levels** k = −4 … Lmax. Even levels are on the climber's left, odd on his right. Levels below 0 are footholds only.

The climber's four limbs start on fixed levels and move in a fixed cycle, each move taking one limb up two levels (to the next hold on its side):

| Limb | Start level | Order in cycle |
|---|---|---|
| Left hand (LH) | 0 | 1 |
| Left foot (LF) | −4 | 2 |
| Right hand (RH) | 1 | 3 |
| Right foot (RF) | −3 | 4 |

With M moves per route, limb o (0 = LH, 1 = LF, 2 = RH, 3 = RF) makes n(o) = floor((M − o + 3)/4) moves, and Lmax = max(2·n(0), 1 + 2·n(2)). Feet stay four levels below the hands.

### 6.2 Spacing

- **Moves per minute** (setting 15, 20, 30 or 60, default 30) defines the grade-6 route: L₀ = Lmax(moves) and dy₀ = route height / (L₀ + 4). dy₀ fixes the climber size (§9.1) and the base hold size hs₀ = clamp(0.62·dy₀, 3.5 px, 15 px).
- Each grade has a spacing factor sp (§8). The route's move count M is the largest M ≥ 4 with Lmax(M) ≤ 1 + (L₀ − 1)/sp. Sparser grades get fewer, longer moves in the same wall height.
- Level y: for k ≤ 1, y = route bottom − (k + 4)·dy₀. For k > 1, y = route bottom − 5·dy₀ − (k − 1)·dy, with dy = (route height − 5·dy₀)/(Lmax − 1). The start (levels −4 … 1) keeps grade-6 spacing at every grade, so every route starts in the same stance.

### 6.3 Determinism

Every random choice is drawn from a seeded generator (mulberry32 over a 32-bit integer hash, Appendix B.1), seeded from the route key (the local minute the route starts, §10) or the day, never from wall-clock randomness. The same minute always produces the same route.

### 6.4 Per-minute holds

Seeded from the route key. With e = (grade − 4)/4 (0 at grade 4, 1 at grade 8), centre cx and half-width h of the route region, a route-level phase and lean:

```
x_k = cx + 0.30·h·sin(0.33·k + phase) + 0.18·h·lean·k/Lmax + side_k·h·(0.16 + 0.30·r + 0.08·e)
      clamped 0.6·hs₀ inside the route region
y_k = levelY(k) + (r − 0.5)·(k ≤ 1 ? dy₀ : dy)·0.25
type = foot (k < 0), jug (top two levels), otherwise from the grade's mix
size = 0.65·hs (k < 0), otherwise hs·uniform(0.9, 1.15), micro × 0.75     where hs = hs₀·sz(grade)
```

Then:

1. **Shared start** (downclimb mode only, §10): levels ≤ 1 move to positions seeded only by the level, blended back to the route's own positions by level 4 (weight (4 − k)/3). All routes then share their start holds, so a climber who ends a descent is already standing on the next route's start.
2. **Each side always climbs**: for k = −2 … Lmax, y_k ≤ y_{k−2} − 0.6·min(dy, dy₀).
3. **Jump targets** (§8.2): the hold a jump lands on becomes a jug of size 1.05 hs₀ and moves up by 0.6·dy.
4. **Volumes**: one or two, near random levels 3 … Lmax − 3.

### 6.5 Paths on the fixed wall

For each path level k, pick a hold from the fixed wall's row nearest to levelY(k): row = clamp(round((route bottom − levelY(k))/dy₀) − 4, −4, L₀). Score each hold in the row and take the lowest:

```
target x = path centre_k + side_k·h·(0.32 + 0.12·e)
score    = |x − target|/h + fit + noise
fit      = |(sizeFactor − 0.62)/0.68 − (1 − e)| · 0.9      big holds suit easy grades, small holds hard ones
noise    = (hash(sid·31 + holdId) mod 1000)/4000           per-minute variety
```

The start band (levels ≤ 1 in downclimb mode) takes the nearest hold with no fit or noise, using a seed that does not depend on the minute, so it is shared by all routes.

## 7. Route colour

One colour per **route**, not per minute: in downclimb mode a route spans two minutes and keeps its colour (§10).

Setting **Colour per route**:

- **Gym colours, shuffled** (default): from the gym palette, never the same twice in a row within the hour (Appendix B.2).
- **Gym colours, in order**: cycling through the palette.
- **Hue wheel**: hue = (route start minute mod 60) × 6°, saturation 85 %, lightness 58 %. The colour itself encodes the minute.

Gym palette: Yellow #F7C948, Green #34C46A, Blue #3A86FF, Red #EF4444, Purple #A06CF0, Orange #FF8C2B, Pink #FF6FB0, Teal #22C3C3, White #E8E8E8.

The colour index is hour·60 + route ordinal within the hour (§10), so consecutive routes are consecutive indices even when routes span two minutes or a beer break intervenes.

## 8. Difficulty grades

### 8.1 Grade table

Grades run from 4 (very easy) to 8 (very hard).

| Grade | Spacing sp | Hold size sz | Hold mix | Jumps per route | Jump height | Jump duration |
|---|---|---|---|---|---|---|
| 4 | 0.80 | 1.35 | jug 0.75, pinch 0.15, sloper 0.10 | 0 | | |
| 5 | 0.90 | 1.15 | jug 0.50, pinch 0.20, sloper 0.15, crimp 0.15 | 0 | | |
| 6 | 1.00 | 1.00 | jug 0.30, crimp 0.25, sloper 0.20, pinch 0.25 | 0 | | |
| 7 | 1.12 | 0.76 | jug 0.05, crimp 0.35, sloper 0.20, pinch 0.15, edge 0.25 | 2 | 0.40 c | 2 moves |
| 8 | 1.24 | 0.56 | crimp 0.25, edge 0.35, sloper 0.10, micro 0.30 | up to 4 | 0.55 c | 2.5 moves |

At the default 30 moves per minute this gives about 37 moves at grade 4, 30 at grade 6 and 22 at grade 8. Grade 6 is the reference: it reproduces the layout without grades.

### 8.2 Jumps (dynos)

- Jumps are hand moves (even move indices) between move 2 and M − 4, at least 4 moves apart, chosen by a seeded shuffle. Fewer fit on short routes; none when M < 8.
- A jump takes longer than a normal move (the "jump duration" column, in units of a normal move), so the flight is spread over several 1 Hz ticks and is visible on the watch.
- During the jump, with air = sin(π·f) for move fraction f: the body (shoulders, hips, head) rises by air × jump height; the reaching hand leads (at least 0.32·c·air above its shoulder); the other hand lets go and reaches up (toward shoulder + (±0.05 c, −0.34 c)); the feet leave the wall and dangle (toward hip + (±0.08 c, 0.40 c)). All blended by air, so the jump starts and ends on the holds.
- The landing hold is a jug placed 0.6·dy higher than its level (§6.4), so there is a visible gap.
- **Nobody jumps down**: downclimbs never use jumps (§11.4).
- Whether a jump succeeds depends on proficiency (§12.2): the expert always makes it, the intermediate may miss once and retry, the beginner never makes it.

### 8.3 Progression

Setting **Rising difficulty** (default on), with **Easiest grade** (default 4) and **Hardest grade** (default 8). With n = hardest − easiest + 1:

```
grade(route) = easiest + (floor(ordinal / k) mod n)        k = 3 with proficiency cycling (§12.3), else 1
```

The ordinal counts routes from the start of the hour (§10), so every hour starts at the easiest grade. With rising difficulty off, the first selector is a single fixed **Grade**.

## 9. Climber figure

### 9.1 Proportions

All in units of the climber size c = min(5·dy₀, 0.85·wall width) × climberSize. The cap applies to the base size before scaling, so every step of the setting changes the size proportionally. **Climber size** is a setting from 0.8 to 2.0 in steps of 0.05 (default 1.0). On the 454 px screen at default settings c ≈ 68 px, and 136 px at 2.0. Holds do not scale with the climber, so a large climber crouches more on the same holds.

| Part | Size |
|---|---|
| Upper arm, forearm | 0.19 c each |
| Thigh, shin | 0.22 c each |
| Torso (hip to shoulder) | 0.30 c |
| Shoulder half-width | 0.08 c |
| Hip half-width | 0.055 c |
| Head | radius 0.085 c, centre 0.14 c beyond the shoulders along the torso |

Drawn as lines with round caps and a filled head: arms max(1.5 px, 0.06 c), legs max(1.8 px, 0.07 c), torso max(2.5 px, 0.13 c). On the watch, emulate round caps by filling circles at joints if needed.

**Colour** setting: white #F5F5F5 (default), chalk grey #C4CAC6, amber #FFBC54.

### 9.2 Pose from holds

1. Each limb end is on its current hold. The moving limb (move index i = floor(m), fraction f) travels from its hold to the one two levels up, eased (in-out quadratic), swinging outward by sin(π·f)·0.07·c.
2. **Feet below hands** (constraint): each foot's y is at least max(hand y) + 0.12 c. A foot that would rise higher comes off its hold and hangs.
3. With hand centre (hx, hy), foot centre (fx, fy) and gap = max(fy − hy, 0.2 c):
   - shoulder centre = (0.6·hx + 0.4·fx, hy + min(0.30 c, 0.30·gap))
   - hip centre = (0.6·fx + 0.4·hx, fy − min(0.34 c, 0.34·gap))
   Spacing proportional to the gap means a crouched climber (dense grades) gets shorter but can never flip.
4. Fix the torso length to 0.30 c about the midpoint. **Head above waist** (constraint): the torso direction's vertical component is at most −0.75 (no more than about 41° from vertical).
5. Shoulders and hips are offset perpendicular to the torso. Elbows and knees come from two-bone IK (Appendix B.5), bending outward (left limbs to the left, right limbs to the right). A limb stretched beyond its reach is drawn straight toward its target.
6. Jump flight is applied on top (§8.2).

### 9.3 Hanging pose

Used for falls and lower-offs. From the harness (hip) point H: shoulders 0.30 c above, hands on the rope (left at (−0.03 c, −0.16 c) and right at (+0.03 c, −0.03 c) from the shoulder centre), feet at (±0.16 c, +0.34 c) from H, walking the wall: ±sin(phase)·0.05 c.

### 9.4 Sitting pose

Used for the beer break (§11.6). Ground y = route bottom + 0.03 H; the climber sits at the mean x of the two start footholds, hips 0.05 c above the ground. Knees at (±0.14 c, −0.14 c) from the hips, feet at (±0.21 c) on the ground. Left hand rests on the left knee. Right hand holds the bottle (§11.6).

## 10. Minute plan

Each hour is laid out as 60 slots. A slot is one minute of one of four kinds:

| Kind | Meaning |
|---|---|
| line | climb (with attempts and falls per proficiency), then a lower-off on the rope at the end of the minute |
| up | climb the whole minute, ending on top or wherever the attempt ended |
| down | downclimb the same route from where the up minute ended, the whole minute |
| beer | sit at the foot of the wall with a beer; the next route is already on the wall |

Every non-beer slot belongs to a **route** with a key (the local minute the route starts) and an **ordinal** (its index among the hour's routes). Up and down minutes of a pair share one route, key, ordinal, colour and grade. Beer slots show the next route.

### 10.1 Building an hour

Settings involved: **Descent** (lowered on the rope, default; or downclimb the next minute), **Lowered on the rope at :00 :15 :30 :45** (downclimb mode only, default off), **Beer break on the hour** (default off), proficiency (§12).

```
special[] = none
if beer:                     special[0] = beer; if downclimb mode: special[1] = beer
if downclimb and quarters:   special[q] = line for q in 0, 15, 30, 45 not already beer

i = 0
while i < 60:
  if special[i] == beer: beer slot; i += 1
  else if rope mode or special[i] == line: line slot (new route); i += 1
  else:
    j = end of the run of non-special slots starting at i
    if no beginners are involved and (j − i) is odd:
      line slot at i (new route); i += 1        spare minute goes on the rope at the START of the run
    while i < j:
      if the next route's proficiency is beginner or only one slot is left:
        line slot (new route); i += 1           beginners never downclimb
      else:
        up slot at i, down slot at i+1 (one new route); i += 2
beer slots take the key and ordinal of the next route
```

Results:

- Rope mode: every minute is a line minute.
- Downclimb mode: up and down pairs, 30 routes an hour.
- With quarters: rope at :00, :15, :30 and :45, 7 pairs in each 14-minute stretch. Exactly one rope descent per quarter for intermediate and expert climbers.
- With beer and quarters: beer :00 and :01, rope :02 (the odd stretch's spare minute, never next to a quarter rope), pairs to :14, rope :15, and so on.
- With beer in rope mode: beer at :00 only.
- Beginner routes are always single line minutes, even in downclimb mode.

### 10.2 Seamless boundaries

The pose at second 60 of a minute equals the pose at second 0 of the next:

- line → anything: the lower-off lands on the next route's start pose (§11.3).
- up → down: same route; the down minute starts from where the up minute ended.
- down → up or line: all routes share their start holds in downclimb mode (§6.4).
- beer: sits down from and stands up into the start pose of its route (§11.6).
- An attempt always ends on a completed move (§12.2), never mid-reach or mid-jump.

## 11. Motion within a minute

### 11.1 Ticks

The watch updates once per second. At second s the pose is computed for time s exactly (fraction 0). Smooth sub-second motion exists in the simulator as a preview only.

### 11.2 Climbing pace

A climb of M moves must finish by T seconds (T = 59 for an up minute, 59 − lower-off for a line minute). Moves take equal time, except jumps, which take their jump duration (§8.1). Time maps to move progress m through the cumulative weights (Appendix B.4). The expert's climb finishes exactly at T on the top hold.

### 11.3 Lower-off

Setting **Lower-off after top-out**: off, 2, 3 (default), 4 or 5 seconds (L). In a line minute the climb runs to T = 59 − L; then from T to 60 the climber is lowered: the hip moves (eased) from where the climb ended down to the next route's start hip, in the hanging pose (§9.3) with walking feet, blended from the climbing pose over the first 20 % and into the next route's start pose over the last 20 %. The wall keeps this route's colour until :00. With L = 0 the climber resets instantly at :00.

### 11.4 Downclimb

A down minute replays the route's moves in reverse, from the move where the up minute ended (endM) to 0, at an even pace over 59 s: m = endM·(1 − s/59). Feet lead downward, as real downclimbing does. No jumps and no jump timing. After a failed attempt (§12) endM is lower, so the downclimb is slower; this is intended (a tired climber).

### 11.5 Falls

See §12.2.

### 11.6 Beer break

The beer break lasts 60 s (rope mode) or 120 s (downclimb mode), local time τ from the start of the break:

- Sits down from the start pose over the first 2 s; stands back up into the start pose over the last 3 s.
- A sip every 8 s: for the first 40 % of each 8 s cycle the bottle hand moves from resting by the right knee to the mouth (head + (0.07 c, 0.06 c)), following sin(π·phase/0.4).
- Bottle: amber glass #CD802A with a cream label band #EEE0BA; length max(9 px, 0.30 c), width max(3.5 px, 0.105 c), neck 40 % of the width; rotated from −0.15 rad (upright) to −2.0 rad (tipped to the mouth).
- The wall shows the next route, so the climber is reading it over his beer.

## 12. Proficiency and falls

### 12.1 Levels

Setting **Proficiency**:

| Level | Falls | Jumps (grades 7 and 8) | Tops out |
|---|---|---|---|
| Expert (default) | never | always makes them | always |
| Intermediate | on about half the routes, falls once onto the rope mid-route (at 40 to 60 % of the route, always between moves, never off a jump), is lowered, restarts and runs out of time | on routes without a rope fall, each jump is missed with probability 0.5: the hand falls short, he drops back onto the holds he jumped from, then makes it on the second try | only when he does not fall onto the rope (about 51 % in testing); missed jumps still top out |
| Beginner | falls on every attempt that leaves time for another (at 15 to 40 % of the route), restarts each time; the last attempt stops short at 80 % of the route at most | never makes them: if an attempt reaches a jump, he comes off at the top of the leap, straight onto the rope; if there is no time left for a fall, he stalls below the jump | never |

Measured over 300 routes each at default settings: expert 300 top-outs; intermediate 153 top-outs, 0.49 falls per route; beginner 0 top-outs, 2.34 falls per route. On grade 7 and 8 routes with jumps (200 per case): expert always tops out; intermediate tops out on every route without a rope fall, with about 0.5 missed jumps per jump; the beginner never gets past his first jump, and most of his falls (402 of 633 at grade 7, 764 of 817 at grade 8) happen at it.

**Beginners never downclimb**: their routes are always single line minutes (§10.1).

### 12.2 Attempt plan

For a climb that must end at T (Appendix B.6):

1. Decide the number of falls allowed (expert 0; intermediate 1 with probability 0.5; beginner unlimited), from a seed of the route key and level.
2. **Missed jumps** (intermediate without a rope fall): each jump is missed with probability 0.5. A missed jump inserts a failed attempt before the real jump, lasting as long as the jump. The whole climb is paced faster to absorb that time (seconds per unit = T / (total weight + missed jump weight)), so he still tops out at T.
3. Repeat: draw a fall height. Beginner: if his first jump comes before it, the fall height becomes the middle of that jump (he comes off at the top of the leap). Intermediate: if it lands inside a jump move, it moves to the start of that move. If climbing to it, falling and being lowered would leave less than 3 s, stop falling. Otherwise: climb segment to the fall height at normal pace, then a fall segment (1 s drop and hang, 2.5 s lower to the start), then start again from the bottom.
4. The final segment climbs at normal pace until T, capped at 80 % of the route and at the start of the first jump for beginners. Its end is rounded **down to a whole move** (endM), so the attempt ends settled on holds.

**Missed jump pose**: at the move before the jump, with phase f from 0 to 1, air = 0.85·sin(π·f) applied as in §8.2, and the reaching hand travels only 0.65·sin(π·f) of the way to the target hold, then returns. He ends on exactly the holds he jumped from.

### 12.3 Fall

- **Drop** (first 1 s): over 0.35 s (eased) the climber goes from his climbing pose to the hanging pose with the harness 0.45 c lower (never below the start hip), swinging sideways by sin(9 t)·0.05 c. The rope is shown.
- **Lower** (next 2.5 s): the hanging pose descends to the start hip with walking feet, blending into the start pose over the last 25 %.
- Chalk is cleared while on the rope.

### 12.4 Proficiency cycling

Setting **Cycle proficiency on each grade** (default off). When on, each grade is climbed three times, as beginner, intermediate, then expert: 4B, 4I, 4E, 5B, 5I, 5E, … (proficiency = [B, I, E][ordinal mod 3], grade from floor(ordinal/3), §8.3). The single proficiency selector is disabled. In downclimb mode a grade then takes 5 minutes: 4B (1 minute, rope), 4I (up, down), 4E (up, down).

### 12.5 The route tag in the simulator

The simulator's route tag reports the attempt: "no falls · tops out", "1 fall · no top", "2 falls · no top".

## 13. Always-on and low-power modes

### 13.1 AMOLED always-on

Drawn once per minute:

- Digits at 55 % brightness (colour scaled toward black).
- No wall, T-nuts, ticks or tags. The route's holds as dots of radius max(1.2 px, 0.18·size) in the route colour at 60 %.
- Climber at 50 %, static: start pose (line and up minutes), top pose (down minutes), sitting (beer).
- Burn-in shift of the whole drawing by ((m mod 3) − 1)·2 px horizontally and ((floor(m/3) mod 3) − 1)·2 px vertically, m = absolute minute.
- Target: lit pixels within the Connect IQ always-on limit (believed to be 10 %; confirm against current documentation). The simulator measures the lit share (any channel > 10 on a 2× subsampled grid).

### 13.2 MIP low power

MIP screens stay on; seconds update through `onPartialUpdate` with a clip region. The changed region per second is the union of the climber's bounding box at s and s − 1 (padded by max(2 px, 0.06 c), including the head), plus the rope anchor when the rope is or was shown. At :00 the whole face redraws. Typical climbing seconds on a 454 px screen: about 2.5 % of the screen; lower-off seconds are much taller (anchor to climber). Validate the budget in M0 (§15.2).

### 13.3 Colour on MIP

All colours quantize to the 64-colour palette (each channel 0x00, 0x55, 0xAA or 0xFF). Check that the route colours stay distinct after quantization and that dim holds remain visible.

## 14. Settings

### 14.1 User settings

These become Connect IQ properties (§15.5). Keys match the simulator's settings object and its exported JSON.

| Key | Values | Default | Section |
|---|---|---|---|
| font | Roboto, Roboto Condensed, Rubik, Barlow Semi Condensed | Roboto | §4.3 |
| weight | 700, 500, 400 | 700 | §4.3 |
| layout | stacked, inline (linear HHMM) | stacked | §4.1 |
| digitSize | 0.8 to 1.2 | 1.0 | §4.1 |
| hourColor | white, grey, route | white | §4.4 |
| minColor | route, white, grey | route | §4.4 |
| hour24 | on, off | on | §4.4 |
| leadZero | on, off | on | §4.4 |
| palette | shuffle, cycle, hue | shuffle | §7 |
| moves | 15, 20, 30, 60 | 30 | §6.2 |
| features | random, fixed | random | §5.3 |
| wallSeed | integer ≥ 1 | 1 | §5.4 |
| holdStyle | mixed, dots | mixed | §5.2 |
| volumes | on, off | on | §5.2 |
| otherRoutes | on, off | on | §5.3 |
| chalk | on, off | off | §5.5 |
| grades | on, off | on | §8.3 |
| gMin | 4 to 8 | 4 | §8.3 |
| gMax | 4 to 8 | 8 | §8.3 |
| showGrade | on, off | on | §3.3 |
| showProf | on, off | on | §3.3 |
| wallStyle | slate, plywood, none | slate | §5.1 |
| wallClip | panel, half | panel | §3.2 |
| wallWidth | 0.22 to 0.36 | 0.30 | §3.2 |
| tnut | on, off | on | §5.1 |
| scale | off, 10, 15, 5 | 10 | §3.4 |
| climberColor | white, grey, amber | white | §9.1 |
| climberScale | 0.8 to 2.0 | 1.0 | §9.1 |
| prof | expert, intermediate, beginner | expert | §12.1 |
| profCycle | on, off | off | §12.4 |
| descent | line (rope), wall (downclimb) | line | §10 |
| lower | 0, 2, 3, 4, 5 s | 3 | §11.3 |
| topRope | on, off | off | §5.7 |
| quarters | on, off (downclimb mode only) | off | §10.1 |
| beer | on, off | off | §10.1 |

Dependencies: wallWidth applies to the floating panel only; otherRoutes to per-minute walls only; gMax and proficiency-tag letters follow grades and profCycle; prof is ignored while profCycle is on; lower applies to rope mode, quarter minutes and beginner minutes.

### 14.2 Simulator-only controls

Screen, always-on or low-power mode, per-second redraw region overlay, play and pause, speed (1×, 4×, 15×, 60×), seconds motion (1 Hz tick or smooth), now, ±1 minute, jump to :55, second slider, set time, jump to the next route of a grade, generate new wall, copy config JSON, reset.

A partner logo under the time is not part of the design and must not be implemented in the published face; a branded build, if ever made, is a private variant outside this document.

## 15. Implementation notes for Connect IQ

### 15.1 Structure

- **Pure core**: time → (slot, route key, ordinal, grade, proficiency, colour) → route (holds, levels, jumps, timing weights, attempt plan) → pose at second s. No `Dc` or Toybox state, so it can be unit-tested against the simulator.
- **Per-minute cache**: build the hour plan once per hour and the current route (and the next, for lower-off targets) once per minute. Per second, only the pose is computed.
- **Renderer**: static layer (wall, T-nuts, holds, volumes, tape, ticks, tags) and dynamic layer (rope, climber, bottle). Digits change once per minute.

### 15.2 Per-second drawing

- High power (both screen types): full redraw each second is the simple path. Consider caching the static layer in a `BufferedBitmap` if the hold drawing is too slow; check memory on the target devices first (a right-half bitmap at 454 px is large).
- MIP low power: in `onPartialUpdate`, set the clip to the changed region (§13.2), redraw the static layer within it (blit from the buffered bitmap, or redraw only holds intersecting the clip), then the climber. Measure the average cost against the partial update budget in M0, especially for lower-off seconds.

### 15.3 Random numbers and integers

The simulator's hash and mulberry32 (Appendix B.1) rely on 32-bit unsigned arithmetic (`Math.imul`, `>>>`). In Monkey C, use `Long` for products and mask to 32 bits (`& 0xFFFFFFFF`), and emulate the unsigned right shift with a mask after `>>`. Seeds such as key·1009 exceed 32 bits; the simulator truncates them to their low 32 bits (`n | 0`), and the watch must do the same. Golden-value tests (§17.2) catch any mismatch.

The **absolute minute** is local minutes since the Unix epoch: floor((UTC seconds + time zone offset)/60), from `Time.now()` and `System.getClockTime().timeZoneOffset`.

### 15.4 Fonts

- Digits: custom bitmap fonts (digits 0 to 9 only) generated per device at the stacked and linear sizes, Roboto bold by default. Supporting the alternative fonts and weights multiplies resources; consider shipping Roboto only in v1.
- Fixed digit cells (§4.2) are mandatory.

### 15.5 Settings delivery

All user settings in §14.1 as properties with phone-app settings. Ranges become lists where Connect IQ requires it (digitSize, wallWidth, climberScale as a few steps). Read at start and in `onSettingsChanged()`; clear the route and plan caches on change.

### 15.6 Drawing primitives

Everything in the simulator maps to `fillEllipse`, `fillRoundedRectangle`, `fillCircle`, `fillPolygon`, `drawLine` with `setPenWidth`, and `drawBitmap`. Enable anti-aliasing where available (API 3.2 and later). Rotated rounded rectangles (crimps, pinches, edges) become 4-point polygons on the watch.

## 16. The simulator

`second-ascent-simulator.html` is self-contained (fonts from Google Fonts). Open it in a browser.

- Renders at the device's native resolution, quantizes colours on MIP screens, and ticks at 1 Hz.
- Settings persist in the browser's local storage.
- **Readouts**: route tag (colour, grade, set time, holds, moves and jumps, moves per tick, climber height, this minute's kind, attempt outcome) and diagnostics (lit pixels, always-on limit, per-second redraw region).
- **Filmstrip**: six frames of the current minute (with lower-off frames when relevant), and the next 12 minutes' colours, kinds (↑ ↓ ⤓ 🍺) and grade plus proficiency.
- **Copy config JSON**: settings plus derived geometry (wall rect, route region, digit centre, level spacing, climber and hold sizes, limb order and start levels, body proportions, timing, palette, grade table).

## 17. Testing and validation

### 17.1 Invariants

These were checked in the simulator by exhaustive sweeps and must hold on the watch:

| Invariant | Simulator check |
|---|---|
| Head above waist: head y < hip y in every pose | 6.9 M poses (all screens, both wall types and areas, both descent modes, 3 climber sizes, 4 move counts, 5 grades), then 4.5 M poses with every proficiency, beer and quarter combination at climber sizes 0.8, 1.4 and 2.0: 0 failures |
| Hands above feet: max(hand y) < min(foot y) | same sweeps: 0 failures |
| Seamless minute boundaries: limb ends and head move less than 1.5 px between second 60 of one minute and second 0 of the next | 24,960 boundaries including beer, quarter and rope minutes and all proficiencies: 0 jumps |
| One rope descent per quarter (quarters on, non-beginner routes) and never two in a row from the quarter rule | hourly plans with and without beer |
| Beginners never downclimb | hourly plans in every mode |
| Expert always tops out, beginner never | 300 routes each |
| Jumps: expert always makes them; intermediate never falls onto the rope off a jump and tops out after missed jumps; beginner never gets past his first jump | 1,600 grade 7 and 8 routes with jumps: 0 violations |

### 17.2 Golden values

Export from the simulator, for fixed settings and minutes: hash and mulberry32 outputs, the hour plan string (for example `BBRUDUDUDUDUDUDRUDUDUD…` for beer and quarters on), route hold positions, attempt plans, and poses at chosen seconds. The watch core must reproduce them within rounding.

### 17.3 Device checks

- Digits never shift; zeros have no dot or slash.
- A full minute at 1×: the climber reads as climbing, jumps and falls are visible across ticks.
- Lower-off and fall seconds within the partial update budget (MIP).
- Always-on lit pixels within the limit (AMOLED).
- Route colours distinct on MIP after quantization; dim holds visible in sunlight.
- Battery drain per hour compared with a plain digital face.

## 18. Risks and open questions

| Item | Status | Notes |
|---|---|---|
| Name | Open | "Second Ascent" is a working title. Check the store and trademarks. |
| Lite and premium | Open | Not decided. If split, follow the private source repository and public lite cut pattern used for other faces. |
| Beginner rope next to a quarter rope | To tune | With proficiency cycling, a beginner's rope minute can land next to a quarter rope minute (for example :15 then :16). Option: give the quarter minute to the beginner when their turns coincide. |
| Very slow downclimb | Watch | After an early fall with little climbed, the downclimb may look frozen at 1 Hz. Option: a minimum descent speed, then wait at the bottom. |
| Pacing at 1× | Validate | Tuned partly at 15×. Judge on the wrist in M2. |
| Grade 8 hang time | Validate | Up to 4 jumps of about 5 s each: roughly a third of the minute in the air. Tune jump duration if it is too much. |
| Always-on limit | M0 | Confirm the current Connect IQ rule and the 10 % figure. |
| Partial update cost | M0 | Lower-off and fall seconds redraw a tall region. |
| Memory for a static-layer bitmap | M0 | Decides between blitting and redrawing holds in the clip. |
| Fonts | M1 | Bitmap font sizes per device; whether to ship the alternative fonts. |

## 19. Milestones

| Milestone | Scope | Done when |
|---|---|---|
| M0. Probes | Partial update cost for climber and lower-off regions; `BufferedBitmap` memory; always-on rule; font rendering | Numbers recorded for one AMOLED and one MIP device |
| M1. Static face | Digits with fixed cells, wall, holds for one route, tags, ticks; settings plumbing | Matches simulator screenshots for a fixed minute |
| M2. Motion | Pure core (plan, routes, grades, poses), per-second update, lower-off, downclimb, jumps | Golden values pass; invariants hold in unit tests; a minute looks right on the wrist |
| M3. Story | Falls and proficiency, beer break, quarters, fixed wall, proficiency cycling | All §17.1 checks pass on device |
| M4. Low power | Always-on rendering, MIP partial updates, burn-in shift | Within budgets on the device list |
| M5. Release | Name, store assets, device list, settings UI review | Published |

## 20. Appendix A. Constants

Distances are fractions of W or H, multiples of the climber size c, or pixels where marked.

### A.1 Layout

| Name | Value |
|---|---|
| Panel corner radius | 0.03 W |
| Route region inset (panel) | 12 % of wall width horizontally, 0.03 H vertically |
| Digit gap to bezel and wall | 0.03 W |

### A.2 Time

| Name | Value |
|---|---|
| Stacked font size, centres | 0.30 H × size; 0.365 H and 0.635 H |
| Linear font size, centre | 0.19 H × size; 0.5 H |
| Digit cell | 1.04 × width("0") |

### A.3 Routes

| Name | Value |
|---|---|
| Start levels | LH 0, LF −4, RH 1, RF −3 |
| Move order | LH, LF, RH, RF |
| Levels per move | 2 |
| Hold base size hs₀ | clamp(0.62·dy₀, 3.5 px, 15 px) |
| Climber size c | min(5·dy₀, 0.85·wall width) × climberScale |
| Monotonic gap | 0.6·min(dy, dy₀) |
| Jump target lift | 0.6·dy, size 1.05 hs₀ |
| Shared start blend | levels ≤ 1 fixed, weight (4 − k)/3 up to level 4 |

### A.4 Motion

| Name | Value |
|---|---|
| Limb swing | sin(π·f)·0.07 c outward |
| Easing | in-out quadratic |
| Feet below lower hand | 0.12 c |
| Torso tilt limit | vertical component ≤ −0.75 |
| Fall | drop 1 s (0.35 s to settle, 0.45 c lower, swing 0.05 c at 9 rad/s), lower 2.5 s |
| Minimum time left to allow a fall | 3 s |
| Beginner final cap | 0.8 × route |
| Beer | sit 2 s, stand 3 s, sip every 8 s for 40 % of the cycle |

### A.5 Colours

| Element | Colour |
|---|---|
| Gym palette | #F7C948, #34C46A, #3A86FF, #EF4444, #A06CF0, #FF8C2B, #FF6FB0, #22C3C3, #E8E8E8 |
| Walls | slate #24292D, plywood #5C4A37, none #000000 |
| Climber | #F5F5F5, #C4CAC6, #FFBC54 |
| Digits | white #F6F6F6, grey #969C99 |
| Rope, anchor ring | #D6D4C8, #969C98 |
| Scale ticks | route colour |
| Bottle, label | #CD802A, #EEE0BA |
| Dim other routes | colour mixed 62 % toward the wall |
| Unused fixed-wall holds | wall mixed 26 % toward white |

### A.6 Tags

| Name | Value |
|---|---|
| Font size fs | 0.055 H, bold |
| Box | width 0.95 fs, height ascent + 0.5 fs, gap 0.22 fs |
| Corner radius | max(1.5 px, 0.18 fs) |
| Outline width | max(1.2 px, 0.11 fs) |

### A.7 Always-on

| Name | Value |
|---|---|
| Digits | 55 % |
| Holds as dots | radius max(1.2 px, 0.18·size), 60 % |
| Climber | 50 % |
| Burn-in shift | ±2 px, 3 × 3 cycle by minute |

## 21. Appendix B. Algorithms

### B.1 Hash and generator

```
hash(n):                        32-bit; n truncated to its low 32 bits first
  x = n
  x = imul(x xor (x >>> 16), 0x45d9f3b)
  x = imul(x xor (x >>> 16), 0x45d9f3b)
  return (x xor (x >>> 16)) as unsigned

mulberry32(a): returns next() in [0, 1)
  a = a + 0x6D2B79F5
  t = imul(a xor (a >>> 15), 1 or a)
  t = (t + imul(t xor (t >>> 7), 61 or t)) xor t
  return ((t xor (t >>> 14)) as unsigned) / 2^32
```

Seeds: route holds hash(key·31 + 7); jumps hash(key·17 + 3); attempts hash(key·13 + {expert 1, intermediate 3, beginner 5}); shared start positions hash(k·7 + 17); fixed wall hash(wallSeed·977 + 5); other routes per day hash(day·97 + 3), their colours hash(day·5 + r); colour shuffle hash(hour·7919 + 13) and hash(hour·61 + k); fixed-wall path noise hash(sid·31 + holdId) with sid = key·1009 + k (shared start band 1013 + k).

### B.2 Shuffled colour

```
colour(index):                  index = hour·60 + ordinal
  hour = floor(index/60); k = index − hour·60; L = 9
  i = hash(hour·7919 + 13) mod L
  repeat k times (j = 1 … k): i = (i + 1 + hash(hour·61 + j) mod (L − 1)) mod L
  return palette[i]             never equal to the previous index's colour
```

### B.3 Move counts and levels

```
n(M, o)  = floor((M − o + 3)/4)
Lmax(M)  = max(2·n(M, 0), 1 + 2·n(M, 2))
M(grade) = largest M ≥ 4 with Lmax(M) ≤ 1 + (L₀ − 1)/sp     (M = moves setting at sp = 1)
```

### B.4 Time to move progress

```
cum[0] = 0; cum[i+1] = cum[i] + (jump(i) ? jumpDuration : 1)
u = clamp(t/T, 0, 1) · cum[M]
i = largest index with cum[i] ≤ u (i < M)
m = i + (u − cum[i]) / (cum[i+1] − cum[i])
```

### B.5 Two-bone IK

```
ik(joint, target, a, b, side):
  d = |target − joint|;  u = (target − joint)/d
  if d ≥ a + b: return joint + u·d·a/(a + b)          stretched: straight
  x = (a² − b² + d²)/(2d);  h = √max(0, a² − x²)
  base = joint + u·x;  n = (−u.y, u.x)
  return whichever of base ± n·h lies further to the limb's side (left limbs: smaller x)
```

### B.6 Attempt plan

```
attemptPlan(route, T, proficiency):
  maxFalls = 0 (E), 1 with p = 0.5 (I), ∞ (B)
  jumps = sorted jump moves; firstJump = jumps[0] or none
  missed = (I and maxFalls == 0) ? each jump with p = 0.5 : none
  spu = T / (cum[M] + Σ weight(missed jumps))      seconds per weight unit
  t = 0; segments = []
  loop:
    mf = none
    if falls < maxFalls:
      mf = M · (B: uniform(0.15, 0.40), I: uniform(0.40, 0.60))
      if B and firstJump < mf: mf = firstJump + 0.5         off at the top of the leap
      if I and mf inside a jump move j: mf = j              never off a jump
      if t + units(mf)·spu + 1 + 2.5 + 3 > T: mf = none
    if mf is none:
      segments += climb(t, T, cap = B ? min(0.8·M, firstJump) : M); break
    segments += climb(t, t + units(mf)·spu); t += units(mf)·spu
    segments += fall(t, t + 3.5, mf);        t += 3.5; falls += 1
  last.cap = floor(min(last.cap, m reached at T))      endM

mapUnits(u, missed):                      time units → progress, missed attempts inserted
  for j in 0 … M−1:
    w = weight(j)
    if j in missed: if u < w: return (m = j, missPhase = u/w); u −= w
    if u < w: return (m = j + u/w); u −= w
  return (m = M)
```

### B.7 Pose at a second

```
poseAt(minute, s):
  slot = plan(hour)[minute]
  beer: sittingPose(τ = beerIndex·60 + s, D = 60 or 120)
  up:   climbPose(s, T = 59)
  down: pose(endM(up) · (1 − s/59), no jumps)
  line: s > 59 − L ? lowerOff((s − (59 − L))/(L + 1), from endM, to next route start)
                   : climbPose(s, T = 59 − L)
climbPose(s, T): find the attempt segment containing s; fall → fallPose;
                 climb → mapUnits(...): missPhase → missed-jump pose at m, else pose(m)
```
