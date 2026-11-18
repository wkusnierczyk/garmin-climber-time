using Toybox.System;
using Toybox.Time;

import Toybox.Lang;

// What the face reads from the watch to decide what to draw: the clock, and whether the
// display is in always-on. Every such read goes through here, so that the capture build
// can stand a fixed moment in for them (#7).
//
// The face takes everything from the clock, so a store image of a given grade or of a
// fall needs a given minute and second, and the simulator in a container runs on the
// real clock. It will not enter always-on headlessly either: Display Mode is a GUI menu
// that it does not persist (playbook, reference/graphics.md). graphics.jungle puts
// capture/ on the source path, whose Now.mc defines these same functions from a frozen
// moment, and excludes (:live) so that only those are compiled. Every other build uses
// these, and capture/ is on no other build's path: a jungle that compiled both would fail
// with a redefinition rather than ship the frozen clock.
module Now {

    (:live)
    function clockTime() as System.ClockTime {
        return System.getClockTime();
    }

    // Seconds since the epoch, UTC.
    (:live)
    function utcSeconds() as Number {
        return Time.now().value();
    }

    // The always-on scene is drawn unless both signals say awake: the sleep callbacks' flag,
    // which lags on the epix Pro, and System.getDisplayMode() (API 5.0.0, the minApiLevel),
    // as in Matrix Time (wkusnierczyk/garmin-matrix-time#191, #212).
    (:live)
    function lowPower(asleep as Boolean) as Boolean {
        return asleep || ((System has :getDisplayMode) && System.getDisplayMode() != System.DISPLAY_MODE_HIGH_POWER);
    }

    // The watch's 12/24-hour setting.
    (:live)
    function is24Hour() as Boolean {
        return System.getDeviceSettings().is24Hour;
    }

    // The second the climber's pose is drawn for: the clock's. The capture build can ask for
    // the second of a fall instead, which depends on the route.
    (:live)
    function poseSecond(r as Route, s as Number) as Number {
        return s;
    }

}
