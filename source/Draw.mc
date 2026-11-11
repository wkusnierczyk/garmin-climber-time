using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

module Draw {

    const WALL = 0x24292D;          // slate
    const LAYOUT = Climb.LAYOUT_CENTRE;   // which wall area the build draws; see Geom
    const CLIMBER = 0xF5F5F5;       // white
    const HOURS = 0xF6F6F6;
    const ROPE = 0xD6D4C8;
    const ANCHOR = 0x969C98;
    const VECTOR_FACES = ["RobotoCondensedBold", "BionicBold", "Swiss721Bold"] as Array<String>;

    // Channel-wise a + (b - a)·t.
    function mix(a as Number, b as Number, t as Float) as Number {
        var out = 0;
        for (var sh = 16; sh >= 0; sh -= 8) {
            var ca = (a >> sh) & 0xFF;
            var cb = (b >> sh) & 0xFF;
            var v = (ca + (cb - ca) * t + 0.5).toNumber();
            out |= (v & 0xFF) << sh;
        }
        return out;
    }

    function vectorFont(size as Number, fallback as Graphics.FontType) as Graphics.FontType {
        if (Graphics has :getVectorFont) {
            var f = Graphics.getVectorFont({ :face => VECTOR_FACES, :size => size });
            if (f != null) {
                return f;
            }
        }
        return fallback;
    }

    // Stacked digits, 0.30 H, shrunk to fit between the bezel and the wall (DESIGN.md §4.1).
    function digitFont(dc as Graphics.Dc, g as Geom) as Graphics.FontType {
        var fs = (g.H * 0.30).toNumber();
        var f = vectorFont(fs, Graphics.FONT_NUMBER_THAI_HOT);
        var maxW = g.digitMaxW;
        var tot = 2 * 1.04 * dc.getTextWidthInPixels("0", f);
        if (tot > maxW && f != Graphics.FONT_NUMBER_THAI_HOT) {
            f = vectorFont((fs * maxW / tot).toNumber(), Graphics.FONT_NUMBER_THAI_HOT);
        }
        return f;
    }

    // Each digit centred in its own cell 1.04 × width("0") (DESIGN.md §4.2).
    function digits(dc as Graphics.Dc, str as String, cx as Float, cy as Float, font as Graphics.FontType, color as Number) as Void {
        var cw = 1.04 * dc.getTextWidthInPixels("0", font);
        var x = cx - cw * str.length() / 2 + cw / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < str.length(); i++) {
            dc.drawText(x, cy, font, str.substring(i, i + 1) as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            x += cw;
        }
    }

    function time(dc as Graphics.Dc, g as Geom, dx as Float, dy as Float, hh as Number, mm as Number, font as Graphics.FontType, hc as Number, mc as Number) as Void {
        digits(dc, hh.format("%02d"), g.dcx + dx, g.H * 0.365 + dy, font, hc);
        digits(dc, mm.format("%02d"), g.dcx + dx, g.H * 0.635 + dy, font, mc);
    }

    function aa(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    // A w × h rectangle centred on (x, y), rotated by a, as a polygon.
    function rotRect(dc as Graphics.Dc, x as Float, y as Float, w as Float, h as Float, a as Float) as Void {
        var c = Math.cos(a).toFloat();
        var s = Math.sin(a).toFloat();
        var hw = w / 2;
        var hh = h / 2;
        dc.fillPolygon([
            [x + (-hw * c - -hh * s), y + (-hw * s + -hh * c)],
            [x + (hw * c - -hh * s), y + (hw * s + -hh * c)],
            [x + (hw * c - hh * s), y + (hw * s + hh * c)],
            [x + (-hw * c - hh * s), y + (-hw * s + hh * c)]
        ] as Array<[Numeric, Numeric]>);
    }

    function ellipse(dc as Graphics.Dc, x as Float, y as Float, a as Float, b as Float) as Void {
        if (a < 1.0 && b < 1.0) {
            dc.fillCircle(x, y, 1);
        } else {
            dc.fillEllipse(x, y, Climb.maxf(a, 1.0), Climb.maxf(b, 1.0));
        }
    }

    // DESIGN.md §5.2.
    function hold(dc as Graphics.Dc, h as Hold, s as Float, col as Number) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var x = h.x;
        var y = h.y;
        switch (h.type) {
            case Climb.JUG:
                ellipse(dc, x, y, s * 0.62, s * 0.42);
                dc.setColor(mix(col, 0, 0.38), Graphics.COLOR_TRANSPARENT);
                ellipse(dc, x, y + s * 0.12, s * 0.38, s * 0.17);
                break;
            case Climb.CRIMP:
                rotRect(dc, x, y, s * 1.1, s * 0.4, h.rot * 0.5);
                break;
            case Climb.SLOPER:
                ellipse(dc, x, y, s * 0.7, s * 0.5);
                dc.setColor(mix(col, 0xFFFFFF, 0.35), Graphics.COLOR_TRANSPARENT);
                ellipse(dc, x - s * 0.18, y - s * 0.16, s * 0.22, s * 0.14);
                break;
            case Climb.PINCH:
                rotRect(dc, x, y, s * 0.44, s * 1.1, h.rot);
                break;
            case Climb.EDGE:
                rotRect(dc, x, y, s * 1.6, Climb.maxf(1.5, s * 0.16), h.rot * 0.3);
                break;
            case Climb.MICRO:
                dc.fillCircle(x, y, Climb.maxf(1.2, s * 0.26));
                break;
            default:
                ellipse(dc, x, y, s * 0.45, s * 0.32);
                break;
        }
        if ((h.type == Climb.JUG || h.type == Climb.SLOPER) && s > 8) {
            dc.setColor(mix(col, 0, 0.6), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, h.type == Climb.JUG ? y - s * 0.16 : y, Climb.maxf(1.0, s * 0.07));
        }
    }

