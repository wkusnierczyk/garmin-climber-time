import Toybox.Lang;
import Toybox.Math;

// The pure core: time -> route -> pose (DESIGN.md §15.1). No Dc, no Toybox state.
//
// Prototype scope: the settings are fixed at the simulator's defaults, except
// "Cycle proficiency on each grade" (on), so the face runs 4B 4I 4E 5B ... 8E, one
// route per minute, each lowered on the rope at the end of its minute.

class Hold {
    public var x as Float;
    public var y as Float;
    public var type as Number;
    public var rot as Float;
    public var s as Float;

    function initialize(x as Float, y as Float, type as Number, rot as Float, s as Float) {
        self.x = x;
        self.y = y;
        self.type = type;
        self.rot = rot;
        self.s = s;
    }
}

class Volume {
    public var x as Float;
    public var y as Float;
    public var r as Float;
    public var rot as Float;

    function initialize(x as Float, y as Float, r as Float, rot as Float) {
        self.x = x;
        self.y = y;
        self.r = r;
        self.rot = rot;
    }
}

class OtherHold {
    public var hold as Hold;
    public var ci as Number;

    function initialize(hold as Hold, ci as Number) {
        self.hold = hold;
        self.ci = ci;
    }
}

class Geom {
    public var W as Float;
    public var H as Float;
    public var round as Boolean;
    public var x0 as Float;
    public var x1 as Float;
    public var y0 as Float;
    public var y1 as Float;
    public var rx0 as Float;
    public var rx1 as Float;
    public var ry0 as Float;
    public var ry1 as Float;
    public var dcx as Float;
    public var ay as Float;

    public var layout as Number;
    public var full as Boolean;           // the wall is the right half
    public var digitMaxW as Float;        // the widest the two-digit block may be
    public var tagX as Float;             // the tags' centre x
    public var tagMode as Number;         // Climb.TAGS_INLINE, TAGS_STACKED or TAGS_ROWS
    public var digitScale as Float;       // applied after the digits are fitted
    public var timeLinear as Boolean;     // HHMM on one line at mid-height, not stacked
    public var tagHug as Boolean;         // tags sized from the digits, boxes hugging the glyph
    public var timeGroup as Boolean;      // right half: time over tags, right-aligned to groupRight
    public var groupRight as Float;
    public var digitSize as Float = 0.0;  // set by the view once the fonts are fitted
    public var tagSize as Float = 0.0;

