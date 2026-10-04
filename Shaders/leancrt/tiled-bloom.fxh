// GPL-2.0-or-later. CRT Royale bloom kernels with a tiled D3D11 schedule.
// Copyright (C) 2014 TroggleMonkey; Copyright (C) 2020 Alex Gunter.
// Keep the retained tap order and size policy. Vertical values cross the same
// UNORM16 clipping boundary before horizontal filtering and composition.
// Native filtering on the validated GPU uses eight fractional bits, half-up.
// The conversion probe and image checks cover the numerical emulation.
#define TILE_W FT_W
#define TILE_H FT_H
#define HALO 21
groupshared int2 tile_origin;
groupshared int active_halo;
float4 shared_sample(float2 uv, float gamma)
{
    int stride = TILE_W + 2 * active_halo;
    float x = uv.x * CONTENT_WIDTH - 0.5 - tile_origin.x + active_halo;
    int y = clamp(int(uv.y * CONTENT_HEIGHT) - tile_origin.y, 0, TILE_H - 1);
    int a = clamp(int(floor(x)), 0, stride - 1);
    int b = min(a + 1, stride - 1);
    float t = floor(frac(x) * 256.0 + 0.5) / 256.0;
    return float4(pow(lerp(vertical[y * stride + a], vertical[y * stride + b], t), gamma), 1);
}
float3 shared_tex2Dblur9fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    const float w12 = w1 + w2;
    const float w34 = w3 + w4;
    const float w12_ratio = w2/w12;
    const float w34_ratio = w4/w34;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w34 * shared_sample( tex_uv - (3.0 + w34_ratio) * dxdy, input_gamma).rgb;
    sum += w12 * shared_sample( tex_uv - (1.0 + w12_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * shared_sample( tex_uv, input_gamma).rgb;
    sum += w12 * shared_sample( tex_uv + (1.0 + w12_ratio) * dxdy, input_gamma).rgb;
    sum += w34 * shared_sample( tex_uv + (3.0 + w34_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 shared_tex2Dblur17fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w7_8 * shared_sample( tex_uv - (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * shared_sample( tex_uv - (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * shared_sample( tex_uv - (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w1_2 * shared_sample( tex_uv - (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * shared_sample( tex_uv, input_gamma).rgb;
    sum += w1_2 * shared_sample( tex_uv + (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * shared_sample( tex_uv + (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * shared_sample( tex_uv + (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * shared_sample( tex_uv + (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 shared_tex2Dblur25fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w9_10 = w9 + w10;
    const float w11_12 = w11 + w12;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    const float w9_10_ratio = w10/w9_10;
    const float w11_12_ratio = w12/w11_12;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w11_12 * shared_sample( tex_uv - (11.0 + w11_12_ratio) * dxdy, input_gamma).rgb;
    sum += w9_10 * shared_sample( tex_uv - (9.0 + w9_10_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * shared_sample( tex_uv - (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * shared_sample( tex_uv - (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * shared_sample( tex_uv - (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w1_2 * shared_sample( tex_uv - (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * shared_sample( tex_uv, input_gamma).rgb;
    sum += w1_2 * shared_sample( tex_uv + (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * shared_sample( tex_uv + (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * shared_sample( tex_uv + (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * shared_sample( tex_uv + (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w9_10 * shared_sample( tex_uv + (9.0 + w9_10_ratio) * dxdy, input_gamma).rgb;
    sum += w11_12 * shared_sample( tex_uv + (11.0 + w11_12_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 shared_tex2Dblur31fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w14_15 * shared_sample( tex_uv - (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * shared_sample( tex_uv - (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * shared_sample( tex_uv - (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * shared_sample( tex_uv - (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * shared_sample( tex_uv - (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * shared_sample( tex_uv - (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w2_3 * shared_sample( tex_uv - (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w0_1 * shared_sample( tex_uv - w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w0_1 * shared_sample( tex_uv + w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w2_3 * shared_sample( tex_uv + (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * shared_sample( tex_uv + (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * shared_sample( tex_uv + (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * shared_sample( tex_uv + (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * shared_sample( tex_uv + (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * shared_sample( tex_uv + (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * shared_sample( tex_uv + (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 shared_tex2Dblur43fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    const float w16 = exp(-256.0 * denom_inv);
    const float w17 = exp(-289.0 * denom_inv);
    const float w18 = exp(-324.0 * denom_inv);
    const float w19 = exp(-361.0 * denom_inv);
    const float w20 = exp(-400.0 * denom_inv);
    const float w21 = exp(-441.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w16_17 = w16 + w17;
    const float w18_19 = w18 + w19;
    const float w20_21 = w20 + w21;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    const float w16_17_ratio = w17/w16_17;
    const float w18_19_ratio = w19/w18_19;
    const float w20_21_ratio = w21/w20_21;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w20_21 * shared_sample( tex_uv - (20.0 + w20_21_ratio) * dxdy, input_gamma).rgb;
    sum += w18_19 * shared_sample( tex_uv - (18.0 + w18_19_ratio) * dxdy, input_gamma).rgb;
    sum += w16_17 * shared_sample( tex_uv - (16.0 + w16_17_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * shared_sample( tex_uv - (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * shared_sample( tex_uv - (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * shared_sample( tex_uv - (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * shared_sample( tex_uv - (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * shared_sample( tex_uv - (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * shared_sample( tex_uv - (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w2_3 * shared_sample( tex_uv - (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w0_1 * shared_sample( tex_uv - w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w0_1 * shared_sample( tex_uv + w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w2_3 * shared_sample( tex_uv + (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * shared_sample( tex_uv + (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * shared_sample( tex_uv + (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * shared_sample( tex_uv + (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * shared_sample( tex_uv + (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * shared_sample( tex_uv + (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * shared_sample( tex_uv + (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w16_17 * shared_sample( tex_uv + (16.0 + w16_17_ratio) * dxdy, input_gamma).rgb;
    sum += w18_19 * shared_sample( tex_uv + (18.0 + w18_19_ratio) * dxdy, input_gamma).rgb;
    sum += w20_21 * shared_sample( tex_uv + (20.0 + w20_21_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 shared_tex2DblurNfast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    #if !_RUNTIME_PHOSPHOR_BLOOM_SIGMA
        #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
    #else
        #if _DRIVERS_ALLOW_DYNAMIC_BRANCHES
            #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        #endif
    #endif
    #ifdef PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        if(sigma <= blur9_std_dev)
        {
            return shared_tex2Dblur9fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur17_std_dev)
        {
            return shared_tex2Dblur17fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur25_std_dev)
        {
            return shared_tex2Dblur25fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur31_std_dev)
        {
            return shared_tex2Dblur31fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else
        {
            return shared_tex2Dblur43fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
    #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
            return shared_tex2Dblur43fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
            return shared_tex2Dblur31fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
            return shared_tex2Dblur25fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #if PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
            return shared_tex2Dblur17fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
            return shared_tex2Dblur9fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #endif
        #endif
        #endif
        #endif
    #endif
}float3 compute_tex2Dblur9fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float weight_sum_inv = 1.0 / (w0 + 2.0 * (w1 + w2 + w3 + w4));
    const float w12 = w1 + w2;
    const float w34 = w3 + w4;
    const float w12_ratio = w2/w12;
    const float w34_ratio = w4/w34;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w34 * tex2Dlod_linearize(tex, tex_uv - (3.0 + w34_ratio) * dxdy, input_gamma).rgb;
    sum += w12 * tex2Dlod_linearize(tex, tex_uv - (1.0 + w12_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * tex2Dlod_linearize(tex, tex_uv, input_gamma).rgb;
    sum += w12 * tex2Dlod_linearize(tex, tex_uv + (1.0 + w12_ratio) * dxdy, input_gamma).rgb;
    sum += w34 * tex2Dlod_linearize(tex, tex_uv + (3.0 + w34_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 compute_tex2Dblur17fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w7_8 * tex2Dlod_linearize(tex, tex_uv - (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * tex2Dlod_linearize(tex, tex_uv - (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * tex2Dlod_linearize(tex, tex_uv - (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w1_2 * tex2Dlod_linearize(tex, tex_uv - (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * tex2Dlod_linearize(tex, tex_uv, input_gamma).rgb;
    sum += w1_2 * tex2Dlod_linearize(tex, tex_uv + (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * tex2Dlod_linearize(tex, tex_uv + (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * tex2Dlod_linearize(tex, tex_uv + (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * tex2Dlod_linearize(tex, tex_uv + (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 compute_tex2Dblur25fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w1_2 = w1 + w2;
    const float w3_4 = w3 + w4;
    const float w5_6 = w5 + w6;
    const float w7_8 = w7 + w8;
    const float w9_10 = w9 + w10;
    const float w11_12 = w11 + w12;
    const float w1_2_ratio = w2/w1_2;
    const float w3_4_ratio = w4/w3_4;
    const float w5_6_ratio = w6/w5_6;
    const float w7_8_ratio = w8/w7_8;
    const float w9_10_ratio = w10/w9_10;
    const float w11_12_ratio = w12/w11_12;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w11_12 * tex2Dlod_linearize(tex, tex_uv - (11.0 + w11_12_ratio) * dxdy, input_gamma).rgb;
    sum += w9_10 * tex2Dlod_linearize(tex, tex_uv - (9.0 + w9_10_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * tex2Dlod_linearize(tex, tex_uv - (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * tex2Dlod_linearize(tex, tex_uv - (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * tex2Dlod_linearize(tex, tex_uv - (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w1_2 * tex2Dlod_linearize(tex, tex_uv - (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w0 * tex2Dlod_linearize(tex, tex_uv, input_gamma).rgb;
    sum += w1_2 * tex2Dlod_linearize(tex, tex_uv + (1.0 + w1_2_ratio) * dxdy, input_gamma).rgb;
    sum += w3_4 * tex2Dlod_linearize(tex, tex_uv + (3.0 + w3_4_ratio) * dxdy, input_gamma).rgb;
    sum += w5_6 * tex2Dlod_linearize(tex, tex_uv + (5.0 + w5_6_ratio) * dxdy, input_gamma).rgb;
    sum += w7_8 * tex2Dlod_linearize(tex, tex_uv + (7.0 + w7_8_ratio) * dxdy, input_gamma).rgb;
    sum += w9_10 * tex2Dlod_linearize(tex, tex_uv + (9.0 + w9_10_ratio) * dxdy, input_gamma).rgb;
    sum += w11_12 * tex2Dlod_linearize(tex, tex_uv + (11.0 + w11_12_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 compute_tex2Dblur31fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w14_15 * tex2Dlod_linearize(tex, tex_uv - (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * tex2Dlod_linearize(tex, tex_uv - (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * tex2Dlod_linearize(tex, tex_uv - (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * tex2Dlod_linearize(tex, tex_uv - (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * tex2Dlod_linearize(tex, tex_uv - (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * tex2Dlod_linearize(tex, tex_uv - (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w2_3 * tex2Dlod_linearize(tex, tex_uv - (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w0_1 * tex2Dlod_linearize(tex, tex_uv - w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w0_1 * tex2Dlod_linearize(tex, tex_uv + w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w2_3 * tex2Dlod_linearize(tex, tex_uv + (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * tex2Dlod_linearize(tex, tex_uv + (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * tex2Dlod_linearize(tex, tex_uv + (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * tex2Dlod_linearize(tex, tex_uv + (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * tex2Dlod_linearize(tex, tex_uv + (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * tex2Dlod_linearize(tex, tex_uv + (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * tex2Dlod_linearize(tex, tex_uv + (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 compute_tex2Dblur43fast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    const float denom_inv = 0.5/(sigma*sigma);
    const float w0 = 1.0;
    const float w1 = exp(-1.0 * denom_inv);
    const float w2 = exp(-4.0 * denom_inv);
    const float w3 = exp(-9.0 * denom_inv);
    const float w4 = exp(-16.0 * denom_inv);
    const float w5 = exp(-25.0 * denom_inv);
    const float w6 = exp(-36.0 * denom_inv);
    const float w7 = exp(-49.0 * denom_inv);
    const float w8 = exp(-64.0 * denom_inv);
    const float w9 = exp(-81.0 * denom_inv);
    const float w10 = exp(-100.0 * denom_inv);
    const float w11 = exp(-121.0 * denom_inv);
    const float w12 = exp(-144.0 * denom_inv);
    const float w13 = exp(-169.0 * denom_inv);
    const float w14 = exp(-196.0 * denom_inv);
    const float w15 = exp(-225.0 * denom_inv);
    const float w16 = exp(-256.0 * denom_inv);
    const float w17 = exp(-289.0 * denom_inv);
    const float w18 = exp(-324.0 * denom_inv);
    const float w19 = exp(-361.0 * denom_inv);
    const float w20 = exp(-400.0 * denom_inv);
    const float w21 = exp(-441.0 * denom_inv);
    const float weight_sum_inv = get_fast_gaussian_weight_sum_inv(sigma);
    const float w0_1 = w0 * 0.5 + w1;
    const float w2_3 = w2 + w3;
    const float w4_5 = w4 + w5;
    const float w6_7 = w6 + w7;
    const float w8_9 = w8 + w9;
    const float w10_11 = w10 + w11;
    const float w12_13 = w12 + w13;
    const float w14_15 = w14 + w15;
    const float w16_17 = w16 + w17;
    const float w18_19 = w18 + w19;
    const float w20_21 = w20 + w21;
    const float w0_1_ratio = w1/w0_1;
    const float w2_3_ratio = w3/w2_3;
    const float w4_5_ratio = w5/w4_5;
    const float w6_7_ratio = w7/w6_7;
    const float w8_9_ratio = w9/w8_9;
    const float w10_11_ratio = w11/w10_11;
    const float w12_13_ratio = w13/w12_13;
    const float w14_15_ratio = w15/w14_15;
    const float w16_17_ratio = w17/w16_17;
    const float w18_19_ratio = w19/w18_19;
    const float w20_21_ratio = w21/w20_21;
    float3 sum = float3(0.0,0.0,0.0);
    sum += w20_21 * tex2Dlod_linearize(tex, tex_uv - (20.0 + w20_21_ratio) * dxdy, input_gamma).rgb;
    sum += w18_19 * tex2Dlod_linearize(tex, tex_uv - (18.0 + w18_19_ratio) * dxdy, input_gamma).rgb;
    sum += w16_17 * tex2Dlod_linearize(tex, tex_uv - (16.0 + w16_17_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * tex2Dlod_linearize(tex, tex_uv - (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * tex2Dlod_linearize(tex, tex_uv - (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * tex2Dlod_linearize(tex, tex_uv - (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * tex2Dlod_linearize(tex, tex_uv - (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * tex2Dlod_linearize(tex, tex_uv - (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * tex2Dlod_linearize(tex, tex_uv - (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w2_3 * tex2Dlod_linearize(tex, tex_uv - (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w0_1 * tex2Dlod_linearize(tex, tex_uv - w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w0_1 * tex2Dlod_linearize(tex, tex_uv + w0_1_ratio * dxdy, input_gamma).rgb;
    sum += w2_3 * tex2Dlod_linearize(tex, tex_uv + (2.0 + w2_3_ratio) * dxdy, input_gamma).rgb;
    sum += w4_5 * tex2Dlod_linearize(tex, tex_uv + (4.0 + w4_5_ratio) * dxdy, input_gamma).rgb;
    sum += w6_7 * tex2Dlod_linearize(tex, tex_uv + (6.0 + w6_7_ratio) * dxdy, input_gamma).rgb;
    sum += w8_9 * tex2Dlod_linearize(tex, tex_uv + (8.0 + w8_9_ratio) * dxdy, input_gamma).rgb;
    sum += w10_11 * tex2Dlod_linearize(tex, tex_uv + (10.0 + w10_11_ratio) * dxdy, input_gamma).rgb;
    sum += w12_13 * tex2Dlod_linearize(tex, tex_uv + (12.0 + w12_13_ratio) * dxdy, input_gamma).rgb;
    sum += w14_15 * tex2Dlod_linearize(tex, tex_uv + (14.0 + w14_15_ratio) * dxdy, input_gamma).rgb;
    sum += w16_17 * tex2Dlod_linearize(tex, tex_uv + (16.0 + w16_17_ratio) * dxdy, input_gamma).rgb;
    sum += w18_19 * tex2Dlod_linearize(tex, tex_uv + (18.0 + w18_19_ratio) * dxdy, input_gamma).rgb;
    sum += w20_21 * tex2Dlod_linearize(tex, tex_uv + (20.0 + w20_21_ratio) * dxdy, input_gamma).rgb;
    return sum * weight_sum_inv;
}
float3 compute_tex2DblurNfast(const sampler2D tex, const float2 tex_uv,
    const float2 dxdy, const float sigma,
    const float input_gamma)
{
    #if !_RUNTIME_PHOSPHOR_BLOOM_SIGMA
        #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
    #else
        #if _DRIVERS_ALLOW_DYNAMIC_BRANCHES
            #define PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        #endif
    #endif
    #ifdef PHOSPHOR_BLOOM_BRANCH_FOR_BLUR_SIZE
        if(sigma <= blur9_std_dev)
        {
            return compute_tex2Dblur9fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur17_std_dev)
        {
            return compute_tex2Dblur17fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur25_std_dev)
        {
            return compute_tex2Dblur25fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else if(sigma <= blur31_std_dev)
        {
            return compute_tex2Dblur31fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
        else
        {
            return compute_tex2Dblur43fast(tex, tex_uv, dxdy, sigma, input_gamma);
        }
    #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_12_PIXELS
            return compute_tex2Dblur43fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_9_PIXELS
            return compute_tex2Dblur31fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #ifdef PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_6_PIXELS
            return compute_tex2Dblur25fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
        #if PHOSPHOR_BLOOM_TRIADS_LARGER_THAN_3_PIXELS
            return compute_tex2Dblur17fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #else
            return compute_tex2Dblur9fast(tex, tex_uv, dxdy, sigma, input_gamma);
        #endif
        #endif
        #endif
        #endif
    #endif
}
void tiled_bloom_body(uint3 group, uint3 local, uint3 pixel)
{
    float sigma = get_final_bloom_sigma(get_min_sigma_to_blur_triad(calc_triad_size().x, bloom_diff_thresh_));
    if (all(local.xy == 0)) { tile_origin = int2(group.xy) * int2(TILE_W, TILE_H); active_halo = selected_halo(sigma); }
    barrier();
    int stride = TILE_W + 2 * active_halo;
    for (uint i = local.y * TILE_W + local.x; i < TILE_H * stride; i += TILE_W * TILE_H) {
        int2 p = tile_origin + int2(int(i % stride) - active_halo, int(i / stride));
        p = clamp(p, int2(0, 0), int2(CONTENT_WIDTH - 1, CONTENT_HEIGHT - 1));
        float2 uv = (float2(p) + 0.5) / content_size;
        float3 v = compute_tex2DblurNfast(samplerBrightpass, uv, float2(0, rcp(CONTENT_HEIGHT)), sigma, get_intermediate_gamma());
        vertical[i] = leanUNorm16(encode_output(float4(v, 1), get_intermediate_gamma())).rgb;
    }
    barrier();
    if (pixel.x >= CONTENT_WIDTH || pixel.y >= CONTENT_HEIGHT) return;
    float2 uv = (float2(pixel.xy) + 0.5) / content_size;
    float3 blurred = shared_tex2DblurNfast(samplerBloomVertical, uv, float2(rcp(CONTENT_WIDTH), 0), sigma, get_intermediate_gamma());
    float3 intensity = tex2Dlod_linearize(samplerMaskedScanlines, uv, get_intermediate_gamma()).rgb;
    float3 bright = tex2Dlod_linearize(samplerBrightpass, uv, get_intermediate_gamma()).rgb;
    float3 phosphor = (intensity - bright + blurred) * get_mask_amplify() * (1.0 / levels_autodim_temp) * levels_contrast;
    float3 raw_diffusion = tex2Dlod_linearize(samplerBlurHorizontal, uv, get_intermediate_gamma()).rgb;
    float3 halation = dot(raw_diffusion, float3(1, 1, 1)) / 3.0;
    float3 diffusion = levels_contrast * lerp(raw_diffusion, halation, halation_weight);
    tex2Dstore(bloom_store, int2(pixel.xy), encode_output(float4(lerp(phosphor, diffusion, diffusion_weight), 1), get_intermediate_gamma()));
}
