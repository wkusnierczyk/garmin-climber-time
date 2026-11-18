using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

import Toybox.Lang;

module Draw {

    const SLATE = 0x24292D;         // the wall, on AMOLED; see wall()
    const LAYOUT = Climb.LAYOUT_HALF;     // which wall area the build draws (DESIGN.md §14.3); the others stay for Premium
    const TIME_LINEAR = true;             // HHMM in one line (time group beside the panel or right half, centre panel); see Geom
    const TIME_CENTRED = true;            // time group: the digits row on H/2, tags below; see groupRows
    const CLIMBER = 0xF5F5F5;       // white
    const HOURS = 0xF6F6F6;         // white; the minutes and both tags take the route colour (DESIGN.md §14.3)
    const AOD_MINUTES = 0x969C99;   // grey: always-on keeps the route colour for the holds only (§13.1)
    const ROPE = 0xD6D4C8;
    const ANCHOR = 0x969C98;

    // The wall's colour: slate, or black on MIP, which has no panel (DESIGN.md §5.1, #56).
    // On 64 colours the slate rounds to navy. What mixes toward the wall mixes toward this.
    function wall() as Number {
        return mip() ? Graphics.COLOR_BLACK : SLATE;
    }

    // A MIP screen (DESIGN.md §2). getDisplayMode is in every AMOLED product's API and in no
    // MIP product's (the SDK's device API files, #56), and unlike requiresBurnInProtection, which
    // can follow the Always On setting, it cannot change while the face runs.
    function mip() as Boolean {
        return !(System has :getDisplayMode);
    }

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

    // The bitmap fonts' em, from their line height. ttf2bmp writes the line as the face's ascender
    // plus descender, rounded up: 2400/2048 em for Roboto Condensed (1900 + 500 units), so a size
    // 81 font has lineHeight 95 and getFontHeight 95. Every font size here is in em, as in the
    // design and the simulator (CSS font-size), and floor(height / LINE_EM) gives back the size
    // the font was generated at (tools/check-font-config.py holds every generated font to it).
    const LINE_EM = 2400.0 / 2048.0;

    function em(dc as Graphics.Dc, f as Graphics.FontType) as Float {
        return Math.floor(dc.getFontHeight(f) / LINE_EM).toFloat();
    }

    // The digits and the tags are bitmap fonts, Roboto Condensed Bold, one size per screen
    // resolution (resources/fonts/fonts.xml, docs/fonts.md). The sizes are what the design's
    // formula gives on each screen, which is no longer computed here: the digits 0.19 H, shrunk to
    // fit Geom.digitMaxW, times Geom.digitScale (DESIGN.md §4.1); the tags so that their two boxes
    // and gap span the minutes' two cells. tools/check-font-config.py checks the sizes against it.

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

    // Widest of the tag characters in font f.
    function tagGlyphWidth(dc as Graphics.Dc, f as Graphics.FontType) as Number {
        var cw = 0;
        var chars = ["8", "B", "I", "E"] as Array<String>;
        for (var i = 0; i < chars.size(); i++) {
            var w = dc.getTextWidthInPixels(chars[i], f);
            if (w > cw) {
                cw = w;
            }
        }
        return cw;
    }

    // The time group's two lines beside the wall: [digits row y, tags row y]. The group is centred
    // vertically, or with TIME_CENTRED moved down so that the digits row is on H/2.
    // A digit is about 0.72 of its font size tall, a tag box 0.96 of the tags' size.
    function groupRows(g as Geom) as Array<Float> {
        var dh = 0.72 * g.digitSize;
        var th = 0.96 * g.tagSize;
        var gap = 0.18 * g.digitSize;
        var top = TIME_CENTRED ? g.H / 2 - dh / 2 : g.H / 2 - (dh + gap + th) / 2;
        return [top + dh / 2, top + dh + gap + th / 2];
    }