    // Wall area (DESIGN.md §3.2, plus the prototype's centre panel):
    //   LAYOUT_PANEL  the floating panel, default width 0.30
    //   LAYOUT_HALF   the right half of the screen
    //   LAYOUT_CENTRE a panel in the middle of the face, as tall as the bezel allows,
    //                 the time stacked left of it and the tags in a line right of it
    function initialize(w as Number, h as Number, round as Boolean, layout as Number, timeLinear as Boolean) {
        W = w.toFloat();
        H = h.toFloat();
        self.round = round;
        self.layout = layout;
        full = layout == Climb.LAYOUT_HALF;
        // Linear time in the centre panel or the right half, for now; its tags then sit
        // in a line too. In the right half, time and tags form a two-line group left of
        // the wall, right-aligned to it and centred vertically.
        self.timeLinear = timeLinear && layout != Climb.LAYOUT_PANEL;
        timeGroup = self.timeLinear && full;
        groupRight = 0.0;
        tagHug = layout == Climb.LAYOUT_CENTRE || timeGroup;
        if (timeGroup) {
            tagMode = Climb.TAGS_INLINE;
        } else if (layout == Climb.LAYOUT_CENTRE) {
            tagMode = self.timeLinear ? Climb.TAGS_INLINE : Climb.TAGS_ROWS;
        } else {
            tagMode = full ? Climb.TAGS_STACKED : Climb.TAGS_INLINE;
        }
        digitScale = layout == Climb.LAYOUT_CENTRE ? 0.9 : 1.0;
        if (timeGroup) {
            digitScale = 1.1;
        }
        digitMaxW = 0.0;
        tagX = 0.0;
        if (layout == Climb.LAYOUT_CENTRE) {
            var ww = Climb.CENTRE_WIDTH * W;
            x0 = (W - ww) / 2;
            x1 = x0 + ww;
            var lb = 0.03 * W;            // the bezel's left edge beside the time
            if (round) {
                // The panel's corners on a circle just inside the bezel.
                var r = W / 2 - 0.02 * W;
                var hh = Math.sqrt(r * r - ww * ww / 4).toFloat();
                y0 = H / 2 - hh;
                y1 = H / 2 + hh;
                // Beside the minutes row's far edge when stacked; beside a linear
                // time's top and bottom, plus a margin, when linear.
                var dy = self.timeLinear ? 0.07 * H : 0.20 * H;
                lb = W / 2 - Math.sqrt(W * W / 4 - dy * dy).toFloat() + (self.timeLinear ? 0.02 * W : 0.0);
            } else {
                y0 = 0.04 * H;
                y1 = 0.96 * H;
            }
            var gapW = 0.025 * W;
            dcx = (lb + x0 - gapW) / 2;
            digitMaxW = x0 - gapW - lb;
            // Mirrors the digits: between the wall right + the gap and the bezel.
            tagX = (x1 + gapW + W - lb) / 2;
            var hp = ww * 0.12;
            var vp = 0.03 * H;
            rx0 = x0 + hp;
            rx1 = x1 - hp;
            ry0 = y0 + vp;
            ry1 = y1 - vp;
            ay = y0 + Climb.maxf(3.0, H * 0.012);
            return;
        }
        if (full) {
            x0 = 0.5 * W;
            x1 = W;
            y0 = 0.0;
            y1 = H;
            dcx = 0.27 * W;
            rx0 = 0.56 * W;
            if (round) {
                rx1 = 0.80 * W;
                ry0 = 0.15 * H;
                ry1 = 0.86 * H;
            } else {
                rx1 = 0.93 * W;
                ry0 = 0.08 * H;
                ry1 = 0.94 * H;
            }
            ay = ry0 - 0.035 * H;
            digitMaxW = 2 * Climb.minf(dcx - 0.03 * W, x0 - dcx - 0.03 * W);
            tagX = (rx1 + W) / 2;
            if (timeGroup) {
                groupRight = x0 - 0.03 * W;
                // The bezel's left edge beside the time's row, a little above mid-height.
                var lb = 0.03 * W;
                if (round) {
                    var dy = 0.10 * H;
                    lb = W / 2 - Math.sqrt(W * W / 4 - dy * dy).toFloat() + 0.03 * W;
                }
                digitMaxW = groupRight - lb;
            }
            return;
        }
        if (round) {
            x0 = 0.555 * W;
            x1 = x0 + 0.30 * W;
            y0 = 0.17 * H;
            y1 = 0.83 * H;
            dcx = 0.30 * W;
        } else {
            x0 = 0.56 * W;
            x1 = Climb.minf(0.95 * W, x0 + 0.30 * W * 1.3);
            y0 = 0.07 * H;
            y1 = 0.93 * H;
            dcx = 0.285 * W;
        }
        var hp = (x1 - x0) * 0.12;
        var vp = 0.03 * H;
        rx0 = x0 + hp;
        rx1 = x1 - hp;
        ry0 = y0 + vp;
        ry1 = y1 - vp;
        ay = y0 + Climb.maxf(3.0, H * 0.012);
        digitMaxW = 2 * Climb.minf(dcx - 0.03 * W, x0 - dcx - 0.03 * W);
        tagX = x1;
    }
}

class Segment {
    public var fall as Boolean;
    public var t0 as Float;
    public var t1 as Float;
    public var cap as Float;
    public var mf as Float;

    function initialize(fall as Boolean, t0 as Float, t1 as Float, cap as Float, mf as Float) {
        self.fall = fall;
        self.t0 = t0;
        self.t1 = t1;
        self.cap = cap;
        self.mf = mf;
    }
}

class Plan {
    public var segs as Array<Segment>;
    public var spu as Float;
    public var miss as Array<Boolean>;
    public var nMiss as Number;
    public var falls as Number;
    public var endM as Float;

    function initialize(segs as Array<Segment>, spu as Float, miss as Array<Boolean>, nMiss as Number, falls as Number, endM as Float) {
        self.segs = segs;
        self.spu = spu;
        self.miss = miss;
        self.nMiss = nMiss;
        self.falls = falls;
        self.endM = endM;
    }
}

// Pose points, as [x0, y0, x1, y1, ...] in the order of the P_* indices.
class Pose {
    public var p as Array<Float>;
    public var c as Float;
    public var lowering as Boolean = false;

    function initialize(c as Float) {
        self.c = c;
        p = new Array<Float>[2 * Climb.P_COUNT];
        for (var i = 0; i < 2 * Climb.P_COUNT; i++) {
            p[i] = 0.0;
        }
    }

    function x(i as Number) as Float { return p[2 * i]; }
    function y(i as Number) as Float { return p[2 * i + 1]; }
    function set(i as Number, x as Float, y as Float) as Void {
        p[2 * i] = x;
        p[2 * i + 1] = y;
    }
}

class Route {
    public var key as Number;
    public var ord as Number;
    public var grade as Number;
    public var prof as Number;
    public var colorIdx as Number;
    public var holds as Array<Hold>;          // index k + 4, k = -4 .. lmax
    public var vols as Array<Volume>;
    public var lmax as Number;
    public var m as Number;                   // move count
    public var dy as Float;
    public var dy0 as Float;
    public var c as Float;
    public var hs as Float;
    public var air as Float;
    public var dynos as Array<Boolean>;       // per move
    public var dynoList as Array<Number>;     // sorted
    public var cum as Array<Float>;
    private var _plans as Dictionary<Number, Plan> = {};

