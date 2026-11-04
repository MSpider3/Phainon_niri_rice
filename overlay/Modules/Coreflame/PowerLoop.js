.pragma library

// The power menu's loop of n actions. A loop position (off) is unbounded; the chosen action is
// the one at the middle, and each action sits at a place p in [-n/2, n/2) around it.

// Place of x steps from the middle, wrapped round the loop
function wrap(x, n) {
    return ((x + n / 2) % n + n) % n - n / 2;
}

// The action at the middle for loop position off
function index(off, n) {
    return n > 0 ? ((Math.round(off) % n) + n) % n : 0;
}

// Steps to turn action i to the middle, the short way round
function turnTo(i, off, n) {
    return Math.round(wrap(i - off, n));
}

// Places further than this from the middle are past the ends
function edge(n) {
    return Math.floor(n / 2);
}

// How far past the end an action at distance a has gone (it sinks out of sight by this much)
// shortcut: with an even count (no Hibernate) one end action jumps across the seam, fine for six.
function sink(a, n) {
    return Math.max(0, a - edge(n));
}

function fade(a, n) {
    const e = edge(n);
    return a <= e ? 1 : Math.max(0, 1 - (a - e) * 2);
}
