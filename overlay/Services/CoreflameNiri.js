.pragma library

// niri settings for Coreflame: a gradient focus ring per form, and the window open/close
// animation (the same for every form). The animation is a GPU shader that runs only while a
// window opens or closes.

const focusRing = {
    "phainon": `    focus-ring {
        width 2
        active-gradient from="#F1DA4F" to="#334786" angle=135
        inactive-color "#6F7FB533"
    }`,
    "khaslana": `    focus-ring {
        width 2.5
        active-gradient from="#D4B14A" to="#E5544C" angle=45
        inactive-color "#94713822"
    }`,
    "reaver": `    focus-ring {
        width 1.5
        active-gradient from="#31363B" to="#7A6AA8" angle=90
        inactive-color "#14151700"
    }`
};

// The Black Tide eclipse (report §9): one effect for every form, played the same on open and close.
// A red ball forms, indigo corruption and flickering cubes spread, two tilted rings sweep, the ball
// collapses to a crosshair point and bursts; the window appears (open) or vanishes (close) under the
// flash, then red speed lines, scattered cubes and embers fade. Times below are fractions of `ms`.
const ms = 650;

const common = `
float cf_hash(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 cf_window(vec2 g) {
    if (g.x < 0.0 || g.x > 1.0 || g.y < 0.0 || g.y > 1.0)
        return vec4(0.0);
    return texture2D(niri_tex, (niri_geo_to_tex * vec3(g, 1.0)).st);
}

// Premultiplied alpha: paint over, and add light.
vec4 cf_over(vec4 dst, vec3 rgb, float a) {
    return vec4(rgb * a, a) + dst * (1.0 - a);
}

vec4 cf_add(vec4 dst, vec3 rgb, float a) {
    return vec4(dst.rgb + rgb * a, min(1.0, dst.a + a));
}

// A thin tilted ring around the ball, drawn as a squashed ellipse; a bright head sweeps round it
// and the back half is hidden behind the ball.
float cf_tilted(vec2 uv, float r, float ball, float radius, float tilt, float squash, float head) {
    float cs = cos(tilt);
    float sn = sin(tilt);
    vec2 q = vec2(cs * uv.x + sn * uv.y, cs * uv.y - sn * uv.x);
    vec2 e = vec2(q.x, q.y / squash);
    float le = length(e);
    float d = abs(le - radius) * le / max(length(vec2(e.x, e.y / squash)), 0.0001);
    float tail = fract((head - atan(e.y, e.x)) / 6.2832);
    float behind = step(r, ball) * step(q.y, 0.0);
    return exp(-d / 0.005) * (0.3 + 0.7 * exp(-tail * 4.0)) * (1.0 - behind);
}
`;