    function initialize(key as Number, g as Geom) {
        self.key = key;
        ord = Climb.posMod(key, 60);
        grade = 4 + (ord / 3) % 5;
        prof = ord % 3;
        colorIdx = Climb.colorIndex(Climb.floorDiv(key, 60), ord);

        var gp = Climb.GRADES[grade - 4];
        var sp = gp[0] as Float;
        var sz = gp[1] as Float;
        var mix = gp[2] as Array<Float>;
        var nDynos = gp[3] as Number;
        air = gp[4] as Float;
        var dw = gp[5] as Float;
        var e = (grade - 4) / 4.0;

        var rng = new Mulberry(Rand.hash(key.toLong() * 31 + 7));
        var l0 = Climb.levels(Climb.MOVES);
        dy0 = (g.ry1 - g.ry0) / (l0 + 4);
        m = Climb.MOVES;
        if (sp != 1.0) {
            var tgt = 1 + (l0 - 1) / sp;
            m = 4;
            while (Climb.levels(m + 1) <= tgt) {
                m++;
            }
        }
        lmax = Climb.levels(m);
        dy = (g.ry1 - g.ry0 - 5 * dy0) / Climb.maxf(1.0, (lmax - 1).toFloat());
        var cx = (g.rx0 + g.rx1) / 2;
        var half = (g.rx1 - g.rx0) / 2;
        var phase = rng.next() * 6.283;
        var lean = rng.next() * 2 - 1;
        c = Climb.minf(5 * dy0, (g.x1 - g.x0) * 0.85);
        hs = Climb.clampf(dy0 * 0.62, 3.5, 15.0);
        var hsg = hs * sz;

        holds = new Array<Hold>[lmax + 5];
        for (var k = -4; k <= lmax; k++) {
            var side = (k & 1) != 0 ? 1.0 : -1.0;
            var x = cx + half * 0.30 * Math.sin(k * 0.33 + phase) + lean * half * 0.18 * (k.toFloat() / lmax) + side * half * (0.16 + 0.30 * rng.next() + e * 0.08);
            x = Climb.clampf(x.toFloat(), g.rx0 + hs * 0.6, g.rx1 - hs * 0.6);
            var y = levelY(g, k) + (rng.next() - 0.5) * (k <= 1 ? dy0 : dy) * 0.25;
            var type;
            if (k < 0) {
                type = Climb.FOOT;
            } else if (k >= lmax - 1) {
                type = Climb.JUG;
            } else {
                type = Climb.pickMix(mix, rng.next());
            }
            var rot = (rng.next() - 0.5) * 0.9;
            var s = k < 0 ? hsg * 0.65 : hsg * (0.9 + rng.next() * 0.25) * (type == Climb.MICRO ? 0.75 : 1.0);
            holds[k + 4] = new Hold(x, y, type, rot, s);
        }
        // Each side's holds strictly climb.
        for (var k = -2; k <= lmax; k++) {
            var lim = holds[k + 2].y - 0.6 * Climb.minf(dy, dy0);
            if (holds[k + 4].y > lim) {
                holds[k + 4].y = lim;
            }
        }
        vols = [] as Array<Volume>;
        var nv = 1 + (rng.next() < 0.5 ? 1 : 0);
        for (var v = 0; v < nv; v++) {
            var k = 3 + (rng.next() * (lmax - 6)).toNumber();
            var h = holds[k + 4];
            var vx = h.x + (rng.next() - 0.5) * hs * 1.4;
            var vr = hs * (1.7 + rng.next() * 0.6);
            vols.add(new Volume(vx, h.y + hs * 0.3, vr, rng.next() * 6.283));
        }

        // Jumps: hand moves, at least one limb cycle apart (makeDynos).
        dynos = new Array<Boolean>[m];
        for (var i = 0; i < m; i++) {
            dynos[i] = false;
        }
        dynoList = [] as Array<Number>;
        if (nDynos > 0 && m >= 8) {
            var r2 = new Mulberry(Rand.hash(key.toLong() * 17 + 3));
            var cand = [] as Array<Number>;
            for (var i = 2; i <= m - 4; i += 2) {
                cand.add(i);
            }
            for (var j = cand.size() - 1; j > 0; j--) {
                var kk = (r2.next() * (j + 1)).toNumber();
                var tmp = cand[j];
                cand[j] = cand[kk];
                cand[kk] = tmp;
            }
            for (var ci = 0; ci < cand.size(); ci++) {
                if (dynoList.size() >= nDynos) {
                    break;
                }
                var i = cand[ci];
                var ok = true;
                for (var q = 0; q < dynoList.size(); q++) {
                    if ((dynoList[q] - i).abs() < 4) {
                        ok = false;
                    }
                }
                if (ok) {
                    dynoList.add(i);
                }
            }
            for (var q = 0; q < dynoList.size(); q++) {
                var i = dynoList[q];
                dynos[i] = true;
                var o = i % 4;
                var lv = Climb.START[o] + 2 * ((i - o + 3) / 4) + 2;
                if (lv <= lmax) {
                    var h = holds[lv + 4];
                    h.type = Climb.JUG;
                    h.s = hs * 1.05;
                    h.y -= 0.6 * dy;
                }
            }
            Climb.sortNumbers(dynoList);
        }
        cum = new Array<Float>[m + 1];
        cum[0] = 0.0;
        for (var i = 0; i < m; i++) {
            cum[i + 1] = cum[i] + (dynos[i] ? dw : 1.0);
        }
    }

