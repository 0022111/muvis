#include <metal_stdlib>
using namespace metal;

// MARK: - Shared types (lane maps mirrored in Renderer.swift)

struct Uniforms {
    float4x4 viewProj;
    float4 audio;   // x bass, y drum, z vocal, w pace
    float4 pulse;   // x boundary pulse, y hype, z hue, w wall time
    float4 morph;   // x shape from, y shape to, z mix, w spin angle
    float4 params;  // x dt, y point scale, z energy, w aspect
    float4 post;    // x kaleido segments, y trail decay, z feedback zoom, w feedback twist
    float4 post2;   // x exposure, y vignette, z aberration, w brightness scale
    float4 rhythm;  // x beat pulse, y bar pulse, z beat phase, w bpm norm
    float4 energy;  // x loudness, y punch, z phrase pulse, w EDR headroom
    float4 extra;   // x shape scale, y shape hue offset, z shape brightness, w minor-key flag
};

struct Particle {
    float4 posLife; // xyz position, w life
    float4 velSeed; // xyz velocity, w home seed
};

constant uint kShapeVertices = 2048;
constant float TAU = 6.28318530718;

// MARK: - Noise

static float hash13(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

static float vnoise(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i);
    float n100 = hash13(i + float3(1, 0, 0));
    float n010 = hash13(i + float3(0, 1, 0));
    float n110 = hash13(i + float3(1, 1, 0));
    float n001 = hash13(i + float3(0, 0, 1));
    float n101 = hash13(i + float3(1, 0, 1));
    float n011 = hash13(i + float3(0, 1, 1));
    float n111 = hash13(i + float3(1, 1, 1));
    float2 nx0 = mix(float2(n000, n001), float2(n100, n101), f.x);
    float2 nx1 = mix(float2(n010, n011), float2(n110, n111), f.x);
    float2 nxy = mix(nx0, nx1, f.y);
    return mix(nxy.x, nxy.y, f.z);
}

/// Divergence-free flow field: the cross product of two noise gradients.
static float3 flow(float3 p, float t) {
    float3 q = p + float3(0.0, t * 0.06, 0.0);
    const float e = 0.25;
    const float3 dx = float3(e, 0, 0), dy = float3(0, e, 0), dz = float3(0, 0, e);
    float a0 = vnoise(q);
    float3 ga = float3(vnoise(q + dx) - a0, vnoise(q + dy) - a0, vnoise(q + dz) - a0);
    float3 r = q + 7.31;
    float b0 = vnoise(r);
    float3 gb = float3(vnoise(r + dx) - b0, vnoise(r + dy) - b0, vnoise(r + dz) - b0);
    return cross(ga, gb) * (1.0 / (e * e));
}

