using Toybox.Math;
using Toybox.System;

import Toybox.Lang;

// The capture build's clock and display mode (#7): source/Now.mc's functions, answered from
// the moment in Frame.mc rather than from the watch. Compiled only through graphics.jungle,
// which also excludes source/Now.mc's (:live) definitions, and never shipped.
//
// Only the triggers are fixed. What is drawn comes from the face's own code, in the real
// simulator, reading these exactly as it reads the watch: a frozen frame is the one the
// watch shows at that moment, as the face draws once a second, at a whole second.
module Now {

    // The moment's hour, minute and second, on the simulator's own ClockTime.
    function clockTime() as System.ClockTime {
        var ct = System.getClockTime();
        var t = Frame.MOMENT;
        ct.hour = (t / 3600) % 24;
        ct.min = (t / 60) % 60;
        ct.sec = t % 60;
        return ct;
    }

    // MOMENT is wall-clock time, given as if UTC. The face takes the zone's offset from the
    // difference between the two, so it reads an offset of 0 and the local minute MOMENT
    // names, which is all it uses (View.absMinute).
    function utcSeconds() as Number {
        return Frame.MOMENT;
    }

    function lowPower(asleep as Boolean) as Boolean {
        return Frame.ALWAYS_ON;
    }

    // With Frame.FALL, the second the climber hangs on the rope after his first fall of the
    // minute; a frame of a fall is chosen by what happens, not by a second that would go stale
    // with the next change to the routes. The pose is drawn for whole seconds, as on the watch:
    // the first one at least half a second into the fall (Climb.FALL_T, DESIGN.md §12.3). A
    // minute with no fall stops the app, so that the capture shows the error, not a climb.
    function poseSecond(r as Route, s as Number) as Number {
        if (!Frame.FALL) {
            return s;
        }
        var segs = r.plan(59 - Climb.LOWER).segs;
        for (var i = 0; i < segs.size(); i++) {
            if (segs[i].fall) {
                return Math.ceil(segs[i].t0 + 0.5).toNumber();
            }
        }
        throw new Lang.InvalidValueException("Frame.FALL: the climber does not fall in this minute");
    }

}