    function time(dc as Graphics.Dc, g as Geom, dx as Float, dy as Float, hh as Number, mm as Number, font as Graphics.FontType, hc as Number, mc as Number) as Void {
        if (g.timeGroup) {
            // HHMM right-aligned to groupRight: the four cells end there.
            var cw = 1.04 * dc.getTextWidthInPixels("0", font);
            var y = groupRows(g)[0];
            digits(dc, hh.format("%02d"), g.groupRight - 3 * cw + dx, y + dy, font, hc);
            digits(dc, mm.format("%02d"), g.groupRight - cw + dx, y + dy, font, mc);
            return;
        }
        if (g.timeLinear) {
            // HHMM, no separator (DESIGN.md §4.1): two blocks of fixed cells side by side.
            var cw = 1.04 * dc.getTextWidthInPixels("0", font);
            digits(dc, hh.format("%02d"), g.dcx - cw + dx, g.H / 2 + dy, font, hc);
            digits(dc, mm.format("%02d"), g.dcx + cw + dx, g.H / 2 + dy, font, mc);
            return;
        }
        digits(dc, hh.format("%02d"), g.dcx + dx, g.H * ROW_HOURS + dy, font, hc);
        digits(dc, mm.format("%02d"), g.dcx + dx, g.H * ROW_MINUTES + dy, font, mc);
    }

    // Always-on (DESIGN.md §13.1): the time in its own colours, under a checkerboard that swaps its black
    // and clear pixels every minute, so no pixel of the time is lit two minutes running; and the
    // route's holds as dots at 60 %, stepping round a +/-HOLD_JIT px square, one corner a minute.
    // Nothing else: the burn-in protector blanks the screen past 10 % lit or a pixel lit 3 min.
    const HOLD_JIT = 4;
    // resources/drawables/checker.png, both sides even.
    const CHECKER_W = 258;
    const CHECKER_H = 130;

    function lowPower(dc as Graphics.Dc, g as Geom, r as Route, rc as Number, hh as Number, mm as Number,
                      absMin as Number, font as Graphics.FontType, checker as Graphics.BitmapType) as Void {
        aa(dc);
        time(dc, g, 0.0, 0.0, hh, mm, font, HOURS, AOD_MINUTES);

        // The checker over the time's box: its cells, plus the glyphs' overhang, sized from the
        // font drawn. The bitmap is tiled over the box; its sides are even, so every tile keeps the
        // phase. The simulator blacks the pixels with x + y = absMin (mod 2); the bitmap blacks
        // those with even x + y from its origin, so the origin is moved by 0 or 1 to match.
        var cw = 1.04 * dc.getTextWidthInPixels("0", font);
        var y = groupRows(g)[0];
        var x0 = (g.groupRight - 4 * cw - 2).toNumber();
        var x1 = (g.groupRight + 2).toNumber();
        var half = Climb.maxf(0.5 * g.digitSize, 0.5 * dc.getFontHeight(font)).toNumber() + 2;
        var y0 = (y - half).toNumber();
        var ox = x0 - Climb.posMod(x0 + y0 + absMin, 2);
        dc.setClip(x0, y0, x1 - x0, 2 * half);
        for (var ty = y0; ty < y0 + 2 * half; ty += CHECKER_H) {
            for (var tx = ox; tx < x1; tx += CHECKER_W) {
                dc.drawBitmap(tx, ty, checker);
            }
        }
        dc.clearClip();

        var k = Climb.posMod(absMin, 4);
        var dx = (k == 1 || k == 2) ? HOLD_JIT : -HOLD_JIT;
        var dy = k >= 2 ? HOLD_JIT : -HOLD_JIT;
        dc.setColor(mix(0, rc, 0.6), Graphics.COLOR_TRANSPARENT);
        for (var i = -4; i <= r.lmax; i++) {
            var h = r.hold(i);
            dc.fillCircle(h.x + dx, h.y + dy, Climb.maxf(1.2, h.s * 0.18));
        }
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
                         hh as Number, mm as Number, digitFont as Graphics.FontType, tagFont as Graphics.FontType, tagSize as Float) as Void {
        aa(dc);
        var W = g.W;
        var ww = g.x1 - g.x0;
        var wh = g.y1 - g.y0;

        // Wall and T-nuts (DESIGN.md §5.1); on MIP neither, the T-nuts rounding to black.
        var wc = wall();
        if (!mip()) {
            dc.setColor(wc, Graphics.COLOR_TRANSPARENT);
            if (g.full) {
                dc.fillRectangle(g.x0, g.y0, ww, wh);
            } else {
                dc.fillRoundedRectangle(g.x0, g.y0, ww, wh, W * 0.03);
            }
            var gs = Climb.maxf(7.0, r.dy0 * 1.15);
            var tr = Climb.maxf(0.8, gs * 0.07);
            dc.setColor(mix(wc, 0xFFFFFF, 0.14), Graphics.COLOR_TRANSPARENT);
            var row = 0;
            for (var y = g.y0 + gs * 0.5; y < g.y1; y += gs) {
                for (var x = g.x0 + gs * (row % 2 == 1 ? 0.9 : 0.4); x < g.x1; x += gs) {
                    dc.fillCircle(x, y, tr);
                }
                row++;
            }
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
                hold(dc, o.hold, r.hs * o.hold.s, mix(Climb.GYM[o.ci], wc, 0.62));
            }
        }

