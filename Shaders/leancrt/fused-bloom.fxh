// GPL-2.0-or-later. CRT Royale mask, brightpass, bloom and composite fused in one compute pass.
// Copyright (C) 2014 TroggleMonkey; Copyright (C) 2020 Alex Gunter.
// Mask and brightpass are recomputed for the tile plus halo in shared memory instead of being
// stored. Kernel arithmetic and tap order match tiled-bloom.fxh. Handles the 9-tap kernel (halo 4)
// for any output whose content box sits on whole backbuffer pixels; other kernels fall back to the
// stored-intermediate paths (fusing them recomputes mask and brightpass over a 3-4x larger halo and
// measured slower than storing).
#define FT_W 32
#define FT_H 16
#define FT_HALO 4
#define FT_SW (FT_W + 2 * FT_HALO)
#define FT_SH (FT_H + 2 * FT_HALO)
int selected_halo(float sigma) {
#ifdef PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
    return sigma <= blur9_std_dev ? 4 : sigma <= blur17_std_dev ? 8 : sigma <= blur25_std_dev ? 12 : sigma <= blur31_std_dev ? 15 : 21;
#else
    #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
    return 21;
    #else
    #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
    return 15;
    #else
    #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
    return 12;
    #else
    #if PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
    return 8;
    #else
    return 4;
    #endif
    #endif
    #endif
    #endif
#endif
}
float lean_bloom_sigma() { return get_final_bloom_sigma(get_min_sigma_to_blur_triad(calc_triad_size().x, bloom_diff_thresh_)); }
// Uniform across the frame. Straight output (flat, no overscan) copies the composite to the backbuffer,
// so the fused pass may use the cheaper approximations of the hardware's rounding and filtering and
// write the finished image itself. Curved or overscanned output resamples the composite, which
// amplifies last-code differences (a few output levels in a handful of pixels), so there the pass
// reproduces the render-target conversion and the texture unit's tap rounding exactly.
bool leanStraightOutput()
{
#if _RUNTIME_GEOMETRY_MODE
    float mode = geom_mode_runtime;
#else
    float mode = geom_mode_static;
#endif
    return leanAlignedOutput && mode <= 0.5 && all(geom_overscan == 1);
}
bool leanFusedActive() { return leanAlignedOutput && selected_halo(lean_bloom_sigma()) == 4; }
storage2D bloom_store { Texture = texBloomHorizontal; };
#if LEAN_FINAL_STORE
storage2D final_store { Texture = texFinal; };
#endif

// Gated passes collapse to zero-area triangles while the fused pass is active.
void leanMaskVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0)
{
    PostProcessVS(id, pos, uv);
    if (leanFusedActive()) pos.x = -1.0;
}
void leanBrightVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0, out float sigma : TEXCOORD1)
{
    brightpassVS(id, pos, uv, sigma);
    if (leanFusedActive()) pos.x = -1.0;
}
void leanBloomVerticalGatedVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0,
    out nointerpolation float sigma : TEXCOORD1)
{
    leanBloomVerticalVS(id, pos, uv, sigma);
    if (leanFusedActive()) pos.x = -1.0;
}
void leanBloomHorizontalGatedVS(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0, out float sigma : TEXCOORD1)
{
    bloomHorizontalVS(id, pos, uv, sigma);
    if (leanFusedActive()) pos.x = -1.0;
}

groupshared float3 br_tile[FT_SW * FT_SH];
groupshared float3 m_tile[FT_W * FT_H];
// One shared pool serves the fused path and the stored-intermediate tiled path (halo up to 21).
#if LEAN_TILED_BLOOM
#define FT_VERT_SIZE (FT_H * (FT_W + 2 * 21))
#else
#define FT_VERT_SIZE (FT_H * FT_SW)
#endif
groupshared float3 vertical[FT_VERT_SIZE];

