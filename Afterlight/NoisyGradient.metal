//
//  NoisyGradient.metal
//  Unfin
//
//  Animated gradient background. When useAura > 0.5, gradient uses the profile aura colors (aura1, aura2, aura3).
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 noisyGradient(
    float2 pos,
    SwiftUI::Layer l,
    float4 bounds,
    float time,
    float useAura,
    half4 aura1,
    half4 aura2,
    half4 aura3
) {
    float2 size = bounds.zw;
    float2 uv = pos / size;

    // Always use the three colors from Swift (default gradient or user aura)
    half3 c1 = aura1.rgb;
    half3 c2 = aura2.rgb;
    half3 c3 = aura3.rgb;

    float t = uv.y + 0.2 * sin(time + uv.x * 3.0);
    float p = uv.x + 0.2 * cos(time + uv.y * 6.0);
    p = clamp(p, 0.0, 1.0);
    t = clamp(t, 0.0, 1.0);

    half3 bottomColor = mix(c1, c2, half(p));
    half3 topColor = mix(c2, c3, half(p));
    half3 color = mix(bottomColor, topColor, half(t));

    return half4(color, 1.0);
}
