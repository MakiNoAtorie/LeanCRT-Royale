// GPL-2.0-or-later. Derived from CRT Royale by TroggleMonkey and Alex Gunter.
// Copyright (C) 2014 TroggleMonkey; Copyright (C) 2020 Alex Gunter.
// Retain the reference's intermediate UNORM16 clipping and rounding at fusions.
float4 leanUNorm16(float4 value) { return round(saturate(value) * 65535.0) / 65535.0; }
// Float to UNORM16 conversion of the validated GPU (probed over every 16-bit code with 1/64 steps
// and checked on 6.2M stored values: no mismatch): floor(x*65536 - floor(x*16)/16 + 7/16), i.e.
// round-to-nearest with a threshold of 9/16 that slides down to 1/2 over each 1/16 of x. One
// stored code near black becomes up to two output levels, so recomputed intermediates must match
// it exactly. LEAN_UNORM16_ROP_OFFSET (7/16) is the one calibration constant; other GPUs may differ.
#ifndef LEAN_UNORM16_ROP_OFFSET
#define LEAN_UNORM16_ROP_OFFSET 0.4375
#endif
float4 leanCode16Rop(float4 value)
{
    const float4 x = saturate(value);
    return min(floor(x * 65536.0 - floor(x * 16.0) * (1.0 / 16.0) + LEAN_UNORM16_ROP_OFFSET), 65535.0);
}
float4 leanUNorm16Rop(float4 value) { return leanCode16Rop(value) / 65535.0; }
// Close approximation of the same conversion (plain rounding with the 9/16 threshold; it differs in about
// 1% of values) for outputs that tolerate it. The fused pass uses it for straight output.
float4 leanCode16Fast(float4 value) { return floor(saturate(value) * 65535.0 + LEAN_UNORM16_ROP_OFFSET); }
float4 leanCode16(float4 value, bool exact) { return exact ? leanCode16Rop(value) : leanCode16Fast(value); }

void leanBloomVerticalVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0,
    out nointerpolation float sigma : TEXCOORD1)
{
    // Sigma is uniform across the triangle. Interpolating it perturbs rare
    // half-UNORM values, which gamma can amplify at curved sample locations.
    bloomVerticalVS(id, pos, uv, sigma);
}
void leanBloomVerticalPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, nointerpolation float sigma : TEXCOORD1,
    out float4 color : SV_Target)
{
    bloomVerticalPS(pos, uv, sigma, color);
}

void leanPhosphorPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, float2 frequency : TEXCOORD1,
    float2 pqx : TEXCOORD2, float2 pqy : TEXCOORD3, out float4 rg : SV_Target0, out float4 blue : SV_Target1)
{
    generatePhosphorMaskPS(pos, uv, frequency, pqx, pqy, rg);
    blue = float4(rg.b, 0, 0, 1);
}
void leanMaskPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 color : SV_Target)
{
    float2 rg = tex2D(samplerPhosphorMask, uv).rg;
    // Live changes leave older colors in untouched cache segments.
#if __RESHADE_PERFORMANCE_MODE__
    bool shared_blue = mask_type >= 3 && phosphor_offset_x.r == phosphor_offset_x.b && phosphor_offset_y.r == phosphor_offset_y.b;
#else
    bool shared_blue = false;
#endif
    float blue = shared_blue ? rg.r : tex2D(samplerPhosphorBlue, uv).r;
    bool interlaced = enable_interlacing && (scanline_deinterlacing_mode == 2 || scanline_deinterlacing_mode == 3);
    float3 scanlines = interlaced ? tex2D(samplerDeinterlace, uv).rgb : tex2D(samplerBeamConvergence, uv).rgb;
    float3 halation = tex2D_linearize(samplerBlurHorizontal, uv, get_intermediate_gamma()).rgb;
    color = float4(lerp(scanlines, dot(halation, float3(1, 1, 1)) / 3.0, halation_weight) * float3(rg, blue), 1);
}

void leanPreblurVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0)
{
    contentCropVS(id, pos, uv);
    if (all(preblur_sampling_radius == 0) && all(frac(content_offset * buffer_size) == 0.0)) pos.x = -1.0;
}
void leanPreblurHorizVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0)
{
    PostProcessVS(id, pos, uv);
    if (all(preblur_sampling_radius == 0) && all(frac(content_offset * buffer_size) == 0.0)) pos.x = -1.0;
}
float3 leanInput(float2 uv)
{
#if ENABLE_PREBLUR
    if (any(preblur_sampling_radius != 0) || any(frac(content_offset * buffer_size) != 0.0)) return tex2Dlod_linearize(samplerPreblurHoriz, uv, get_input_gamma()).rgb;
#endif
    return pow(tex2Dlod(ReShade::BackBuffer, float4(uv * content_scale + content_offset, 0, 0)).rgb, get_input_gamma());
}
float3 leanBeam(float2 uv)
{
    bool landscape = geom_rotation_mode == 0 || geom_rotation_mode == 2;
    float2 rotated = landscape ? uv : uv.yx;
    float scale = landscape ? CONTENT_HEIGHT : CONTENT_WIDTH;
    InterpolationFieldData field = calc_interpolation_field_data(rotated, scale);
    float ypos = (rotated.y * field.triangle_wave_freq + field.field_parity) * 0.5;
    float2 bin_size = (landscape ? float2(1, scanline_thickness) : float2(scanline_thickness, 1)) / content_size;
    float2 sample_uv = round_coord(uv, 0, bin_size);
    if (field.wrong_field) {
        if (landscape) sample_uv.y += (sample_uv.y <= uv.y ? 1 : -1) * scanline_thickness / (CONTENT_HEIGHT);
        else sample_uv.x += (sample_uv.x <= uv.x ? 1 : -1) * scanline_thickness / (CONTENT_WIDTH);
    }
    float3 current = leanInput(sample_uv);
    float3 result = float3(tex2D_nograd(samplerBeamDist, float2(current.r, ypos)).x,
        tex2D_nograd(samplerBeamDist, float2(current.g, ypos)).x,
        tex2D_nograd(samplerBeamDist, float2(current.b, ypos)).x);
    if (beam_shape_mode == 3) {
        float2 offset = float2(0, scanline_thickness) * (1 + enable_interlacing) / content_size;
        float3 upper = leanInput(sample_uv - offset), lower = leanInput(sample_uv + offset);
        result += float3(tex2D_nograd(samplerBeamDist, float2(upper.r, ypos)).y,
            tex2D_nograd(samplerBeamDist, float2(upper.g, ypos)).y,
            tex2D_nograd(samplerBeamDist, float2(upper.b, ypos)).y);
        result += float3(tex2D_nograd(samplerBeamDist, float2(lower.r, ypos)).z,
            tex2D_nograd(samplerBeamDist, float2(lower.g, ypos)).z,
            tex2D_nograd(samplerBeamDist, float2(lower.b, ypos)).z);
    }
    return result;
}
void leanCachedBeamVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0)
{
    PostProcessVS(id, pos, uv);
    if (all(convergence_offset_x == 0) && all(convergence_offset_y == 0) && scanline_offset == 0) pos.x = -1.0;
}
void leanCachedBeamPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 color : SV_Target)
{
    color = float4(leanBeam(uv), 1);
}
void leanBeamsPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 color : SV_Target)
{
    if (all(convergence_offset_x == 0) && all(convergence_offset_y == 0) && scanline_offset == 0) {
        color = float4(leanBeam(uv), 1); return;
    }
    // Fractional convergence needs hardware filtering of quantized emission.
    // Re-evaluating four beam samples per channel was slower and less accurate.
    float run_convergence = any(convergence_offset_x != 0) || any(convergence_offset_y != 0);
    beamConvergencePS(pos, uv, run_convergence, color);
}

bool leanFuseGeometry()
{
#if _RUNTIME_GEOMETRY_MODE
    float mode = geom_mode_runtime;
#else
    float mode = geom_mode_static;
#endif
    return leanAlignedOutput && (antialias_level < 0.5 || (mode <= 0.5 && all(geom_overscan == 1)));
}
void leanGeometryCacheVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0,
    out float2 output_size_inv : TEXCOORD1, out float4 aspect_overscan : TEXCOORD2,
    out float3 eye : TEXCOORD3, out float3 row0 : TEXCOORD4, out float3 row1 : TEXCOORD5,
    out float3 row2 : TEXCOORD6)
{
    geometryVS(id, pos, uv, output_size_inv, aspect_overscan, eye, row0, row1, row2);
    if (leanFuseGeometry()) pos.x = -1.0;
}
void leanOutputPS(float4 pos : SV_Position, float2 uv : TEXCOORD0,
    float2 output_size_inv : TEXCOORD1, float4 aspect_overscan : TEXCOORD2,
    float3 eye : TEXCOORD3, float3 row0 : TEXCOORD4, float3 row1 : TEXCOORD5,
    float3 row2 : TEXCOORD6, out float4 color : SV_Target)
{
    if (!leanFuseGeometry()) {
#if !USE_VERTEX_UNCROPPING
        uncropContentPixelShader(pos, uv, color);
#else
        const float2 cached_uv = ((uv - content_offset) * buffer_size) / content_size;
        color = tex2D(samplerGeometry, cached_uv);
        if (uv.x < content_left || uv.x > content_right || uv.y < content_upper || uv.y > content_lower) color.rgb = 0;
#endif
        return;
    }
    if (uv.x < content_left || uv.x > content_right || uv.y < content_upper || uv.y > content_lower) {
        color = float4(0, 0, 0, 1); return;
    }
    float2 local_uv = (uv - content_offset) / content_scale;
    geometryPS(pos, local_uv, output_size_inv, aspect_overscan, eye, row0, row1, row2, color);
    color = leanUNorm16(color);
}
void leanOutputVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0,
    out float2 output_size_inv : TEXCOORD1, out float4 aspect_overscan : TEXCOORD2,
    out float3 eye : TEXCOORD3, out float3 row0 : TEXCOORD4, out float3 row1 : TEXCOORD5,
    out float3 row2 : TEXCOORD6)
{
    geometryVS(min(id, 2), pos, uv, output_size_inv, aspect_overscan, eye, row0, row1, row2);
    if (!leanFuseGeometry()) {
#if !USE_VERTEX_UNCROPPING
        contentUncropVS(id, pos, uv);
#else
        uv = float2(id & 1, !(id & 2));
        pos = float4(uv * float2(2, -2) + float2(-1, 1), 1, 1);
#endif
    }
}

