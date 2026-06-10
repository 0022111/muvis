#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Radial kaleidoscope with a bass-driven ripple. segments < 2 disables mirroring.
[[ stitchable ]] half4 kaleido(float2 position, SwiftUI::Layer layer,
                               float2 size, float segments, float warp, float time) {
    float2 center = size * 0.5;
    float2 d = position - center;
    float r = length(d);
    float a = atan2(d.y, d.x);

    if (segments >= 2.0) {
        float seg = 6.2831853 / segments;
        a = fmod(fmod(a, seg) + seg, seg);
        a = abs(a - seg * 0.5);
    }

    r += warp * 22.0 * sin(r * 0.045 - time * 4.0);

    float2 p = center + r * float2(cos(a), sin(a));
    p = clamp(p, float2(1.0), size - 1.0);
    return layer.sample(p);
}
