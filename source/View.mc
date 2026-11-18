using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

import Toybox.Lang;

class View extends WatchUi.WatchFace {

    // Always-on draws its own scene (Draw.lowPower, DESIGN.md §13.1), and a display that is
    // off draws nothing. Now.lowPower decides between them, from this flag and the display
    // mode. The scene takes everything from the clock, so it changes once a minute however
    // often onUpdate is called. The clock is read through Now as well, for the captures (#7).
    private var _lowPower as Boolean = false;
    private var _checker as Graphics.BitmapType?;

    private var _geom as Geom?;
    private var _route as Route?;
    private var _next as Route?;
    private var _others as Array<OtherHold>?;
    private var _othersDay as Number = -1;
    // The static layer's bitmap, held locked: the graphics pool does not restore a purged
    // BufferedBitmap, and an unlocked one was purged between minutes, leaving only the climber
    // on the screen (#60). Null where it cannot be had: the layer is drawn on the screen.
    private var _static as Graphics.BufferedBitmap?;
    private var _staticMin as Number = -1;
    private var _digitFont as Graphics.FontType?;
    private var _tagFont as Graphics.FontType?;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var shape = System.getDeviceSettings().screenShape;
        var g = new Geom(w, h, shape == System.SCREEN_SHAPE_ROUND, Draw.LAYOUT, Draw.TIME_LINEAR);
        _geom = g;
        // The bitmap fonts for this screen's resolution (resources-<family>/fonts), and their sizes.
        var df = WatchUi.loadResource(Rez.Fonts.Time) as Graphics.FontType;
        var tf = WatchUi.loadResource(Rez.Fonts.Tag) as Graphics.FontType;
        _digitFont = df;
        _tagFont = tf;
        g.digitSize = Draw.em(dc, df);
        g.tagSize = Draw.em(dc, tf);
        // A new bitmap is empty: _staticMin = -1 draws it before its first use. Without that, a
        // layout again within the same minute showed the empty bitmap until the minute changed,
        // the same symptom as a purge (#60).
        freeStatic();
        if (Graphics has :createBufferedBitmap) {
            try {
                _static = Graphics.createBufferedBitmap({ :width => w, :height => h }).get() as Graphics.BufferedBitmap?;
            } catch (e instanceof Graphics.OutOfGraphicsMemoryException) {
                freeStatic();
            }
        }
    }

    // Without the bitmap the static layer is drawn straight onto the screen.
    private function freeStatic() as Void {
        _static = null;
        _staticMin = -1;
    }

    // Local minutes since the epoch (DESIGN.md §15.3), with the offset taken from the
    // clock itself so that it follows DST.
    private function absMinute(ct as System.ClockTime) as Number {
        var utcMin = Now.utcSeconds() / 60;
        var local = ct.hour * 60 + ct.min;
        var off = Climb.posMod(local - utcMin % 1440, 1440);
        if (off > 720) {
            off -= 1440;
        }
        return utcMin + off;
    }

    private function routesFor(absMin as Number, g as Geom) as Route {
        var r = _route;
        if (r == null || r.key != absMin) {
            var n = _next;
            r = (n != null && n.key == absMin) ? n : new Route(absMin, g);
            _route = r;
            _next = null;
        }
        return r;
    }

    private function nextRoute(absMin as Number, g as Geom) as Route {
        var n = _next;
        if (n == null || n.key != absMin + 1) {
            n = new Route(absMin + 1, g);
            _next = n;
        }
        return n;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var g = _geom;
        var df = _digitFont;
        var tf = _tagFont;
        if (g == null || df == null || tf == null) {
            return;
        }
        if ((System has :getDisplayMode) && System.getDisplayMode() == System.DISPLAY_MODE_OFF) {
            return;
        }
        var ct = Now.clockTime();
        var absMin = absMinute(ct);
        var r = routesFor(absMin, g);
        var rc = Climb.GYM[r.colorIdx];
        var hh = ct.hour;
        if (!Now.is24Hour()) {
            hh = hh % 12;
            if (hh == 0) {
                hh = 12;
            }
        }

        if (Now.lowPower(_lowPower)) {
            var ck = _checker;
            if (ck == null) {
                // The locked static bitmap holds pool space for good (#60); if the checker does
                // not fit beside it, always-on goes without the bitmap, and so does the face.
                try {
                    ck = WatchUi.loadResource(Rez.Drawables.Checker) as Graphics.BitmapType;
                } catch (e instanceof Graphics.OutOfGraphicsMemoryException) {
                    freeStatic();
                    ck = WatchUi.loadResource(Rez.Drawables.Checker) as Graphics.BitmapType;
                }
                _checker = ck;
            }
            Draw.lowPower(dc, g, r, rc, hh, ct.min, absMin, df, ck);
            return;
        }

        var day = Climb.floorDiv(absMin, 1440);
        var others = _others;
        if (others == null || _othersDay != day) {
            others = Climb.otherHolds(day, g);
            _others = others;
            _othersDay = day;
        }

        var bmp = _static;
        if (bmp != null) {
            if (_staticMin != absMin) {
                var bdc = bmp.getDc();
                bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                bdc.clear();
                Draw.staticLayer(bdc, g, r, rc, others, hh, ct.min, df, tf, g.tagSize);
                _staticMin = absMin;
            }
            dc.drawBitmap(0, 0, bmp);
        } else {
            Draw.staticLayer(dc, g, r, rc, others, hh, ct.min, df, tf, g.tagSize);
        }

        var rn = nextRoute(absMin, g);
        var P = Climb.poseAt(r, rn, Now.poseSecond(r, ct.sec));
        Draw.dynamicLayer(dc, g, P);
    }

    function onEnterSleep() as Void {
        _lowPower = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        _lowPower = false;
        WatchUi.requestUpdate();
    }

}