    function staticLayer(dc as Graphics.Dc, g as Geom, r as Route, rc as Number, others as Array<OtherHold>,
                         hh as Number, mm as Number, digitFont as Graphics.FontType, tagFont as Graphics.FontType) as Void {
        aa(dc);
        var W = g.W;
        var ww = g.x1 - g.x0;
        var wh = g.y1 - g.y0;

        // Wall and T-nuts (DESIGN.md §5.1).
        dc.setColor(WALL, Graphics.COLOR_TRANSPARENT);
        if (g.full) {
            dc.fillRectangle(g.x0, g.y0, ww, wh);
        } else {
            dc.fillRoundedRectangle(g.x0, g.y0, ww, wh, W * 0.03);
        }
        var gs = Climb.maxf(7.0, r.dy0 * 1.15);
        var tr = Climb.maxf(0.8, gs * 0.07);
        dc.setColor(mix(WALL, 0xFFFFFF, 0.14), Graphics.COLOR_TRANSPARENT);
        var row = 0;
        for (var y = g.y0 + gs * 0.5; y < g.y1; y += gs) {
            for (var x = g.x0 + gs * (row % 2 == 1 ? 0.9 : 0.4); x < g.x1; x += gs) {
                dc.fillCircle(x, y, tr);
            }
            row++;
        }

        // Other routes, dim (DESIGN.md §5.3).
        for (var i = 0; i < others.size(); i++) {
            var o = others[i];
            if (o.ci == r.colorIdx) {
                continue;
            }
            var clash = false;
            for (var k = -4; k <= r.lmax; k++) {
                var h = r.hold(k);
                var dx = h.x - o.hold.x;
                var dy = h.y - o.hold.y;
                if (dx * dx + dy * dy < r.hs * 1.3 * r.hs * 1.3) {
                    clash = true;
                    break;
                }
            }
            if (!clash) {
                hold(dc, o.hold, r.hs * o.hold.s, mix(Climb.GYM[o.ci], WALL, 0.62));
            }
        }

        // Volumes.
        dc.setColor(mix(rc, WALL, 0.45), Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < r.vols.size(); i++) {
            var v = r.vols[i];
            var pts = [] as Array<[Numeric, Numeric]>;
            for (var j = 0; j < 3; j++) {
                var a = v.rot + j * 2.094;
                pts.add([v.x + Math.cos(a) * v.r, v.y + Math.sin(a) * v.r]);
            }
            dc.fillPolygon(pts);
        }

        // The route.
        for (var k = -4; k <= r.lmax; k++) {
            var h = r.hold(k);
            hold(dc, h, h.s, rc);
        }

        // Start and finish tape (DESIGN.md §5.6).
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        var tw = Climb.maxf(4.0, r.hs * 0.9);
        var th = Climb.maxf(1.5, r.hs * 0.16);
        var top = r.hold(r.lmax);
        dc.fillRectangle(top.x - tw / 2, top.y - r.hs * 0.75 - th, tw, th);
        for (var k = 0; k <= 1; k++) {
            var h = r.hold(k);
            dc.fillRectangle(h.x - tw * 0.35, h.y + h.s * 0.6, tw * 0.7, th);
        }

        // Seconds scale, every 10 s (DESIGN.md §3.4).
        var xl = g.x0 + Climb.maxf(2.0, W * 0.008);
        for (var s = 10; s < 60; s += 10) {
            var y = Climb.lerp(g.ry1, g.ry0, s / 60.0);
            var len = s % 15 == 0 ? Climb.maxf(5.0, W * 0.016) : Climb.maxf(3.0, W * 0.008);
            dc.fillRectangle(xl, y.toNumber(), len, Climb.maxf(1.5, W * 0.005));
        }

        // Anchor ring (DESIGN.md §5.7).
        dc.setColor(ANCHOR, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Climb.maxf(1.0, r.c * 0.03).toNumber());
        dc.drawCircle((g.rx0 + g.rx1) / 2, g.ay, Climb.maxf(1.5, r.hs * 0.22));
        dc.setPenWidth(1);

        tags(dc, g, r, rc, tagFont);
        time(dc, g, 0.0, 0.0, hh, mm, digitFont, HOURS, rc);
    }

