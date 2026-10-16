.pragma library

// niri settings that follow the form: a gradient focus ring, and window open/close
// animations that echo the form-change animation (Transformation.qml). The animations are GPU
// shaders that run only for the few hundred milliseconds of each open or close.

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

const common = `
float cf_hash(vec2 v) {
    return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 cf_window(vec3 coords_geo) {
    if (coords_geo.x < 0.0 || coords_geo.x > 1.0 || coords_geo.y < 0.0 || coords_geo.y > 1.0)
        return vec4(0.0);
    return texture2D(niri_tex, (niri_geo_to_tex * coords_geo).st);
}
`;

// Phainon: dawn rises up the window; a gold line of light passes with it. Closing is the sunset.
function dawn(fn, closing) {
    const edge = closing ? "-0.25 + p * 1.5" : "1.25 - p * 1.5";
    return common + `
vec4 ${fn}(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    vec4 color = cf_window(coords_geo);
    float d = coords_geo.y - (${edge});
    float shown = smoothstep(-0.02, 0.12, d);
    float glow = exp(-abs(d) * 18.0) * (1.0 - p) * 0.6 * step(0.0, coords_geo.y) * step(coords_geo.y, 1.0);
    return color * shown + vec4(vec3(0.945, 0.855, 0.31) * glow, glow);
}`;
}

// Khaslana: a ring of molten gold opens from the centre, the window shears into slabs that snap
// back into place. Closing: the slabs scatter and the ring collapses.
function ignition(fn, closing) {
    const k = closing ? "p" : "(1.0 - p)";
    const radius = closing ? "(1.0 - p) * 1.15" : "p * 1.15";
    return common + `
vec4 ${fn}(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    float slab = floor(coords_geo.y * 8.0);
    float shift = (cf_hash(vec2(slab, niri_random_seed)) - 0.5) * 0.09 * ${k} * ${k};
    vec4 color = cf_window(coords_geo + vec3(shift, 0.0, 0.0));
    vec2 d = (coords_geo.xy - 0.5) * size_geo.xy;
    float r = length(d) / (0.5 * length(size_geo.xy));
    float R = ${radius};
    float shown = 1.0 - smoothstep(R - 0.06, R, r);
    float ring = exp(-abs(r - R) * 30.0) * ${k} * step(r, 1.0);
    vec3 gold = mix(vec3(0.831, 0.694, 0.29), vec3(1.0, 0.604, 0.239), r);
    return color * shown + vec4(gold * ring, ring);
}`;
}

// Flame Reaver: the black tide. Blocks arrive left to right, dark at first, then the window shows
// through. Closing: blocks go dark and drop out.
function tide(fn, closing) {
    return common + `
vec4 ${fn}(vec3 coords_geo, vec3 size_geo) {
    float p = niri_clamped_progress;
    vec4 color = cf_window(coords_geo);
    vec2 block = floor(coords_geo.xy * vec2(12.0, 8.0));
    float t = cf_hash(block + niri_random_seed) * 0.55 + clamp(coords_geo.x, 0.0, 1.0) * 0.4;
    float a = clamp((p * 1.1 - t) / 0.15, 0.0, 1.0);
    ${closing ? "a = 1.0 - a;" : ""}
    vec4 charcoal = vec4(0.078, 0.082, 0.09, 1.0) * color.a;
    float lit = ${closing ? "clamp(a * 2.0 - 1.0, 0.0, 1.0)" : "a"};
    return mix(charcoal, color, lit) * step(0.001, a);
}`;
}

const shaders = {
    "phainon": dawn,
    "khaslana": ignition,
    "reaver": tide
};
const durations = {
    "phainon": [340, 260],
    "khaslana": [300, 240],
    "reaver": [280, 220]
};

function animations(form) {
    const make = shaders[form];
    if (!make)
        return "";
    const ms = durations[form];
    return `animations {
    window-open {
        duration-ms ${ms[0]}
        curve "ease-out-cubic"
        custom-shader r"
${make("open_color", false)}
"
    }

    window-close {
        duration-ms ${ms[1]}
        curve "ease-out-quad"
        custom-shader r"
${make("close_color", true)}
"
    }
}`;
}