// What the texture unit returns for a bilinear tap of a UNORM16 texture, as a 16-bit code: the blend
// of two codes with an 8-bit weight (w in 0..256), rounded half up. Emulated filtering has to round
// the same way or its sums drift from the hardware's by a code or two. The numerator stays below
// 2^24, so float arithmetic on integer-valued codes is exact.
float3 leanFilterCode(float3 a, float3 b, float w) { return floor((a * (256.0 - w) + b * w + 128.0) * (1.0 / 256.0)); }
// A normalized tap of the fused pass. Straight output uses the plain blend; curved output
// resamples the composite, so there taps are rounded like the texture unit. Real-game precision
// failures and the limits of this device-specific emulation are recorded in GAME-TESTS.md.
float3 leanTap(float3 a, float3 b, float w, bool exact) { return (exact ? leanFilterCode(a, b, w) : lerp(a, b, w * (1.0 / 256.0))) / 65535.0; }
// BloomApprox: the vertical and horizontal 3-tap box passes as one pass, bit-identical to the pair.
// A column of the vertical pass's output is recomputed on demand (same taps, stored-texture
// quantization), then combined with the 8-bit bilinear weight the horizontal pass's sampler used.
float3 leanApproxColumn(int column, float2 uv, uint pairs, float2 delta)
{
    const float2 coord_top = float2((column + 0.5) / (CONTENT_WIDTH), uv.y) - delta * pairs;
    float3 acc = 0;
    for (int i = 0; i < pairs * 2 + 1; ++i)
        acc += tex2Dlod(samplerBeamConvergence, float4(coord_top + i * delta, 0, 0)).rgb;
    return leanCode16Rop(float4(acc / (pairs * 2 + 1), 1)).rgb;
}
void leanApproxBloomPS(float4 pos : SV_Position, float2 uv : TEXCOORD0, out float4 color : SV_Target)
{
    const uint pairs = uint((bloomapprox_downsizing_factor - 1) / 2);
    const float2 dy = blur_radius * float2(0.0, rcp(CONTENT_HEIGHT));
    const float dx = blur_radius * rcp(CONTENT_WIDTH);
    if (blur_radius == 1.0 && pairs == 1) {
        // Unit radius: the three horizontal taps share one fractional weight and four columns.
        const float x = (uv.x - dx) * CONTENT_WIDTH - 0.5;
        const int a = int(floor(x));
        const float w = floor(frac(x) * 256.0 + 0.5);
        const float3 c0 = leanApproxColumn(clamp(a, 0, int(CONTENT_WIDTH) - 1), uv, 1, dy);
        const float3 c1 = leanApproxColumn(clamp(a + 1, 0, int(CONTENT_WIDTH) - 1), uv, 1, dy);
        const float3 c2 = leanApproxColumn(clamp(a + 2, 0, int(CONTENT_WIDTH) - 1), uv, 1, dy);
        const float3 c3 = leanApproxColumn(clamp(a + 3, 0, int(CONTENT_WIDTH) - 1), uv, 1, dy);
        color = float4(((leanFilterCode(c0, c1, w) / 65535.0 + leanFilterCode(c1, c2, w) / 65535.0) + leanFilterCode(c2, c3, w) / 65535.0) / 3.0, 1);
        return;
    }
    float3 acc = 0;
    const float x_left = uv.x - dx * pairs;
    for (int i = 0; i < pairs * 2 + 1; ++i) {
        const float x = (x_left + i * dx) * CONTENT_WIDTH - 0.5;
        const int a = int(floor(x));
        const float w = floor(frac(x) * 256.0 + 0.5);
        acc += leanFilterCode(leanApproxColumn(clamp(a, 0, int(CONTENT_WIDTH) - 1), uv, pairs, dy),
                              leanApproxColumn(clamp(a + 1, 0, int(CONTENT_WIDTH) - 1), uv, pairs, dy), w) / 65535.0;
    }
    color = float4(acc / (pairs * 2 + 1), 1);
}