    // Level y: the start keeps grade-6 spacing at every grade (DESIGN.md §6.2).
    private function levelY(g as Geom, k as Number) as Float {
        return k <= 1 ? g.ry1 - (k + 4) * dy0 : g.ry1 - 5 * dy0 - (k - 1) * dy;
    }

    function hold(k as Number) as Hold {
        return holds[k + 4];
    }

    function plan(t as Number) as Plan {
        var p = _plans[t];
        if (p == null) {
            p = Climb.attemptPlan(self, t.toFloat());
            _plans[t] = p;
        }
        return p;
    }
}

module Climb {

    enum { LAYOUT_PANEL, LAYOUT_HALF, LAYOUT_CENTRE }
    const CENTRE_WIDTH = 0.36;     // the centre panel's width, as a fraction of W
    // The tags: side by side, stacked, or stacked level with the hours and minutes rows.
    enum { TAGS_INLINE, TAGS_STACKED, TAGS_ROWS }

    const MOVES = 30;          // moves per minute at grade 6
    const LOWER = 3;           // lower-off seconds
    const START = [0, -4, 1, -3] as Array<Number>;   // LH, LF, RH, RF

    enum { JUG, CRIMP, SLOPER, PINCH, EDGE, MICRO, FOOT }
    enum { BEGINNER, INTERMEDIATE, EXPERT }

    enum {
        P_SM, P_HM, P_SL, P_SR, P_PL, P_PR, P_LH, P_RH, P_LF, P_RF, P_EL, P_ER, P_KL, P_KR, P_HEAD, P_COUNT
    }

    // [sp, sz, mix as [type, p, type, p, ...], jumps, air, jump duration]
    const GRADES = [
        [0.80, 1.35, [0.0, 0.75, 3.0, 0.15, 2.0, 0.10], 0, 0.0, 1.0],
        [0.90, 1.15, [0.0, 0.50, 3.0, 0.20, 2.0, 0.15, 1.0, 0.15], 0, 0.0, 1.0],
        [1.00, 1.00, [0.0, 0.30, 1.0, 0.25, 2.0, 0.20, 3.0, 0.25], 0, 0.0, 1.0],
        [1.12, 0.76, [0.0, 0.05, 1.0, 0.35, 2.0, 0.20, 3.0, 0.15, 4.0, 0.25], 2, 0.40, 2.0],
        [1.24, 0.56, [1.0, 0.25, 4.0, 0.35, 2.0, 0.10, 5.0, 0.30], 4, 0.55, 2.5]
    ] as Array<Array>;

    const GYM = [0xF7C948, 0x34C46A, 0x3A86FF, 0xEF4444, 0xA06CF0, 0xFF8C2B, 0xFF6FB0, 0x22C3C3, 0xE8E8E8] as Array<Number>;

    const FALL_T = 1.0;
    const FALL_LOWER_T = 2.5;

    function minf(a as Float, b as Float) as Float { return a < b ? a : b; }
    function maxf(a as Float, b as Float) as Float { return a > b ? a : b; }
    function clampf(v as Float, a as Float, b as Float) as Float { return v < a ? a : (v > b ? b : v); }
    function lerp(a as Float, b as Float, t as Float) as Float { return a + (b - a) * t; }
    function ease(t as Float) as Float {
        if (t < 0.5) {
            return 2 * t * t;
        }
        var u = -2 * t + 2;
        return 1 - u * u / 2;
    }
    function posMod(a as Number, n as Number) as Number { return ((a % n) + n) % n; }
    function floorDiv(a as Number, n as Number) as Number { return (a - posMod(a, n)) / n; }
    function floorf(v as Float) as Number {
        var i = v.toNumber();
        return (i > v) ? i - 1 : i;
    }