        // Volumes.
        dc.setColor(mix(rc, wc, 0.45), Graphics.COLOR_TRANSPARENT);
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

        tags(dc, g, r, rc, tagFont, tagSize);
        time(dc, g, 0.0, 0.0, hh, mm, digitFont, HOURS, rc);
    }

    const ROW_HOURS = 0.365;        // stacked time rows' centres, as fractions of H
    const ROW_MINUTES = 0.635;

    // [grade] and [B/I/E] (DESIGN.md §3.3, enlarged for the prototype), by g.tagMode:
    //   TAGS_INLINE   side by side at mid-height
    //   TAGS_STACKED  grade above proficiency, about mid-height
    //   TAGS_ROWS     grade level with the hours, proficiency level with the minutes
    // Only the time group ships; the other modes draw with the time group's tag font, which is
    // sized for it (fs is that font's em). A layout that ships them needs fonts of its own.
    function tags(dc as Graphics.Dc, g as Geom, r as Route, rc as Number, font as Graphics.FontType, fs as Float) as Void {
        var asc = fs * 0.72;
        var bw;
        var th;
        var lw;
        var rad;
        if (g.tagHug) {
            // A box hugging the glyph: the widest of the characters, padded.
            var cw = tagGlyphWidth(dc, font);
            var pad = fs * 0.12;
            bw = cw + 2 * pad;
            th = asc + 2 * pad;
            lw = Climb.maxf(2.0, fs * 0.05);
            rad = Climb.maxf(2.0, fs * 0.12);
        } else {
            bw = fs * 1.05;
            th = asc + fs * 0.5;
            lw = Climb.maxf(1.5, fs * 0.09);
            rad = Climb.maxf(1.5, fs * 0.18);
        }
        var gap = fs * 0.18;
        var cx1;
        var cy1;
        var cx2;
        var cy2;
        if (g.timeGroup) {
            cx2 = g.groupRight - bw / 2;
            cx1 = cx2 - bw - gap;
            cy1 = groupRows(g)[1];
            cy2 = cy1;
        } else if (g.tagMode == Climb.TAGS_INLINE) {
            cx1 = g.tagX - (bw + gap) / 2;
            cx2 = g.tagX + (bw + gap) / 2;
            cy1 = g.H / 2;
            cy2 = cy1;
        } else if (g.tagMode == Climb.TAGS_STACKED) {
            cx1 = g.tagX;
            cx2 = cx1;
            cy1 = g.H / 2 - (th + gap) / 2;
            cy2 = g.H / 2 + (th + gap) / 2;
        } else {
            cx1 = g.tagX;
            cx2 = cx1;
            cy1 = g.H * ROW_HOURS;
            cy2 = g.H * ROW_MINUTES;
        }
        var letters = ["B", "I", "E"] as Array<String>;

        // Both boxes on whole pixels, the same size, and a whole-pixel ring, so the two outer
        // edges match and the ring is as thick on every side (#41).
        var w = (bw + 0.5).toNumber();
        var h = (th + 0.5).toNumber();
        var rr = (rad + 0.5).toNumber();
        var ring = (lw + 0.5).toNumber();
        var x1 = (cx1 - bw / 2 + 0.5).toNumber();
        var y1 = (cy1 - th / 2 + 0.5).toNumber();
        var x2 = (cx2 - bw / 2 + 0.5).toNumber();
        var y2 = (cy2 - th / 2 + 0.5).toNumber();

        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x1, y1, w, h, rr);
        dc.setColor(mix(rc, 0, 0.82), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx1, cy1, font, r.grade.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // The outline as two fills, the box in the route colour and the inside in the background,
        // so its outer edge is the grade box's by construction: a thick pen's stroke does not
        // land where a fill's edge does, and drew this box 3 px short (#41).
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x2, y2, w, h, rr);
        // The inside shows the background behind the tag: the wall only where the tags sit on
        // it (Geom.tagsOnWall), black everywhere else (#45).
        dc.setColor(g.tagsOnWall ? wall() : Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x2 + ring, y2 + ring, w - 2 * ring, h - 2 * ring, rr > ring + 1 ? rr - ring : 1);
        dc.setColor(rc, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx2, cy2, font, letters[r.prof], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