function eclipse(fn, closing) {
    const shown = closing ? "1.0 - swap" : "swap";
    return common + `
vec4 ${fn}(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    float S = min(size_geo.x, size_geo.y);
    vec2 px = (coords_geo.xy - 0.5) * size_geo.xy;
    vec2 uv = px / S;
    vec2 beyond = abs(px) - 0.5 * size_geo.xy;
    float out_d = max(beyond.x, beyond.y) / S;
    if (out_d > 0.22)
        return vec4(0.0);
    float inside = step(out_d, 0.0);
    float edge = 1.0 - smoothstep(0.0, 0.22, out_d);
    float r = length(uv);
    float seed = niri_random_seed * 97.0;
    float frame = floor(p * 18.0);

    float born = smoothstep(0.0, 0.14, p);
    float grow = smoothstep(0.14, 0.40, p);
    float swell = smoothstep(0.40, 0.58, p);
    float collapse = smoothstep(0.58, 0.63, p);
    float R = max(mix(0.075 * born + 0.105 * grow + 0.27 * swell, 0.012, collapse), 0.001);
    float ballOn = 1.0 - smoothstep(0.62, 0.645, p);
    float burst = smoothstep(0.62, 0.665, p) * (1.0 - smoothstep(0.68, 0.82, p));
    float swap = smoothstep(0.645, 0.68, p);
    float after = step(0.64, p);
    float fade = clamp((p - 0.64) / 0.36, 0.0, 1.0);
    float heat = swell * (1.0 - collapse);

    vec3 red0 = vec3(0.596, 0.141, 0.208);
    vec3 red1 = vec3(0.827, 0.314, 0.361);
    vec3 hot = vec3(1.0, 0.93, 0.93);
    vec3 pinkWhite = vec3(1.0, 0.84, 0.92);

    // Corruption: indigo shards seeping out of the ball; the window glitches in blocks under it.
    float corrupt = grow * (1.0 - smoothstep(0.6, 0.68, p));
    float reach = R + 0.9 * grow + 0.2 * swell;
    vec2 cell = floor(uv * 16.0);
    float n = cf_hash(cell + seed);
    float n2 = cf_hash(vec2(floor((atan(uv.y, uv.x) + 3.1416) * 12.0), seed));
    float density = corrupt * (1.0 - smoothstep(reach * 0.55, reach, r)) * (0.45 + 0.35 * n + 0.2 * n2);
    vec3 indigo = mix(mix(vec3(0.149, 0.102, 0.22), vec3(0.224, 0.145, 0.333), n), vec3(0.302, 0.231, 0.443), n2 * 0.6);

    vec2 jitter = (vec2(cf_hash(cell + frame), cf_hash(cell - frame)) - 0.5) * 0.04 * corrupt * step(0.7, n);
    vec4 c = cf_window(coords_geo.xy + jitter) * (${shown});
    c = cf_over(c, indigo, density * inside * 0.85);

    // Cubes: a flickering grid in the corruption; after the burst a few fly outward.
    vec2 g = uv * 14.0 / (1.0 + 1.6 * fade);
    vec2 gf = fract(g) - 0.5;
    vec2 gc = floor(g);
    float h = cf_hash(gc + seed * 1.7);
    float hs = 0.14 + 0.16 * h;
    float m = max(abs(gf.x), abs(gf.y));
    float flick = step(0.62, cf_hash(gc + frame + seed));
    float zone = max(corrupt * step(R, r) * (1.0 - smoothstep(reach * 0.5, reach, r)), step(0.85, h) * (1.0 - fade) * after);
    float cube = step(m, hs) * flick * zone * edge;
    c = cf_over(c, mix(vec3(0.03, 0.02, 0.05), vec3(0.302, 0.231, 0.443), step(hs - 0.04, m)), cube * 0.95);

    // The ball: soft red glow, black core, thin red ring whose rim turns white-hot.
    float glow = exp(-max(r - R, 0.0) / 0.07) * 0.55 * ballOn * born;
    c = cf_add(c, mix(red0, red1, glow), glow * edge);
    float core = (1.0 - smoothstep(R - 0.004, R, r)) * ballOn;
    c = cf_over(c, mix(vec3(0.02, 0.0, 0.01), vec3(0.22, 0.02, 0.05), pow(min(r / R, 1.0), 3.0)), core);
    float ring = exp(-abs(r - R) / (0.006 + 0.004 * swell)) * ballOn * born;
    c = cf_add(c, mix(mix(red0, red1, ring), hot, heat * ring), ring);

    // Two tilted rings sweep around the ball as it swells.
    float rings = smoothstep(0.38, 0.44, p) * (1.0 - smoothstep(0.58, 0.62, p));
    float head = (p - 0.38) / 0.22 * 7.5;
    float tilted = cf_tilted(uv, r, R, 1.3 * R, -0.22, 0.22, head) + cf_tilted(uv, r, R, 1.5 * R, 0.12, 0.32, head + 3.1416);
    c = cf_add(c, mix(red1, hot, heat * 0.6), tilted * rings * edge);

    // Collapse: a pink-white point with a crosshair and a magenta smear.
    float xhair = smoothstep(0.56, 0.6, p) * (1.0 - smoothstep(0.64, 0.7, p));
    float lines = exp(-abs(uv.y) / 0.0025) * exp(-abs(uv.x) / 0.35) + exp(-abs(uv.x) / 0.0025) * exp(-abs(uv.y) / 0.35);
    float spot = exp(-r / 0.02) + exp(-abs(r - 0.06) / 0.004);
    c = cf_add(c, pinkWhite, (spot + lines) * xhair * edge);
    c = cf_add(c, vec3(0.85, 0.3, 0.75), exp(-abs(uv.y) / 0.05) * exp(-abs(uv.x) / 0.3) * 0.5 * xhair * inside);

    // Burst: white-pink flash over the whole window; the window swaps underneath it.
    vec3 flash = mix(vec3(1.0, 0.97, 0.97), vec3(1.0, 0.45, 0.6), clamp(smoothstep(0.25, 1.1, r + 0.25 * n2) + 0.6 * smoothstep(0.68, 0.8, p), 0.0, 1.0));
    c = cf_over(c, flash, min(burst * 1.1, 1.0) * inside);
    c = cf_add(c, flash, burst * edge * 0.6 * (1.0 - inside));

    // Fade: red haze over the window, speed lines past its edges, embers.
    c = cf_over(c, mix(vec3(0.3, 0.23, 0.44), vec3(0.45, 0.04, 0.1), smoothstep(0.0, 0.3, r)), (1.0 - fade) * after * 0.45 * exp(-r * 1.5) * inside);
    float slot = (atan(uv.y, uv.x) / 6.2832 + 0.5) * 70.0;
    float hl = cf_hash(vec2(floor(slot), seed));
    float w = 0.04 + 0.08 * hl;
    float tip = 0.15 + fade * (1.1 + 0.6 * hl);
    float seg = smoothstep(tip - 0.2 - 0.35 * hl, tip, r) * step(r, tip);
    float streak = (1.0 - smoothstep(w * 0.5, w, abs(fract(slot) - 0.5))) * seg * step(0.45, hl) * (1.0 - fade) * after * edge;
    c = cf_add(c, mix(vec3(0.85, 0.12, 0.2), pinkWhite, pow(seg, 12.0)), streak);
    vec2 eg = uv * 22.0 / (1.0 + 0.8 * fade);
    vec2 ec = floor(eg);
    vec2 ej = vec2(cf_hash(ec + 1.3), cf_hash(ec + 7.1)) - 0.5;
    float ember = step(0.86, cf_hash(ec + seed * 3.1)) * exp(-length(fract(eg) - 0.5 - ej * 0.6) / 0.06) * (0.6 + 0.4 * cf_hash(ec + frame)) * (1.0 - fade) * step(0.66, p) * edge;
    c = cf_add(c, vec3(1.0, 0.35, 0.25), ember);

    return clamp(c, 0.0, 1.0);
}`;
}

// The "still" fallback (Power Saver): a plain fade.
function fade(fn, closing) {
    return `
vec4 ${fn}(vec3 coords_geo, vec3 size_geo) {
    vec3 t = niri_geo_to_tex * coords_geo;
    vec4 color = texture2D(niri_tex, t.st);
    return color * (${closing ? "1.0 - " : ""}niri_clamped_progress);
}`;
}

function animations(still) {
    const make = still ? fade : eclipse;
    const len = still ? 150 : ms;
    return `animations {
    window-open {
        duration-ms ${len}
        curve "linear"
        custom-shader r"
${make("open_color", false)}
"
    }

    window-close {
        duration-ms ${len}
        curve "linear"
        custom-shader r"
${make("close_color", true)}
"
    }
}`;
}
