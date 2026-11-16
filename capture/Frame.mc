import Toybox.Lang;

// The moment one capture build shows (#7). tools/make-graphics.py writes a copy of this file
// for each frame it captures, over a copy of the tree, and never into the repository; this
// one is for building the capture by hand:
//
//   monkeyc -f "monkey.jungle;graphics.jungle" ...
module Frame {

    // Wall-clock seconds since 1970-01-01 00:00, as if UTC: 2026-11-16 10:07:24, grade 6,
    // intermediate (DESIGN.md §8.3), mid-climb.
    const MOMENT = 1794823644;

    // Draw the always-on scene.
    const ALWAYS_ON = false;

    // Draw the climber hanging after his first fall of the minute, whatever MOMENT's second.
    const FALL = false;

}
