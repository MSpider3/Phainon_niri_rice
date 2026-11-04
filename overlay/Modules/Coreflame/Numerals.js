.pragma library

// Khaslana numbers his acts in Roman; plain digits from 40 on.
function roman(n) {
    if (n >= 40 || n < 1)
        return String(n);
    const r = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
    let out = "";
    let v = n;
    for (const [k, s] of r) {
        while (v >= k) {
            out += s;
            v -= k;
        }
    }
    return out;
}

// The Flame Reaver's two-digit numbers
function two(n) {
    return String(n).padStart(2, "0");
}
