VARY vec3 normal;
VARY vec3 position;
VARY vec3 local;
VARY vec2 uv;
uniform vec4 colDiffuse;
uniform int surface;    // see Surface in platform.odin
uniform float hitFlash;
uniform float fade;     // 0 = solid, 1 = see-through
// The layout of the meadow (see set_ground_layout in game.odin).
uniform vec4 fields[8]; // ploughed fields: x0, z0, x1, z1
uniform int fieldCount;
uniform vec4 paths[6];  // paths from home: x0, z0, x1, z1
uniform int pathCount;
uniform vec4 forest;    // centre x, z and radii of the forest
uniform vec4 hills;     // and of the goat hills

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

// Smooth value noise.
float wash(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}

// An ordered dither pattern, 0..1, repeating every 4 pixels.
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2.0 + a.y * a.y * 0.75);
}
float bayer4(vec2 a) {
    return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// A few flat steps, blended with the dither pattern.
float steps(float t, float count, float dither) {
    return clamp(floor(t * count + dither) / count, 0.0, 1.0);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
    vec2 ab = b - a;
    float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    return length(p - a - ab * t);
}

// How far inside an ellipse, with a ragged edge: 1 inside, 0 outside.
float area(vec2 p, vec4 e, float dither) {
    float d = length((p - e.xy) / e.zw);
    float edge = d + .12 * (wash(p * .21) - .5) + .05 * (wash(p * .9) - .5);
    return step(edge, .97 + .05 * (dither - .5));
}

vec3 meadow(vec2 p, float dither) {
    float broad = wash(p * .18);
    float middle = wash(p * .7 + 3.1);
    float fine = wash(p * vec2(3.1, 4.3));
    float tone = smoothstep(.2, .8, .55 * broad + .3 * middle + .15 * fine);
    tone = steps(tone, 3.0, dither);
    vec3 deep = vec3(.33, .52, .27);
    vec3 base = vec3(.45, .64, .31);
    vec3 sunny = vec3(.62, .75, .37);
    vec3 grass = tone < .5 ? mix(deep, base, tone * 2.0) : mix(base, sunny, tone * 2.0 - 1.0);

    // The forest floor is darker, strewn with brown leaves.
    float wood = area(p, forest, dither);
    vec3 floor_tone = mix(vec3(.25, .38, .21), vec3(.36, .46, .25), tone);
    floor_tone = mix(floor_tone, vec3(.47, .37, .23), step(.74, fine) * step(.4, middle));
    grass = mix(grass, floor_tone, wood);
    // The hills are dry and stony.
    float hill = area(p, hills, dither);
    vec3 dry = mix(vec3(.5, .55, .32), vec3(.66, .66, .42), tone);
    dry = mix(dry, vec3(.6, .58, .54), step(.7, wash(p * 1.7)) * .8);
    grass = mix(grass, dry, hill);

    // Footpaths wind out from home to each part of the meadow, from a bare
    // yard round the house.
    vec2 w = p + vec2(1.6 * sin(p.y * .17) + .6 * sin(p.y * .41), 1.4 * sin(p.x * .15) + .5 * sin(p.x * .37));
    float d = length(p) - 4.5;
    for (int i = 0; i < 6; i++) {
        if (i >= pathCount) break;
        d = min(d, segment_distance(w, paths[i].xy, paths[i].zw));
    }
    float verge = d + .72 * (wash(p * 1.3) - .5) + .25 * (fine - .5);
    float path = step(.35 + .3 * dither, 1.0 - smoothstep(.41, 1.28, verge));
    vec3 earth = mix(vec3(.66, .58, .42), vec3(.86, .77, .56), steps(.62 * broad + .38 * fine, 2.0, dither));
    vec3 ground = mix(grass, earth, path);

    // Ploughed fields, in rows.
    for (int i = 0; i < 8; i++) {
        if (i >= fieldCount) break;
        vec4 f = fields[i];
        vec2 ragged = vec2(.25 * (wash(p * 2.1) - .5));
        if (all(greaterThan(p + ragged, f.xy)) && all(lessThan(p + ragged, f.zw))) {
            float furrow = step(.5, fract(p.y * 1.3 + .15 * sin(p.x * .7)));
            vec3 soil = mix(vec3(.42, .3, .2), vec3(.53, .39, .26), furrow);
            ground = mix(soil, vec3(.36, .26, .18), step(.82, fine) * .6);
        }
    }
    // Warm sunlight falls in broad soft patches, as through gaps in leaves.
    float sun = smoothstep(.55, .8, wash(p * .09 + 7.3) * .7 + wash(p * .23) * .3);
    ground *= mix(vec3(.94, .96, 1.0), vec3(1.1, 1.05, .9), steps(sun, 2.0, dither));
    return ground;
}

void main() {
    float dither = bayer4(gl_FragCoord.xy);
    if (fade > 0.0 && bayer4(gl_FragCoord.xy) < fade) {
        discard;
    }
    if (surface == 1) {
        OUT_COLOR = vec4(meadow(position.xz, dither), 1.0);
        return;
    }
    if (surface == 3) {
        // A shadow, flattened on the ground: drawn flat into the shadow image.
        OUT_COLOR = vec4(colDiffuse.rgb, 1.0);
        return;
    }

    vec3 n = normalize(normal);
    vec3 sun = normalize(vec3(-.62, .89, .43)); // must match SUN in platform.odin
    float light = dot(n, sun);
    vec3 pigment = colDiffuse.rgb;

    if (surface == 2) {
        // Leaves: clumps of lighter and darker foliage.
        vec2 p = position.xz * 1.9 + position.y * vec2(1.3, -0.9);
        float clump = wash(p) * .65 + wash(p * 2.7) * .35;
        pigment *= .78 + .42 * steps(clump, 3.0, dither);
        // Each leafy lump is darker underneath, so crowns look round and deep.
        pigment *= mix(.72, 1.06, steps(smoothstep(-.8, .7, local.y), 3.0, dither));
    }
    if (surface == 4) {
        // Bark: long vertical grain.
        float grain = wash(vec2(atan(local.x, local.z) * 3.0, local.y * 9.0));
        pigment *= .82 + .3 * steps(grain, 2.0, dither);
    }
    if (surface == 5) {
        // Stone with patches of moss on top.
        vec2 p = local.xz + local.y * vec2(.39, .71);
        float mineral = wash(6.0 * p) + .34 * wash(19.0 * p);
        light += .2 * (mineral - .65);
        float moss = smoothstep(.59, .74, mineral * .64 + .42 * n.y);
        pigment = mix(pigment, vec3(.47, .55, .32), steps(moss, 2.0, dither) * .81);
        pigment *= .90 + .16 * mineral;
    }
    if (surface == 6) {
        // Bias-cut lapel crossing the curved jacket.
        float seam = local.x + .68 * local.y - .24;
        float front = smoothstep(.15, .4, local.z);
        float lapel = (1.0 - smoothstep(.09, .115, abs(seam))) * front;
        pigment = mix(pigment, vec3(.46, .33, .24), lapel * .91);
    }

    vec3 bounce = vec3(.03, .04, .025) * (1.0 - smoothstep(-.6, .35, n.y));
    // Four flat tones from a warm low sun: deep shade, shade, light and a
    // sunlit highlight. The edges between them are dithered, like hand-made
    // pixel art. Shadows are cool, light is warm, and skylight tints
    // anything facing up.
    float lit = light + (dither - .5) * .12;
    vec3 tint = vec3(.46, .5, .72);
    tint = mix(tint, vec3(.64, .67, .84), step(-.4, lit));
    tint = mix(tint, vec3(.97, .93, .84), step(.02, lit));
    tint = mix(tint, vec3(1.13, 1.05, .86), step(.58, lit));
    vec3 sky = vec3(.03, .05, .09) * max(n.y, 0.0);
    // Darker where things meet the ground.
    float contact = mix(.8, 1.0, steps(smoothstep(.0, .5, position.y), 2.0, dither));
    vec3 color = pigment * tint * contact + bounce + sky;
    color = floor(color * 14.0 + .5) / 14.0;
    OUT_COLOR = vec4(mix(color, vec3(1.0, .89, .68), hitFlash), colDiffuse.a);
}