    function nMoves(m as Number, o as Number) as Number {
        var n = m - o + 3;
        return n >= 0 ? n / 4 : -((-n + 3) / 4);
    }

    function levels(m as Number) as Number {
        var a = 2 * nMoves(m, 0);
        var b = 1 + 2 * nMoves(m, 2);
        return a > b ? a : b;
    }

    function pickMix(mix as Array<Float>, r as Float) as Number {
        var a = 0.0;
        for (var i = 0; i < mix.size(); i += 2) {
            a += mix[i + 1];
            if (r < a) {
                return mix[i].toNumber();
            }
        }
        return mix[0].toNumber();
    }

    function sortNumbers(a as Array<Number>) as Void {
        for (var i = 1; i < a.size(); i++) {
            var v = a[i];
            var j = i - 1;
            while (j >= 0 && a[j] > v) {
                a[j + 1] = a[j];
                j--;
            }
            a[j + 1] = v;
        }
    }

    // Shuffled gym colour, never the same twice in a row within the hour (Appendix B.2).
    function colorIndex(hour as Number, ord as Number) as Number {
        var i = Rand.hashMod(hour.toLong() * 7919 + 13, 9);
        for (var k = 1; k <= ord; k++) {
            i = (i + 1 + Rand.hashMod(hour.toLong() * 61 + k, 8)) % 9;
        }
        return i;
    }

    // Three other routes on the wall, per day (DESIGN.md §5.3).
    function otherHolds(day as Number, g as Geom) as Array<OtherHold> {
        var rng = new Mulberry(Rand.hash(day.toLong() * 97 + 3));
        var list = [] as Array<OtherHold>;
        var xa = g.x0 + (g.x1 - g.x0) * 0.06;
        var xb = g.x1 - (g.x1 - g.x0) * 0.06;
        var types = [JUG, CRIMP, SLOPER, PINCH] as Array<Number>;
        for (var r = 0; r < 3; r++) {
            var ci = Rand.hashMod(day.toLong() * 5 + r, 9);
            for (var i = 0; i < 11; i++) {
                var x = lerp(xa, xb, rng.next());
                var y = lerp(g.full ? g.H * 0.05 : g.ry0, g.ry1, rng.next());
                if (g.round) {
                    var dx = x - g.W / 2;
                    var dy = y - g.H / 2;
                    var rr = g.W / 2 - 10;
                    if (dx * dx + dy * dy > rr * rr) {
                        continue;
                    }
                }
                var s = 0.55 + rng.next() * 0.5;
                var t = types[(rng.next() * 4).toNumber()];
                var rot = (rng.next() - 0.5) * 0.9;
                list.add(new OtherHold(new Hold(x, y, t, rot, s), ci));
            }
        }
        return list;
    }

    // ---------- timing ----------

    function uOfM(r as Route, m as Float) as Float {
        var i = floorf(m);
        if (i < 0) { i = 0; }
        if (i > r.m - 1) { i = r.m - 1; }
        return r.cum[i] + (m - i) * (r.cum[i + 1] - r.cum[i]);
    }

    function mOfU(r as Route, u as Float) as Float {
        var i = 0;
        while (i < r.m - 1 && r.cum[i + 1] <= u) {
            i++;
        }
        return minf(r.m.toFloat(), i + (u - r.cum[i]) / (r.cum[i + 1] - r.cum[i]));
    }

    // [m, missPhase], missPhase < 0 when not in a missed attempt.
    function mapUnits(r as Route, u as Float, miss as Array<Boolean>) as Array<Float> {
        for (var j = 0; j < r.m; j++) {
            var w = r.cum[j + 1] - r.cum[j];
            if (miss[j]) {
                if (u < w) {
                    return [j.toFloat(), u / w];
                }
                u -= w;
            }
            if (u < w) {
                return [j + u / w, -1.0];
            }
            u -= w;
        }
        return [r.m.toFloat(), -1.0];
    }

