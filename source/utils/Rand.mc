import Toybox.Lang;

// 32-bit hash and mulberry32, as in the simulator (DESIGN.md, Appendix B.1). Monkey C's
// Number is a signed 32-bit int; products go through Long and are truncated to the
// low 32 bits, which is what Math.imul and `n|0` do in the simulator (DESIGN.md §15.3).
module Rand {

    // The low 32 bits of n, as a signed Number.
    function trunc32(n as Long) as Number {
        var v = n & 0xFFFFFFFFl;
        if (v >= 0x80000000l) {
            v -= 0x100000000l;
        }
        return v.toNumber();
    }

    function imul(a as Number, b as Number) as Number {
        return trunc32(a.toLong() * b.toLong());
    }

    // x >>> n for 0 < n < 32: an arithmetic shift with the sign bits masked off.
    function ushr(x as Number, n as Number) as Number {
        return (x >> n) & ((1 << (32 - n)) - 1);
    }

    // Unsigned 32-bit result, as a Long.
    function hash(n as Long) as Long {
        var x = trunc32(n);
        x = imul(x ^ ushr(x, 16), 0x45d9f3b);
        x = imul(x ^ ushr(x, 16), 0x45d9f3b);
        return (x ^ ushr(x, 16)).toLong() & 0xFFFFFFFFl;
    }

    function hashMod(n as Long, m as Number) as Number {
        return (hash(n) % m.toLong()).toNumber();
    }

}

class Mulberry {

    private var _a as Number;

    function initialize(seed as Long) {
        _a = Rand.trunc32(seed);
    }

    // In [0, 1).
    function next() as Float {
        _a = Rand.trunc32(_a.toLong() + 0x6D2B79F5l);
        var a = _a;
        var t = Rand.imul(a ^ Rand.ushr(a, 15), 1 | a);
        t = Rand.trunc32(t.toLong() + Rand.imul(t ^ Rand.ushr(t, 7), 61 | t).toLong()) ^ t;
        var u = (t ^ Rand.ushr(t, 14)).toLong() & 0xFFFFFFFFl;
        var r = (u.toDouble() / 4294967296.0d).toFloat();
        return r < 1.0 ? r : 0.99999994;
    }

}
