using Toybox.Test;

import Toybox.Lang;

// The face's arithmetic against the simulator (ClimbGolden), and the rules of DESIGN.md
// §8.3, §10, §11.3, §12 and §6.3 that the golden values do not spell out.
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

    // Grade, proficiency, colour, moves, levels, jumps and every hold, route by route.
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
                    logger.error("minute +" + at + ": field " + f + " = " + got[f] + ", simulator " + (want[f + 1] as Number));
                    return false;
                }
            }
            var dynos = want[6] as Array<Number>;
            if (r.dynoList.size() != dynos.size()) {
                logger.error("minute +" + at + ": " + r.dynoList.size() + " jumps, simulator " + dynos.size());
                return false;
            }
            for (var d = 0; d < dynos.size(); d++) {
                if (r.dynoList[d] != dynos[d]) {
                    logger.error("minute +" + at + ": jump " + d + " at move " + r.dynoList[d] + ", simulator " + dynos[d]);
                    return false;
                }
            }
            var xy = ClimbGolden.HOLDS[i];
            for (var k = -4; k <= r.lmax; k++) {
                var h = r.hold(k);
                var j = 2 * (k + 4);
                if (!ClimbGolden.near(h.x, xy[j]) || !ClimbGolden.near(h.y, xy[j + 1])) {
                    logger.error("minute +" + at + " hold " + k + ": (" + h.x + ", " + h.y + "), simulator (" + xy[j] + ", " + xy[j + 1] + ")");
                    return false;
                }
            }
        }
        return true;
    }

    // 4B 4I 4E 5B ... 8E, one minute each, from 4B at every hour (DESIGN.md §8.3, §12.4).
    (:test)
    static function gradesCycleEveryFifteenMinutes(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        for (var k = 0; k < 60; k += 7) {
            var r = new Route(ClimbGolden.BASE + k, g);
            if (r.grade != 4 + (k / 3) % 5 || r.prof != k % 3) {
                logger.error("minute " + k + ": " + r.grade + "/" + r.prof);
                return false;
            }
        }
        return true;
    }

    // The three climbs of a grade share holds and colour; the next grade does not (§6.3, §7).
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
        return b.colorIdx == e.colorIdx && n.colorIdx != e.colorIdx;
    }

    // The plan covers the climb up to :56; the expert tops out, the beginner never does
    // (§11.3, §12); the last 3 s are the lower-off.
    (:test)
    static function plansAndLowerOff(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        var top = 59 - Climb.LOWER;
        for (var k = 0; k < 15; k++) {
            var r = new Route(ClimbGolden.BASE + k, g);
            var rn = new Route(ClimbGolden.BASE + k + 1, g);
            var pl = r.plan(top);
            if (r.prof == 2 && (pl.falls != 0 || pl.endM < r.m - 0.001)) {
                logger.error("minute " + k + ": the expert falls or stops short");
                return false;
            }
            if (r.prof == 0 && pl.endM >= r.m - 0.001) {
                logger.error("minute " + k + ": the beginner tops out");
                return false;
            }
            if (Climb.poseAt(r, rn, top).lowering || !Climb.poseAt(r, rn, top + 1).lowering) {
                logger.error("minute " + k + ": the lower-off does not start at :" + (top + 1));
                return false;
            }
        }
        return true;
    }

    // On the 416 screen the panel, the route and the time group stay on the screen.
    (:test)
    static function geometryOnTheScreen(logger as Test.Logger) as Boolean {
        var g = ClimbGolden.geom();
        return g.timeGroup && g.x0 > g.groupRight && g.x1 < g.W && g.rx0 > g.x0 && g.rx1 < g.x1
            && g.ry0 > g.y0 && g.ry1 < g.y1 && g.digitMaxW > 0;
    }

}