    // Appendix B.6.
    function attemptPlan(r as Route, t as Float) as Plan {
        var pf = r.prof;
        var rng = new Mulberry(Rand.hash(r.key.toLong() * 13 + (pf == BEGINNER ? 5 : pf == INTERMEDIATE ? 3 : 1)));
        var maxFalls = pf == EXPERT ? 0 : (pf == INTERMEDIATE ? (rng.next() < 0.5 ? 1 : 0) : 99);
        var dyn = r.dynoList;
        var firstDyno = dyn.size() > 0 ? dyn[0] : -1;
        var miss = new Array<Boolean>[r.m];
        for (var i = 0; i < r.m; i++) {
            miss[i] = false;
        }
        var nMiss = 0;
        if (pf == INTERMEDIATE && maxFalls == 0) {
            for (var i = 0; i < dyn.size(); i++) {
                if (rng.next() < 0.5) {
                    miss[dyn[i]] = true;
                    nMiss++;
                }
            }
        }
        var extra = 0.0;
        for (var i = 0; i < r.m; i++) {
            if (miss[i]) {
                extra += r.cum[i + 1] - r.cum[i];
            }
        }
        var spu = t / (r.cum[r.m] + extra);
        var segs = [] as Array<Segment>;
        var tt = 0.0;
        var nf = 0;
        while (true) {
            var mf = -1.0;
            if (nf < maxFalls) {
                mf = r.m * (pf == BEGINNER ? 0.15 + 0.25 * rng.next() : 0.4 + 0.2 * rng.next());
                if (pf == BEGINNER && firstDyno >= 0 && firstDyno < mf) {
                    mf = firstDyno + 0.5;
                }
                if (pf == INTERMEDIATE) {
                    for (var i = 0; i < dyn.size(); i++) {
                        if (mf >= dyn[i] && mf < dyn[i] + 1) {
                            mf = dyn[i].toFloat();
                            break;
                        }
                    }
                }
                if (tt + uOfM(r, mf) * spu + FALL_T + FALL_LOWER_T + 3 > t) {
                    mf = -1.0;
                }
            }
            if (mf < 0) {
                var cap = r.m.toFloat();
                if (pf == BEGINNER) {
                    cap = minf(0.8 * r.m, firstDyno >= 0 ? firstDyno.toFloat() : r.m.toFloat());
                }
                segs.add(new Segment(false, tt, t, cap, 0.0));
                break;
            }
            var tc = uOfM(r, mf) * spu;
            segs.add(new Segment(false, tt, tt + tc, r.m.toFloat(), 0.0));
            tt += tc;
            segs.add(new Segment(true, tt, tt + FALL_T + FALL_LOWER_T, 0.0, mf));
            tt += FALL_T + FALL_LOWER_T;
            nf++;
        }
        var last = segs[segs.size() - 1];
        var reached = nMiss > 0 ? mapUnits(r, (t - last.t0) / spu, miss)[0] : mOfU(r, (t - last.t0) / spu);
        last.cap = floorf(minf(last.cap, reached) + 1e-6).toFloat();
        return new Plan(segs, spu, miss, nMiss, nf, last.cap);
    }

    // ---------- poses ----------

    function limbAt(r as Route, o as Number, m as Float) as Array<Float> {
        var i = floorf(m);
        var f = m - i;
        if (i >= r.m) {
            i = r.m;
            f = 0.0;
        }
        var done = (i - o + 3) / 4;
        if (i - o + 3 < 0) { done = 0; }
        var lv = START[o] + 2 * done;
        var p = r.hold(lv);
        if (i < r.m && i % 4 == o && f > 0) {
            var q = r.hold(lv + 2);
            var e = ease(f);
            var side = o < 2 ? -1.0 : 1.0;
            return [lerp(p.x, q.x, e) + side * Math.sin(Math.PI * f).toFloat() * 0.07 * r.c, lerp(p.y, q.y, e)];
        }
        return [p.x, p.y];
    }

    // Two-bone IK, bending toward the limb's side (Appendix B.5).
    function ik(jx as Float, jy as Float, tx as Float, ty as Float, a as Float, side as Number) as Array<Float> {
        var dx = tx - jx;
        var dy = ty - jy;
        var d = Math.sqrt(dx * dx + dy * dy).toFloat();
        if (d < 1e-6) { d = 1e-6; }
        var ux = dx / d;
        var uy = dy / d;
        if (d >= 2 * a - 0.01) {
            return [jx + ux * d / 2, jy + uy * d / 2];
        }
        var x = d / 2;
        var h = Math.sqrt(maxf(0.0, a * a - x * x)).toFloat();
        var bx = jx + ux * x;
        var by = jy + uy * x;
        var n1x = bx - uy * h;
        var n1y = by + ux * h;
        var n2x = bx + uy * h;
        var n2y = by - ux * h;
        var pick1 = side < 0 ? n1x < n2x : n1x > n2x;
        return pick1 ? [n1x, n1y] : [n2x, n2y];
    }

    function finishLimbs(P as Pose) as Void {
        var c = P.c;
        var a = 0.19 * c;
        var l = 0.22 * c;
        var e = ik(P.x(P_SL), P.y(P_SL), P.x(P_LH), P.y(P_LH), a, -1);
        P.set(P_EL, e[0], e[1]);
        e = ik(P.x(P_SR), P.y(P_SR), P.x(P_RH), P.y(P_RH), a, 1);
        P.set(P_ER, e[0], e[1]);
        e = ik(P.x(P_PL), P.y(P_PL), P.x(P_LF), P.y(P_LF), l, -1);
        P.set(P_KL, e[0], e[1]);
        e = ik(P.x(P_PR), P.y(P_PR), P.x(P_RF), P.y(P_RF), l, 1);
        P.set(P_KR, e[0], e[1]);
    }

