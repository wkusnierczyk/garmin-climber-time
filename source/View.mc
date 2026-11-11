using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

import Toybox.Lang;

class View extends WatchUi.WatchFace {

    // Prototype: no always-on scene. The same full face is drawn in every display mode,
    // once a second while the watch is awake and once a minute in always-on.

    private var _geom as Geom?;
    private var _route as Route?;
    private var _next as Route?;
    private var _others as Array<OtherHold>?;
    private var _othersDay as Number = -1;
    private var _static as Graphics.BufferedBitmapReference?;
    private var _staticMin as Number = -1;
    private var _digitFont as Graphics.FontType = Graphics.FONT_NUMBER_THAI_HOT;
    private var _tagFont as Graphics.FontType = Graphics.FONT_XTINY;
    private var _tagSize as Float = 0.0;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var shape = System.getDeviceSettings().screenShape;
        var g = new Geom(w, h, shape == System.SCREEN_SHAPE_ROUND, Draw.LAYOUT);
        _geom = g;
        var ds = Draw.digitSize(dc, g);
        _digitFont = Draw.vectorFont(ds, Graphics.FONT_NUMBER_THAI_HOT);
        if (g.tagMode == Climb.TAGS_ROWS) {
            _tagSize = ds * Draw.TAG_ROW_SCALE;
            _tagFont = Draw.vectorFont(_tagSize.toNumber(), Graphics.FONT_NUMBER_MILD);
        } else {
            _tagSize = g.H * Draw.TAG_FS;
            _tagFont = Draw.vectorFont(_tagSize.toNumber(), Graphics.FONT_XTINY);
        }
        if (Graphics has :createBufferedBitmap) {
            _static = Graphics.createBufferedBitmap({ :width => w, :height => h });
        }
    }

    // Local minutes since the epoch (DESIGN.md §15.3), with the offset taken from the
    // clock itself so that it follows DST.
    private function absMinute(ct as System.ClockTime) as Number {
        var utcMin = Time.now().value() / 60;
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
        if (g == null) {
            return;
        }
        var ct = System.getClockTime();
        var absMin = absMinute(ct);
        var r = routesFor(absMin, g);
        var rc = Climb.GYM[r.colorIdx];
        var hh = ct.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hh = hh % 12;
            if (hh == 0) {
                hh = 12;
            }
        }

        var day = Climb.floorDiv(absMin, 1440);
        var others = _others;
        if (others == null || _othersDay != day) {
            others = Climb.otherHolds(day, g);
            _others = others;
            _othersDay = day;
        }

        var sb = _static;
        var bmp = sb != null ? sb.get() : null;
        if (bmp != null) {
            if (_staticMin != absMin) {
                var bdc = (bmp as Graphics.BufferedBitmap).getDc();
                bdc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                bdc.clear();
                Draw.staticLayer(bdc, g, r, rc, others, hh, ct.min, _digitFont, _tagFont, _tagSize);
                _staticMin = absMin;
            }
            dc.drawBitmap(0, 0, bmp as Graphics.BufferedBitmap);
        } else {
            Draw.staticLayer(dc, g, r, rc, others, hh, ct.min, _digitFont, _tagFont, _tagSize);
        }

        var rn = nextRoute(absMin, g);
        var P = Climb.poseAt(r, rn, ct.sec);
        Draw.dynamicLayer(dc, g, P);
    }

}
