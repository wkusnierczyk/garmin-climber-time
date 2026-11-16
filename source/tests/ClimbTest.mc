using Toybox.Test;

import Toybox.Lang;

// The face's arithmetic against the simulator (ClimbGolden, from tools/make-golden.py), and
// the rules of DESIGN.md §6.3, §8.3, §11.3, §12 and §14.3 that the golden values do not spell
// out.
(:test)
class ClimbTest {

    (:test)
    static function hashMatchesTheSimulator(logger as Test.Logger) as Boolean {
        for (var i = 0; i < ClimbGolden.HASH_IN.size(); i++) {
            var h = Rand.hash(ClimbGolden.HASH_IN[i]);
            if (h != ClimbGolden.HASH_OUT[i]) {
                logger.error("hash(" + ClimbGolden.HASH_IN[i] + ") = " + h + ", simulator " + ClimbGolden.HASH_OUT[i]);
                return false;
            }
        }
        return true;
    }

    (:test)
    static function mulberryMatchesTheSimulator(logger as Test.Logger) as Boolean {
        var m = new Mulberry(Rand.hash(ClimbGolden.BASE.toLong() * 31 + 7));
        for (var i = 0; i < ClimbGolden.MUL.size(); i++) {
            var v = m.next();
            if ((v - ClimbGolden.MUL[i]).abs() > 1e-6) {
                logger.error("draw " + i + " = " + v + ", simulator " + ClimbGolden.MUL[i]);
                return false;
            }
        }
        return true;
    }

    (:test)
    static function roundColoursMatchTheSimulator(logger as Test.Logger) as Boolean {
        for (var i = 0; i < ClimbGolden.ROUND_IN.size(); i++) {
            var c = Climb.roundColor(ClimbGolden.ROUND_IN[i]);
            if (c != ClimbGolden.ROUND_OUT[i]) {
                logger.error("round " + ClimbGolden.ROUND_IN[i] + " colour " + c + ", simulator " + ClimbGolden.ROUND_OUT[i]);
                return false;
            }
        }
        return true;
    }

    // Every grade and proficiency: the numbers, the jumps, and each hold's position, type and
    // size, and each volume.
    (:test)
    static function routesMatchTheSimulator(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        for (var i = 0; i < ClimbGolden.ROUTES.size(); i++) {
            var want = ClimbGolden.ROUTES[i];
            var at = want[0] as Number;
            var r = new Route(ClimbGolden.BASE + at, g);
            var got = [r.grade, r.prof, r.colorIdx, r.m, r.lmax] as Array<Number>;
            for (var f = 0; f < got.size(); f++) {
                if (got[f] != (want[f + 1] as Number)) {
                    logger.error("+" + at + ": field " + f + " = " + got[f] + ", simulator " + (want[f + 1] as Number));
                    return false;
                }
            }
            var dynos = want[6] as Array<Number>;
            if (!sameNumbers(r.dynoList, dynos)) {
                logger.error("+" + at + ": jumps " + r.dynoList + ", simulator " + dynos);
                return false;
            }
            var hs = ClimbGolden.HOLDS[i];
            for (var k = -4; k <= r.lmax; k++) {
                var h = r.hold(k);
                var j = 4 * (k + 4);
                if (!ClimbGolden.near(h.x, hs[j]) || !ClimbGolden.near(h.y, hs[j + 1]) || h.type != hs[j + 2]
                    || !ClimbGolden.near(h.s, hs[j + 3])) {
                    logger.error("+" + at + " hold " + k + ": " + h.x + ", " + h.y + ", type " + h.type + ", size " + h.s
                        + "; simulator " + hs[j] + ", " + hs[j + 1] + ", type " + hs[j + 2] + ", size " + hs[j + 3]);
                    return false;
                }
            }
            var vs = ClimbGolden.VOLS[i];
            if (r.vols.size() * 3 != vs.size()) {
                logger.error("+" + at + ": " + r.vols.size() + " volumes, simulator " + vs.size() / 3);
                return false;
            }
            for (var v = 0; v < r.vols.size(); v++) {
                var o = r.vols[v];
                if (!ClimbGolden.near(o.x, vs[3 * v]) || !ClimbGolden.near(o.y, vs[3 * v + 1]) || !ClimbGolden.near(o.r, vs[3 * v + 2])) {
                    logger.error("+" + at + " volume " + v + ": " + o.x + ", " + o.y + ", " + o.r + "; simulator " + vs[3 * v] + ", " + vs[3 * v + 1] + ", " + vs[3 * v + 2]);
                    return false;
                }
            }
        }
        return true;
    }

    // Falls, missed jumps, where the climb ends and every segment, against the simulator.
    (:test)
    static function plansMatchTheSimulator(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        for (var i = 0; i < ClimbGolden.ROUTES.size(); i++) {
            var at = ClimbGolden.ROUTES[i][0] as Number;
            var want = ClimbGolden.PLANS[i];
            var pl = new Route(ClimbGolden.BASE + at, g).plan(ClimbGolden.TOP);
            var segs = want[3] as Array<Float>;
            if (pl.falls != (want[0] as Number) || pl.nMiss != (want[1] as Number) || !ClimbGolden.near(pl.endM, want[2] as Float)
                || pl.segs.size() * 2 != segs.size()) {
                logger.error("+" + at + ": " + pl.falls + " falls, " + pl.nMiss + " misses, ends at " + pl.endM + ", " + pl.segs.size()
                    + " segments; simulator " + (want[0] as Number) + ", " + (want[1] as Number) + ", " + (want[2] as Float) + ", " + segs.size() / 2);
                return false;
            }
            for (var s = 0; s < pl.segs.size(); s++) {
                if (!ClimbGolden.near(pl.segs[s].t0, segs[2 * s]) || !ClimbGolden.near(pl.segs[s].t1, segs[2 * s + 1])) {
                    logger.error("+" + at + " segment " + s + ": " + pl.segs[s].t0 + " to " + pl.segs[s].t1 + "; simulator "
                        + segs[2 * s] + " to " + segs[2 * s + 1]);
                    return false;
                }
            }
        }
        return true;
    }