    // Pose from holds at move progress m (DESIGN.md §9.2). missPhase >= 0 is a missed jump.
    function pose(r as Route, m as Float, noAir as Boolean, missPhase as Float) as Pose {
        var c = r.c;
        var lh = limbAt(r, 0, m);
        var lf = limbAt(r, 1, m);
        var rh = limbAt(r, 2, m);
        var rf = limbAt(r, 3, m);
        var di = floorf(m);
        var df = m - di;
        var air = 0.0;
        if (!noAir && di < r.m && di >= 0 && r.dynos[di] && df > 0) {
            air = Math.sin(Math.PI * df).toFloat();
        }
        if (missPhase >= 0) {
            air = Math.sin(Math.PI * missPhase).toFloat() * 0.85;
            var o = di % 4;
            var lv = START[o] + 2 * ((di - o + 3) / 4);
            if (lv + 2 <= r.lmax) {
                var p = r.hold(lv);
                var q = r.hold(lv + 2);
                var k = 0.65 * Math.sin(Math.PI * missPhase).toFloat();
                var hand = o == 0 ? lh : rh;
                hand[0] = lerp(p.x, q.x, k);
                hand[1] = lerp(p.y, q.y, k);
            }
        }
        var lowHand = maxf(lh[1], rh[1]) + 0.12 * c;
        if (lf[1] < lowHand) { lf[1] = lowHand; }
        if (rf[1] < lowHand) { rf[1] = lowHand; }
        var hx = (lh[0] + rh[0]) / 2;
        var hy = (lh[1] + rh[1]) / 2;
        var fx = (lf[0] + rf[0]) / 2;
        var fy = (lf[1] + rf[1]) / 2;
        var gap = maxf(fy - hy, 0.2 * c);
        var smx = hx * 0.6 + fx * 0.4;
        var smy = hy + minf(0.30 * c, gap * 0.3);
        var hmx = fx * 0.6 + hx * 0.4;
        var hmy = fy - minf(0.34 * c, gap * 0.34);
        var dx = smx - hmx;
        var dy = smy - hmy;
        var d = Math.sqrt(dx * dx + dy * dy).toFloat();
        if (d == 0.0) { d = 1.0; }
        dx /= d;
        dy /= d;
        if (dy > -0.75) {
            dy = -0.75;
            dx = (dx < 0 ? -1 : 1) * Math.sqrt(1 - dy * dy).toFloat();
        }
        var tl = 0.30 * c;
        var midx = (smx + hmx) / 2;
        var midy = (smy + hmy) / 2;
        smx = midx + dx * tl / 2;
        smy = midy + dy * tl / 2;
        hmx = midx - dx * tl / 2;
        hmy = midy - dy * tl / 2;
        var px = dy;
        var py = -dx;
        var P = new Pose(c);
        P.set(P_SM, smx, smy);
        P.set(P_HM, hmx, hmy);
        P.set(P_SL, smx + px * 0.08 * c, smy + py * 0.08 * c);
        P.set(P_SR, smx - px * 0.08 * c, smy - py * 0.08 * c);
        P.set(P_PL, hmx + px * 0.055 * c, hmy + py * 0.055 * c);
        P.set(P_PR, hmx - px * 0.055 * c, hmy - py * 0.055 * c);
        P.set(P_HEAD, smx + dx * 0.14 * c, smy + dy * 0.14 * c);
        if (air > 0) {
            var lift = air * r.air * c;
            var body = [P_SM, P_HM, P_SL, P_SR, P_PL, P_PR, P_HEAD] as Array<Number>;
            for (var i = 0; i < body.size(); i++) {
                P.p[2 * body[i] + 1] -= lift;
            }
            var movingLeft = di % 4 == 0;
            var mv = movingLeft ? lh : rh;
            var ms = movingLeft ? P_SL : P_SR;
            var st = movingLeft ? rh : lh;
            var ss = movingLeft ? P_SR : P_SL;
            var sd = movingLeft ? 1.0 : -1.0;
            mv[1] = minf(mv[1], P.y(ms) - 0.32 * c * air);
            st[0] = lerp(st[0], P.x(ss) + sd * 0.05 * c, air);
            st[1] = lerp(st[1], P.y(ss) - 0.34 * c, air);
            lf[0] = lerp(lf[0], P.x(P_PL) - 0.08 * c, air);
            lf[1] = lerp(lf[1], P.y(P_PL) + 0.40 * c, air);
            rf[0] = lerp(rf[0], P.x(P_PR) + 0.08 * c, air);
            rf[1] = lerp(rf[1], P.y(P_PR) + 0.40 * c, air);
        }
        P.set(P_LH, lh[0], lh[1]);
        P.set(P_RH, rh[0], rh[1]);
        P.set(P_LF, lf[0], lf[1]);
        P.set(P_RF, rf[0], rf[1]);
        finishLimbs(P);
        return P;
    }