    // Tag font size, as a fraction of H. The design's 0.055 side by side was hard to
    // read on the wrist; the prototype stacks them larger.
    const TAG_FS = 0.085;

    // [grade] and [B/I/E], stacked or side by side, centred at mid-height on g.tagX
    // (DESIGN.md §3.3, enlarged for the prototype).
    function tags(dc as Graphics.Dc, g as Geom, r as Route, rc as Number, font as Graphics.FontType) as Void {
        var fs = g.H * TAG_FS;
        var asc = fs * 0.72;
        var bw = fs * 1.05;
        var th = asc + fs * 0.5;
        var gap = fs * 0.18;
        var lw = Climb.maxf(1.5, fs * 0.09);
        var rad = Climb.maxf(1.5, fs * 0.18);
        var x;
        var y;
        var dx = 0.0;
        var dy = 0.0;
        if (g.tagsInLine) {
            x = g.tagX - bw - gap / 2;
            y = g.H / 2 - th / 2;
            dx = bw + gap;
        } else {
            x = g.tagX - bw / 2;
            y = g.H / 2 - (th + gap / 2);
            dy = th + gap;
        }
        var letters = ["B", "I", "E"] as Array<String>;

        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, th, rad);
        dc.setColor(mix(rc, 0, 0.82), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + bw / 2, y + th / 2, font, r.grade.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dx;
        y += dy;

        dc.setColor(WALL, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, bw, th, rad);
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(lw.toNumber());
        dc.drawRoundedRectangle(x + lw / 2, y + lw / 2, bw - lw, th - lw, Climb.maxf(1.0, rad - lw / 2));
        dc.setPenWidth(1);
        dc.drawText(x + bw / 2, y + th / 2, font, letters[r.prof], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function seg(dc as Graphics.Dc, P as Pose, a as Number, b as Number, dx as Float, dy as Float, w as Float) as Void {
        var ax = P.x(a) + dx;
        var ay = P.y(a) + dy;
        var bx = P.x(b) + dx;
        var by = P.y(b) + dy;
        dc.drawLine(ax, ay, bx, by);
        // Round caps and joints.
        var rr = w / 2;
        if (rr >= 1.0) {
            dc.fillCircle(ax, ay, rr);
            dc.fillCircle(bx, by, rr);
        }
    }

    // DESIGN.md §9.1: lines with round caps and a filled head.
    function climber(dc as Graphics.Dc, P as Pose, col as Number, dx as Float, dy as Float) as Void {
        var c = P.c;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var aw = Climb.maxf(1.5, 0.06 * c);
        dc.setPenWidth(aw.toNumber());
        seg(dc, P, Climb.P_SL, Climb.P_EL, dx, dy, aw);
        seg(dc, P, Climb.P_EL, Climb.P_LH, dx, dy, aw);
        seg(dc, P, Climb.P_SR, Climb.P_ER, dx, dy, aw);
        seg(dc, P, Climb.P_ER, Climb.P_RH, dx, dy, aw);
        var lw = Climb.maxf(1.8, 0.07 * c);
        dc.setPenWidth(lw.toNumber());
        seg(dc, P, Climb.P_PL, Climb.P_KL, dx, dy, lw);
        seg(dc, P, Climb.P_KL, Climb.P_LF, dx, dy, lw);
        seg(dc, P, Climb.P_PR, Climb.P_KR, dx, dy, lw);
        seg(dc, P, Climb.P_KR, Climb.P_RF, dx, dy, lw);
        var tw = Climb.maxf(2.5, 0.13 * c);
        dc.setPenWidth(tw.toNumber());
        seg(dc, P, Climb.P_HM, Climb.P_SM, dx, dy, tw);
        dc.setPenWidth(1);
        dc.fillCircle(P.x(Climb.P_HEAD) + dx, P.y(Climb.P_HEAD) + dy, Climb.maxf(2.0, 0.085 * c));
    }

    function dynamicLayer(dc as Graphics.Dc, g as Geom, P as Pose) as Void {
        aa(dc);
        if (P.lowering) {
            dc.setColor(ROPE, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(Climb.maxf(1.0, P.c * 0.025).toNumber());
            dc.drawLine((g.rx0 + g.rx1) / 2, g.ay, P.x(Climb.P_HM), P.y(Climb.P_HM));
            dc.setPenWidth(1);
        }
        climber(dc, P, CLIMBER, 0.0, 0.0);
    }

}
