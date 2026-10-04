// LeanCRT: a remake of CRT Royale's rendering pipeline.
// GPL-2.0-or-later. Original CRT Royale: TroggleMonkey; ReShade port: Alex Gunter.
// Copyright (C) 2014 TroggleMonkey; Copyright (C) 2020 Alex Gunter.
#include "leancrt/ReShade.fxh"
#ifndef CONTENT_BOX_VISIBLE
#define CONTENT_BOX_VISIBLE 0
#endif
#include "leancrt/resources.fxh"
#include "leancrt/royale/shaders/content-box.fxh"
#if !CONTENT_BOX_VISIBLE
#include "leancrt/royale/shaders/input-blurring.fxh"
#include "leancrt/royale/shaders/electron-beams.fxh"
#include "leancrt/royale/shaders/blurring.fxh"
#include "leancrt/royale/shaders/deinterlace.fxh"
#include "leancrt/royale/shaders/phosphor-mask.fxh"
#include "leancrt/royale/shaders/brightpass.fxh"
#include "leancrt/royale/shaders/bloom.fxh"
#include "leancrt/royale/shaders/geometry-aa-last-pass.fxh"
#include "leancrt/pipeline.fxh"
// D3D11 compute: mask, brightpass, bloom and composite fused in one pass when the 9-tap kernel is
// active and the content box is pixel-aligned (straight output also gets its final 8-bit image from
// it). The stored-intermediate paths remain for wider kernels: tiled bloom for 4K-sized outputs,
// raster bloom below that (single-execution measurements).
#if __RENDERER__ >= 0xb000 && __RENDERER__ < 0xc000
#define LEAN_FUSED_BLOOM 1
#else
#define LEAN_FUSED_BLOOM 0
#endif
#if LEAN_FUSED_BLOOM && BUFFER_WIDTH * BUFFER_HEIGHT >= 3840 * 2160
#define LEAN_TILED_BLOOM 1
#else
#define LEAN_TILED_BLOOM 0
#endif
#if LEAN_FUSED_BLOOM
#include "leancrt/fused-bloom.fxh"
#if LEAN_TILED_BLOOM
#include "leancrt/tiled-bloom.fxh"
#endif
#endif
#if LEAN_FINAL_STORE
// For straight output the fused pass has already written the finished image (see resources.fxh); copy it, with the
// area outside the content box black as the original Output does.
void leanFinalPS(float4 pos : SV_Position, float2 uv : TEXCOORD0,
    float2 output_size_inv : TEXCOORD1, float4 aspect_overscan : TEXCOORD2,
    float3 eye : TEXCOORD3, float3 row0 : TEXCOORD4, float3 row1 : TEXCOORD5,
    float3 row2 : TEXCOORD6, out float4 color : SV_Target)
{
    if (!leanFusedActive() || !leanStraightOutput())
        leanOutputPS(pos, uv, output_size_inv, aspect_overscan, eye, row0, row1, row2, color);
    else if (uv.x < content_left || uv.x > content_right || uv.y < content_upper || uv.y > content_lower)
        color = float4(0, 0, 0, 1);
    else
        color = tex2Dfetch(samplerFinal, int2(pos.xy));
}
#define LEAN_OUTPUT_PS leanFinalPS
#else
#define LEAN_OUTPUT_PS leanOutputPS
#endif
#if LEAN_FUSED_BLOOM
[numthreads(FT_W, FT_H, 1)]
void lean_bloom(uint3 group : SV_GroupID, uint3 local : SV_GroupThreadID, uint3 pixel : SV_DispatchThreadID)
{
    if (leanFusedActive()) fused_bloom_body(group, local, pixel);
#if LEAN_TILED_BLOOM
    else tiled_bloom_body(group, local, pixel);
#endif
}
#endif
#endif