static float3 hsv2rgb(float3 c) {
    float3 p = abs(fract(c.xxx + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// MARK: - Hero shape
// A 1D parameter t in [0, 1) sweeps a closed-ish space curve; sections pick the curve.

static float3 shapePoint(float t, float id, float time) {
    float a = t * TAU;
    switch (int(round(id))) {
    case 1: { // torus knot (2,5) — drops
        float r = 2.0 + cos(5.0 * a);
        return float3(r * cos(2.0 * a), sin(5.0 * a) * 1.2, r * sin(2.0 * a)) * 0.52;
    }
    case 2: { // bloom — breakdowns
        float r = 0.55 + 0.85 * pow(abs(cos(3.5 * a)), 0.6);
        return float3(r * cos(a), 0.55 * sin(7.0 * a), r * sin(a)) * 1.05;
    }
    case 3: { // lissajous knot — buildups
        return float3(sin(3.0 * a + time * 0.13), sin(4.0 * a), sin(5.0 * a + 1.7)) * 1.3;
    }
    case 4: { // double helix — verses
        float side = step(0.5, t);
        float s = fract(t * 2.0);
        float ang = s * 4.0 * TAU + side * 3.14159265 + time * 0.22;
        return float3(cos(ang) * 0.85, (s - 0.5) * 3.1, sin(ang) * 0.85);
    }
    case 5: { // torus knot (3,4) — bridges
        float r = 2.0 + cos(4.0 * a);
        return float3(r * cos(3.0 * a), sin(4.0 * a) * 1.2, r * sin(3.0 * a)) * 0.48;
    }
    default: { // spiral sphere — intros and outros
        float th = acos(clamp(1.0 - 2.0 * t, -1.0, 1.0));
        float ph = a * 16.0 + time * 0.1;
        return float3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * 1.45;
    }
    }
}

static float3 heroPoint(float t, constant Uniforms& u) {
    float time = u.pulse.w;
    float m = smoothstep(0.0, 1.0, u.morph.z);
    float3 p = mix(shapePoint(t, u.morph.x, time), shapePoint(t, u.morph.y, time), m);
    p *= 1.0 + 0.05 * sin(time * 0.8 + t * TAU * 3.0);  // slow breathing
    p *= 1.0 + u.audio.x * 0.22 + u.pulse.x * 0.35      // bass swell, boundary kick
             + u.rhythm.x * 0.05 + u.energy.z * 0.12;   // beat tick, phrase shimmer
    return p;
}

// MARK: - Particle simulation

kernel void simulate(device Particle* particles [[buffer(0)]],
                     constant Uniforms& u [[buffer(1)]],
                     uint id [[thread_position_in_grid]])
{
    Particle p = particles[id];
    float dt = min(u.params.x, 0.05);
    float t = u.pulse.w;
    float bass = u.audio.x, drum = u.audio.y, vocal = u.audio.z, pace = u.audio.w;
    float boom = u.pulse.x;

    float3 pos = p.posLife.xyz;
    float life = p.posLife.w;
    float3 vel = p.velSeed.xyz;
    float seed = p.velSeed.w;

    // Spring toward a home point on the hero curve; turbulence pulls away.
    float3 home = heroPoint(fract(seed), u);
    vel += (home - pos) * (2.6 + vocal * 4.0) * dt;
    vel += flow(pos * (0.55 + pace * 0.5), t)
         * (0.6 + bass * 2.4 + drum * 1.4) * (0.5 + u.energy.x * 0.8) * u.params.z * dt;

    // Drum hits shove radially; section boundaries detonate; bars swirl.
    float3 radial = normalize(pos + float3(1e-4, 2e-4, 3e-4));
    vel += radial * (drum * drum * 2.4 + boom * 6.0) * dt;
    float3 tangent = normalize(cross(radial, float3(0.0, 1.0, 0.0)) + float3(0.0, 1e-4, 0.0));
    vel += tangent * u.rhythm.y * 3.0 * dt;

    vel *= exp(-dt * 2.6);
    pos += vel * dt;

    life -= dt * (0.14 + drum * 0.22 + boom * 0.5);
    if (life <= 0.0) {
        float fresh = hash13(float3(seed * 113.7, t, fract(seed * 71.3) + 0.1));
        seed = fresh;
        pos = heroPoint(fresh, u);
        vel = flow(pos, t) * 0.5;
        life = 0.55 + 0.45 * hash13(float3(fresh * 91.3, t * 1.7, 5.1));
    }

    particles[id].posLife = float4(pos, life);
    particles[id].velSeed = float4(vel, seed);
}

// MARK: - Scene render (into the HDR trail buffer, additive)

struct GlowVertex {
    float4 position [[position]];
    float size [[point_size]];
    half4 color;
};

vertex GlowVertex shapeVert(uint vid [[vertex_id]],
                            constant Uniforms& u [[buffer(1)]])
{
    float t = float(vid) / float(kShapeVertices - 1);
    GlowVertex o;
    o.position = u.viewProj * float4(heroPoint(t, u) * u.extra.x, 1.0);
    o.size = 1.0;
    float hue = u.pulse.z + u.extra.y + t * 0.10;
    float sat = 0.62 + u.extra.w * 0.12;  // minor keys read moodier
    float bright = (0.10 + u.audio.y * 0.14 + u.pulse.x * 0.20 + u.rhythm.x * 0.12)
                 * (0.35 + u.energy.x * 0.9) * u.extra.z * u.post2.w;
    o.color = half4(half3(hsv2rgb(float3(hue, sat, 1.0)) * bright), 1.0h);
    return o;
}

fragment half4 lineFrag(GlowVertex in [[stage_in]]) {
    return in.color;
}

vertex GlowVertex particleVert(uint vid [[vertex_id]],
                               device const Particle* particles [[buffer(0)]],
                               constant Uniforms& u [[buffer(1)]])
{
    Particle p = particles[vid];
    float4 clip = u.viewProj * float4(p.posLife.xyz, 1.0);
    float speed = length(p.velSeed.xyz);
    float fade = smoothstep(0.0, 0.18, p.posLife.w);
    GlowVertex o;
    o.position = clip;
    o.size = clamp(u.params.y * (2.2 + speed * 1.6 + u.audio.y * 3.0)
                   * (1.0 + u.rhythm.x * 0.3) / max(clip.w, 0.25), 1.0, 28.0);
    float hue = u.pulse.z + fract(p.velSeed.w * 7.0) * 0.14 + speed * 0.04;
    float sat = clamp(0.85 - u.audio.x * 0.25 - speed * 0.06 + u.extra.w * 0.08, 0.2, 1.0);
    float bright = (0.20 + speed * 0.40 + u.audio.y * 0.45)
                 * (0.30 + u.energy.x * 0.9) * fade * u.post2.w;
    o.color = half4(half3(hsv2rgb(float3(hue, sat, 1.0)) * bright), 1.0h);
    return o;
}

fragment half4 particleFrag(GlowVertex in [[stage_in]],
                            float2 pc [[point_coord]])
{
    float d = length(pc - 0.5) * 2.0;
    float a = exp(-d * d * 5.0) * smoothstep(1.0, 0.7, d);
    return in.color * half(a);
}

// MARK: - Fullscreen passes

struct ScreenVertex {
    float4 position [[position]];
    float2 uv;
};

vertex ScreenVertex screenVert(uint vid [[vertex_id]]) {
    float2 v = float2((vid << 1) & 2, vid & 2);
    ScreenVertex o;
    o.position = float4(v * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(v.x, 1.0 - v.y);
    return o;
}

/// Trail feedback: resample last frame's accumulation with a slight zoom and
/// twist, decayed — everything drawn after this pass leaves luminous wakes.
fragment half4 feedbackFrag(ScreenVertex in [[stage_in]],
                            texture2d<half> history [[texture(0)]],
                            constant Uniforms& u [[buffer(1)]])
{
    constexpr sampler smp(address::clamp_to_edge, filter::linear);
    float2 c = in.uv - 0.5;
    c.x *= u.params.w;
    float tw = u.post.w;
    c = float2x2(cos(tw), -sin(tw), sin(tw), cos(tw)) * c;
    c *= u.post.z;
    c.x /= u.params.w;
    half4 h = history.sample(smp, c + 0.5);
    h *= half(u.post.y);
    h = max(h - half4(0.0015h), half4(0.0h));  // floor cut so ghosts fully die
    return half4(h.rgb, 1.0h);
}

/// Tiny fixed-weight CPPN (sin-activated network) — an organic aurora field
/// evaluated per pixel, breathing behind the scene.
static float3 cppn(float2 p, float t, float hue) {
    float4 x = float4(p, length(p), t);
    float4 h1 = sin(float4(dot(x, float4( 1.7, -2.3,  1.1, 0.9)),
                           dot(x, float4(-2.1,  1.4,  2.6, 0.7)),
                           dot(x, float4( 0.8,  2.2, -1.9, 1.1)),
                           dot(x, float4( 2.9, -0.6, -1.2, 0.5))));
    float4 h2 = sin(float4(dot(h1, float4( 1.3, -2.2,  1.9, -0.8)) + 1.0,
                           dot(h1, float4(-1.7,  1.1,  0.6,  2.3)) + 2.0,
                           dot(h1, float4( 2.4,  0.9, -1.4,  1.2)) + 3.0,
                           dot(h1, float4(-0.5, -1.8,  2.2, -1.6)) + 4.0));
    float v = dot(h2, float4(0.25));
    return hsv2rgb(float3(hue + 0.45 + v * 0.10, 0.7, 0.5 + 0.5 * v));
}

/// Composite: kaleidoscope, chromatic aberration, glow taps, CPPN background,
/// filmic-ish tonemap, vignette.
fragment half4 postFrag(ScreenVertex in [[stage_in]],
                        texture2d<half> accum [[texture(0)]],
                        constant Uniforms& u [[buffer(1)]])
{
    constexpr sampler smp(address::clamp_to_edge, filter::linear);
    float2 c = in.uv - 0.5;
    c.x *= u.params.w;

    float segments = u.post.x;
    if (segments >= 2.0) {
        float r = length(c);
        float ang = atan2(c.y, c.x) + u.morph.w * 0.15;
        float seg = TAU / segments;
        ang = fmod(fmod(ang, seg) + seg, seg);
        ang = abs(ang - seg * 0.5);
        c = r * float2(cos(ang), sin(ang));
    }

    float2 suv = float2(c.x / u.params.w, c.y) + 0.5;
    float2 dir = suv - 0.5;
    float ab = u.post2.z * (0.0015 + u.audio.x * 0.004 + u.energy.y * 0.010);
    float3 col;
    col.r = float(accum.sample(smp, suv + dir * ab).r);
    col.g = float(accum.sample(smp, suv).g);
    col.b = float(accum.sample(smp, suv - dir * ab).b);

    const float g = 0.006;
    float3 glow = float3(0.0);
    glow += float3(accum.sample(smp, suv + float2(g, 0.0)).rgb);
    glow += float3(accum.sample(smp, suv - float2(g, 0.0)).rgb);
    glow += float3(accum.sample(smp, suv + float2(0.0, g)).rgb);
    glow += float3(accum.sample(smp, suv - float2(0.0, g)).rgb);
    col += glow * 0.16;

    col += cppn(c * 2.3, u.pulse.w * 0.05, u.pulse.z + u.extra.w * 0.07)
         * (0.03 + u.audio.x * 0.04 + u.pulse.x * 0.08) * (0.4 + u.energy.x);

    // Tonemap to an SDR look, linearize for the extended-linear colorspace,
    // then push the hottest highlights into the display's EDR headroom.
    float3 sdr = 1.0 - exp(-col * u.post2.x);
    sdr *= max(1.0 - u.post2.y * dot(c, c) * 1.5, 0.0);
    float3 lin = pow(sdr, float3(2.2));
    float hot = smoothstep(0.55, 1.0, max3(sdr.r, sdr.g, sdr.b));
    lin *= mix(1.0, u.energy.w, hot * hot);
    return half4(half3(lin), 1.0h);
}