float3 fused_mask(float2 uv, bool exact)
{
    float2 rg = tex2Dlod(samplerPhosphorMask, float4(uv, 0, 0)).rg;
#if __RESHADE_PERFORMANCE_MODE__
    bool shared_blue = mask_type >= 3 && phosphor_offset_x.r == phosphor_offset_x.b && phosphor_offset_y.r == phosphor_offset_y.b;
#else
    bool shared_blue = false;
#endif
    float blue = shared_blue ? rg.r : tex2Dlod(samplerPhosphorBlue, float4(uv, 0, 0)).r;
    bool interlaced = enable_interlacing && (scanline_deinterlacing_mode == 2 || scanline_deinterlacing_mode == 3);
    float3 scanlines = interlaced ? tex2Dlod(samplerDeinterlace, float4(uv, 0, 0)).rgb : tex2Dlod(samplerBeamConvergence, float4(uv, 0, 0)).rgb;
    float3 halation = tex2Dlod_linearize(samplerBlurHorizontal, uv, get_intermediate_gamma()).rgb;
    return leanCode16(float4(lerp(scanlines, dot(halation, float3(1, 1, 1)) / 3.0, halation_weight) * float3(rg, blue), 1), exact).rgb / 65535.0;
}
// Stored mask/brightpass are decoded with the intermediate gamma when read, as the textures were.
float3 fused_bright(float3 stored_mask, float2 uv, float bloom_sigma, bool exact)
{
    const float3 intensity_dim = pow(stored_mask, get_intermediate_gamma());
    const float mask_amplify = get_mask_amplify();
    const float3 intensity = intensity_dim * rcp(levels_autodim_temp) * mask_amplify * levels_contrast;
    const float3 phosphor_blur_approx = levels_contrast * tex2Dlod_linearize(samplerBloomApproxHoriz, uv, get_intermediate_gamma()).rgb;
    const float center_weight = get_center_weight(bloom_sigma);
    const float3 max_area_contribution_approx = max(float3(0.0, 0.0, 0.0), phosphor_blur_approx - center_weight * intensity);
    const float3 area_contrib_underestimate = bloom_underestimate_levels * max_area_contribution_approx;
    const float3 intensity_underestimate = bloom_underestimate_levels * intensity;
    const float3 blur_ratio_temp = ((float3(1.0, 1.0, 1.0) - area_contrib_underestimate) / intensity_underestimate - float3(1.0, 1.0, 1.0)) / (center_weight - 1.0);
    const float3 blur_ratio = saturate(blur_ratio_temp);
    const float3 brightpass = intensity_dim * lerp(blur_ratio, float3(1.0, 1.0, 1.0), bloom_excess);
    return leanCode16(encode_output(float4(brightpass, 1.0), get_intermediate_gamma()), exact).rgb;
}
// Emulates the hardware's 8-bit bilinear weight along y on the shared brightpass tile. The tap
// position comes from the float32 UV exactly as the sampler would see it, so the weight
// rounding matches the native filter row by row.
float3 br_vsample(int col, float uv_y, int origin_y, bool exact_taps)
{
    float y = uv_y * CONTENT_HEIGHT - 0.5 - origin_y + FT_HALO;
    int a = int(floor(y));
    float w = floor(frac(y) * 256.0 + 0.5);
    int a0 = clamp(a, 0, FT_SH - 1), a1 = clamp(a + 1, 0, FT_SH - 1);
    return pow(leanTap(br_tile[a0 * FT_SW + col], br_tile[a1 * FT_SW + col], w, exact_taps), get_intermediate_gamma());
}
float3 vert_hsample(float uv_x, int row, int origin_x, bool exact_taps)
{
    float x = uv_x * CONTENT_WIDTH - 0.5 - origin_x + FT_HALO;
    int a = clamp(int(floor(x)), 0, FT_SW - 1);
    int b = min(a + 1, FT_SW - 1);
    float w = floor(frac(x) * 256.0 + 0.5);
    return pow(leanTap(vertical[row * FT_SW + a], vertical[row * FT_SW + b], w, exact_taps), get_intermediate_gamma());
}
void fused_bloom_body(uint3 group, uint3 local, uint3 pixel)
{
    const float sigma = lean_bloom_sigma();
    const bool exact_taps = !leanStraightOutput();
    const int2 origin = int2(group.xy) * int2(FT_W, FT_H);
    const uint tid = local.y * FT_W + local.x;
    // Mask and brightpass for tile plus halo, quantized like the stored textures.
    for (uint i = tid; i < FT_SW * FT_SH; i += FT_W * FT_H) {
        int rx = int(i % FT_SW), ry = int(i / FT_SW);
        int2 p = clamp(origin + int2(rx - FT_HALO, ry - FT_HALO), int2(0, 0), int2(CONTENT_WIDTH - 1, CONTENT_HEIGHT - 1));
        float2 uv = (float2(p) + 0.5) / content_size;
        float3 m = fused_mask(uv, exact_taps);
        int cx = rx - FT_HALO, cy = ry - FT_HALO;
        if (cx >= 0 && cx < FT_W && cy >= 0 && cy < FT_H) m_tile[cy * FT_W + cx] = m;
        br_tile[i] = fused_bright(m, uv, sigma, exact_taps);
    }
    barrier();
    // Vertical 9-tap blur, quantized before the horizontal pass as the stored texture was.
    const float denom_inv = 0.5 / (sigma * sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    const float w12 = w1 + w2;
    const float w34 = w3 + w4;
    const float o12 = 1.0 + w2 / w12;
    const float o34 = 3.0 + w4 / w34;
    for (uint j = tid; j < FT_H * FT_SW; j += FT_W * FT_H) {
        int col = int(j % FT_SW);
        int row_y = int(j / FT_SW);
        float uv_y = (float(clamp(origin.y + row_y, 0, CONTENT_HEIGHT - 1)) + 0.5) / content_size.y;
        const float dy = rcp(CONTENT_HEIGHT);
        float3 sum = w34 * br_vsample(col, uv_y - o34 * dy, origin.y, exact_taps);
        sum += w12 * br_vsample(col, uv_y - o12 * dy, origin.y, exact_taps);
        sum += w0 * br_vsample(col, uv_y, origin.y, exact_taps);
        sum += w12 * br_vsample(col, uv_y + o12 * dy, origin.y, exact_taps);
        sum += w34 * br_vsample(col, uv_y + o34 * dy, origin.y, exact_taps);
        vertical[j] = leanCode16(encode_output(float4(sum * weight_sum_inv, 1), get_intermediate_gamma()), exact_taps).rgb;
    }
    barrier();
    if (pixel.x >= CONTENT_WIDTH || pixel.y >= CONTENT_HEIGHT) return;
    const float2 uv = (float2(pixel.xy) + 0.5) / content_size;
    const float dx = rcp(CONTENT_WIDTH);
    const int row = int(local.y);
    float3 blurred = w34 * vert_hsample(uv.x - o34 * dx, row, origin.x, exact_taps);
    blurred += w12 * vert_hsample(uv.x - o12 * dx, row, origin.x, exact_taps);
    blurred += w0 * vert_hsample(uv.x, row, origin.x, exact_taps);
    blurred += w12 * vert_hsample(uv.x + o12 * dx, row, origin.x, exact_taps);
    blurred += w34 * vert_hsample(uv.x + o34 * dx, row, origin.x, exact_taps);
    blurred *= weight_sum_inv;
    const float3 intensity = pow(m_tile[local.y * FT_W + local.x], get_intermediate_gamma());
    const float3 bright = pow(br_tile[(local.y + FT_HALO) * FT_SW + local.x + FT_HALO] / 65535.0, get_intermediate_gamma());
    float3 phosphor = (intensity - bright + blurred) * get_mask_amplify() * (1.0 / levels_autodim_temp) * levels_contrast;
    float3 raw_diffusion = tex2Dlod_linearize(samplerBlurHorizontal, uv, get_intermediate_gamma()).rgb;
    float3 halation = dot(raw_diffusion, float3(1, 1, 1)) / 3.0;
    float3 diffusion = levels_contrast * lerp(raw_diffusion, halation, halation_weight);
    const float4 composite = encode_output(float4(lerp(phosphor, diffusion, diffusion_weight), 1), get_intermediate_gamma());
#if LEAN_FINAL_STORE
    if (!exact_taps) {
        // Straight output: what Output would do to the stored 16-bit composite. Decode, dim the
        // borders, encode, quantize like the 16-bit target it used to render into, and store the
        // 8-bit result at the content box's position in the backbuffer.
        const float2 video_uv = (uv - float2(0.5, 0.5)) / get_geom_overscan_vector() + float2(0.5, 0.5);
        const float border_dim = get_border_dim_factor(video_uv, get_aspect_vector(content_size.x / content_size.y));
        const float3 shown = pow(leanCode16Fast(composite).rgb / 65535.0, get_intermediate_gamma()) * border_dim;
        tex2Dstore(final_store, int2(pixel.xy) + int2(LEAN_ORIGIN_X, LEAN_ORIGIN_Y), leanUNorm16(encode_output(float4(shown, 1.0), get_output_gamma())));
        return;
    }
#endif
    tex2Dstore(bloom_store, int2(pixel.xy), composite);
}