technique LeanCRT
{
#if CONTENT_BOX_VISIBLE
    pass ContentBox { VertexShader = PostProcessVS; PixelShader = contentBoxPixelShader; }
#else
#if ENABLE_PREBLUR
    pass PreblurVert { VertexShader = leanPreblurVS; PixelShader = preblurVertPS; RenderTarget = texPreblurVert; ClearRenderTargets = false; PrimitiveTopology = TRIANGLESTRIP; VertexCount = 4; }
    pass PreblurHoriz { VertexShader = leanPreblurHorizVS; PixelShader = preblurHorizPS; RenderTarget = texPreblurHoriz; ClearRenderTargets = false; }
#endif
    pass BeamLookup { VertexShader = calculateBeamDistsVS; PixelShader = calculateBeamDistsPS; RenderTarget = texBeamDist; ClearRenderTargets = false; }
    pass CachedBeams { VertexShader = leanCachedBeamVS; PixelShader = leanCachedBeamPS; RenderTarget = texElectronBeams; ClearRenderTargets = false; }
    pass BeamsConvergence { VertexShader = PostProcessVS; PixelShader = leanBeamsPS; RenderTarget = texBeamConvergence; }
    pass BloomApprox { VertexShader = PostProcessVS; PixelShader = leanApproxBloomPS; RenderTarget = texBloomApproxHoriz; }
    pass DiffusionVert { VertexShader = blurVerticalVS; PixelShader = blurVerticalPS; RenderTarget = texBlurVertical; }
    pass DiffusionHoriz { VertexShader = blurHorizontalVS; PixelShader = blurHorizontalPS; RenderTarget = texBlurHorizontal; }
    pass Deinterlace { VertexShader = deinterlaceVS; PixelShader = deinterlacePS; RenderTarget = texDeinterlace; }
    pass History { VertexShader = freezeFrameVS; PixelShader = freezeFramePS; RenderTarget = texFreezeFrame; ClearRenderTargets = false; }
    pass PhosphorLookup { VertexShader = generatePhosphorMaskVS; PixelShader = leanPhosphorPS; RenderTarget = texPhosphorMask; RenderTarget1 = texPhosphorBlue; ClearRenderTargets = false; PrimitiveTopology = TRIANGLESTRIP; VertexCount = 4; }
#if LEAN_FUSED_BLOOM
    pass Mask { VertexShader = leanMaskVS; PixelShader = leanMaskPS; RenderTarget = texMaskedScanlines; ClearRenderTargets = false; }
    pass Bright { VertexShader = leanBrightVS; PixelShader = brightpassPS; RenderTarget = texBrightpass; ClearRenderTargets = false; }
#else
    pass Mask { VertexShader = PostProcessVS; PixelShader = leanMaskPS; RenderTarget = texMaskedScanlines; }
    pass Bright { VertexShader = brightpassVS; PixelShader = brightpassPS; RenderTarget = texBrightpass; }
#endif
#if LEAN_FUSED_BLOOM && !LEAN_TILED_BLOOM
    pass BloomVert { VertexShader = leanBloomVerticalGatedVS; PixelShader = leanBloomVerticalPS; RenderTarget = texBloomVertical; ClearRenderTargets = false; }
    pass BloomHoriz { VertexShader = leanBloomHorizontalGatedVS; PixelShader = bloomHorizontalPS; RenderTarget = texBloomHorizontal; ClearRenderTargets = false; }
#endif
#if !LEAN_FUSED_BLOOM
    pass BloomVert { VertexShader = leanBloomVerticalVS; PixelShader = leanBloomVerticalPS; RenderTarget = texBloomVertical; }
    pass BloomComposite { VertexShader = bloomHorizontalVS; PixelShader = bloomHorizontalPS; RenderTarget = texBloomHorizontal; }
#else
    pass BloomComposite { ComputeShader = lean_bloom; DispatchSizeX = (CONTENT_WIDTH + FT_W - 1) / FT_W; DispatchSizeY = (CONTENT_HEIGHT + FT_H - 1) / FT_H; }
#endif
    pass GeometryCache { VertexShader = leanGeometryCacheVS; PixelShader = geometryPS; RenderTarget = texGeometry; ClearRenderTargets = false; }
    pass Output { VertexShader = leanOutputVS; PixelShader = LEAN_OUTPUT_PS; PrimitiveTopology = TRIANGLESTRIP; VertexCount = 4; }
#endif
}