    // 4B 4I 4E 5B ... 8E, one minute each, from 4B at every hour (§8.3, §12.4).
    (:test)
    static function gradesCycleEveryFifteenMinutes(logger as Test.Logger) as Boolean {
        var want = [4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8] as Array<Number>;
        var g = ClimbGolden.geom();
        for (var k = 0; k < 60; k++) {
            var r = new Route(ClimbGolden.BASE + k, g);
            if (r.grade != want[k % 15] || r.prof != k % 3) {
                logger.error("minute " + k + ": grade " + r.grade + ", proficiency " + r.prof);
                return false;
            }
        }
        return true;
    }

    // The three climbs of a grade share holds, jumps and colour; the next grade does not (§6.3, §7).
    (:test)
    static function oneRoutePerGradeRound(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        var b = new Route(ClimbGolden.BASE + 12, g);
        var e = new Route(ClimbGolden.BASE + 14, g);
        var n = new Route(ClimbGolden.BASE + 15, g);
        for (var k = -4; k <= b.lmax; k++) {
            if (b.hold(k).x != e.hold(k).x || b.hold(k).y != e.hold(k).y) {
                logger.error("hold " + k + " differs within the round");
                return false;
            }
        }
        if (!sameNumbers(b.dynoList, e.dynoList) || b.colorIdx != e.colorIdx) {
            logger.error("jumps or colour differ within the round");
            return false;
        }
        if (n.colorIdx == e.colorIdx) {
            logger.error("the next grade keeps the colour");
            return false;
        }
        return true;
    }

    // Every minute of an hour: the plan covers 0 to :56 without a gap, the proficiencies keep
    // their rules (§12.1), and the lower-off takes the last 3 s (§11.3, §14.3).
    (:test)
    static function plansFollowTheRules(logger as Test.Logger) as Boolean {
        if (Climb.LOWER != 3 || ClimbGolden.TOP != 59 - Climb.LOWER) {
            logger.error("the lower-off is " + Climb.LOWER + " s, not 3");
            return false;
        }
        var g = ClimbGolden.geom();
        var top = ClimbGolden.TOP;
        for (var k = 0; k < 60; k++) {
            var r = new Route(ClimbGolden.BASE + k, g);
            var rn = new Route(ClimbGolden.BASE + k + 1, g);
            var pl = r.plan(top);
            var t = 0.0;
            for (var s = 0; s < pl.segs.size(); s++) {
                if (!ClimbGolden.near(pl.segs[s].t0, t)) {
                    logger.error("minute " + k + ": segment " + s + " starts at " + pl.segs[s].t0 + ", not " + t);
                    return false;
                }
                t = pl.segs[s].t1;
            }
            if (!ClimbGolden.near(t, top)) {
                logger.error("minute " + k + ": the plan ends at " + t + ", not " + top);
                return false;
            }
            var topped = pl.endM >= r.m - 0.001;
            if (r.prof == Climb.EXPERT && (pl.falls != 0 || !topped)) {
                logger.error("minute " + k + ": the expert falls or stops short");
                return false;
            }
            if (r.prof == Climb.INTERMEDIATE && (pl.falls > 1 || topped != (pl.falls == 0))) {
                logger.error("minute " + k + ": the intermediate falls " + pl.falls + " times, tops out " + topped);
                return false;
            }
            if (r.prof == Climb.BEGINNER && (topped || pl.falls < 1
                || (r.dynoList.size() > 0 && pl.endM > r.dynoList[0] + 0.001))) {
                logger.error("minute " + k + ": the beginner tops out, never falls, or passes his first jump");
                return false;
            }
            if (Climb.poseAt(r, rn, top).lowering || !Climb.poseAt(r, rn, top + 1).lowering) {
                logger.error("minute " + k + ": the lower-off does not start at :" + (top + 1));
                return false;
            }
        }
        return true;
    }

    // On the 416 round screen the shipped wall, its route and the time group stay inside the bezel.
    (:test)
    static function geometryInsideTheBezel(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        var c = g.W / 2;
        var corners = [[g.x0, g.y0], [g.x1, g.y0], [g.x0, g.y1], [g.x1, g.y1], [g.rx0, g.ry0], [g.rx1, g.ry0],
                       [g.rx0, g.ry1], [g.rx1, g.ry1], [g.groupRight - g.digitMaxW, g.H / 2 - 0.10 * g.H]] as Array<Array<Float>>;
        for (var i = 0; i < corners.size(); i++) {
            var dx = corners[i][0] - c;
            var dy = corners[i][1] - c;
            if (dx * dx + dy * dy > c * c) {
                logger.error("point " + i + " (" + corners[i][0] + ", " + corners[i][1] + ") is outside the bezel");
                return false;
            }
        }
        if (!g.timeGroup || g.groupRight >= g.x0) {
            logger.error("the time group is missing or overlaps the wall");
            return false;
        }
        return true;
    }

    static function sameNumbers(a as Array<Number>, b as Array<Number>) as Boolean {
        if (a.size() != b.size()) {
            return false;
        }
        for (var i = 0; i < a.size(); i++) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

}