    function blend(A as Pose, B as Pose, w as Float) as Pose {
        var P = new Pose(A.c);
        for (var i = 0; i < 2 * P_COUNT; i++) {
            P.p[i] = lerp(A.p[i], B.p[i], w);
        }
        return P;
    }

    // In the harness, hands on the rope, feet walking the wall (DESIGN.md §9.3).
    function hangPose(hx as Float, hy as Float, c as Float, ph as Float) as Pose {
        var P = new Pose(c);
        var smy = hy - 0.30 * c;
        P.set(P_SM, hx, smy);
        P.set(P_HM, hx, hy);
        P.set(P_SL, hx - 0.08 * c, smy);
        P.set(P_SR, hx + 0.08 * c, smy);
        P.set(P_PL, hx - 0.055 * c, hy);
        P.set(P_PR, hx + 0.055 * c, hy);
        P.set(P_LH, hx - 0.03 * c, smy - 0.16 * c);
        P.set(P_RH, hx + 0.03 * c, smy - 0.03 * c);
        var w = Math.sin(ph).toFloat() * 0.05 * c;
        P.set(P_LF, hx - 0.16 * c, hy + 0.34 * c + w);
        P.set(P_RF, hx + 0.16 * c, hy + 0.34 * c - w);
        P.set(P_HEAD, hx, smy - 0.14 * c);
        finishLimbs(P);
        return P;
    }

    function lowerPose(r as Route, rn as Route, u as Float, mEnd as Float) as Pose {
        var A = pose(r, mEnd, false, -1.0);
        var B = pose(rn, 0.0, false, -1.0);
        var e = ease(u);
        var T = hangPose(lerp(A.x(P_HM), B.x(P_HM), e), lerp(A.y(P_HM), B.y(P_HM), e), r.c, u * Math.PI.toFloat() * 4);
        var w = minf(clampf(u / 0.2, 0.0, 1.0), clampf((1 - u) / 0.2, 0.0, 1.0));
        var P = blend(u < 0.5 ? A : B, T, w);
        P.lowering = true;
        return P;
    }

    function fallPose(r as Route, mf as Float, tt as Float) as Pose {
        var c = r.c;
        var A = pose(r, mf, false, -1.0);
        var B = pose(r, 0.0, false, -1.0);
        var h0x = A.x(P_HM);
        var h0y = minf(A.y(P_HM) + 0.45 * c, B.y(P_HM));
        var P;
        if (tt < FALL_T) {
            var k = ease(clampf(tt / 0.35, 0.0, 1.0));
            var hx = A.x(P_HM) + Math.sin(tt * 9).toFloat() * 0.05 * c;
            var hy = lerp(A.y(P_HM), h0y, k);
            P = blend(A, hangPose(hx, hy, c, 0.0), k);
        } else {
            var u = clampf((tt - FALL_T) / FALL_LOWER_T, 0.0, 1.0);
            var e = ease(u);
            var T = hangPose(lerp(h0x, B.x(P_HM), e), lerp(h0y, B.y(P_HM), e), c, u * Math.PI.toFloat() * 3);
            P = blend(B, T, clampf((1 - u) / 0.25, 0.0, 1.0));
        }
        P.lowering = true;
        return P;
    }

    function climbPose(r as Route, s as Float, t as Number) as Pose {
        var pl = r.plan(t);
        var tt = clampf(s, 0.0, t.toFloat());
        var n = pl.segs.size();
        for (var i = 0; i < n; i++) {
            var sg = pl.segs[i];
            if (tt < sg.t1 || i == n - 1) {
                if (sg.fall) {
                    return fallPose(r, sg.mf, tt - sg.t0);
                }
                if (pl.nMiss > 0) {
                    var mu = mapUnits(r, (tt - sg.t0) / pl.spu, pl.miss);
                    if (mu[1] >= 0) {
                        return pose(r, mu[0], false, mu[1]);
                    }
                    return pose(r, minf(sg.cap, mu[0]), false, -1.0);
                }
                return pose(r, minf(sg.cap, mOfU(r, (tt - sg.t0) / pl.spu)), false, -1.0);
            }
        }
        return pose(r, 0.0, false, -1.0);
    }

    // Every minute is a "line" minute: climb until :56, lowered on the rope to the next
    // route's start over the last 3 s (DESIGN.md §10, §11.3).
    function poseAt(r as Route, rn as Route, s as Number) as Pose {
        var top = 59 - LOWER;
        if (s > top) {
            return lowerPose(r, rn, (s - top).toFloat() / (60 - top), r.plan(top).endM);
        }
        return climbPose(r, s.toFloat(), top);
    }

}
