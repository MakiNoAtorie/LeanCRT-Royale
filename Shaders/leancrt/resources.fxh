// GPL-2.0-or-later. CRT Royale resource layout rebuilt for LeanCRT.
#ifndef LEANCRT_RESOURCES
#define LEANCRT_RESOURCES
#include "leancrt/royale/lib/bind-shader-params.fxh"
// ReShade shares named textures across loaded effects, including disabled ones.
// Keep our changed formats and persistent caches separate from original Royale.
#define texPreblurVert leanTexPreblurVert
#define texPreblurHoriz leanTexPreblurHoriz
#define texBeamDist leanTexBeamDist
#define texElectronBeams leanTexElectronBeams
#define texBeamConvergence leanTexBeamConvergence
#define texBloomApproxHoriz leanTexBloomApproxHoriz
#define texBlurVertical leanTexBlurVertical
#define texBlurHorizontal leanTexBlurHorizontal
#define texDeinterlace leanTexDeinterlace
#define texFreezeFrame leanTexFreezeFrame
#define texPhosphorMask leanTexPhosphorMask
#define texPhosphorBlue leanTexPhosphorBlue
#define texFinal leanTexFinal
// Supply the resources expected by retained Royale modules without allocating
// their original geometry intermediate.
#define _SHARED_OBJECTS_H
#define LEAN_TARGET(name, w, h) \
    texture2D tex##name < pooled = true; > { Width = w; Height = h; Format = RGBA16; }; \
    sampler2D sampler##name { Texture = tex##name; };
#define TEX_PREBLUR_VERT_WIDTH CONTENT_WIDTH
#define TEX_PREBLUR_VERT_HEIGHT CONTENT_HEIGHT
#define TEX_PREBLUR_HORIZ_WIDTH CONTENT_WIDTH
#define TEX_PREBLUR_HORIZ_HEIGHT CONTENT_HEIGHT
LEAN_TARGET(PreblurVert, CONTENT_WIDTH, CONTENT_HEIGHT)
LEAN_TARGET(PreblurHoriz, CONTENT_WIDTH, CONTENT_HEIGHT)
#define TEX_BEAMDIST_WIDTH num_beamdist_color_samples
#define TEX_BEAMDIST_HEIGHT num_beamdist_dist_samples
#define TEX_BEAMDIST_SIZE int2(TEX_BEAMDIST_WIDTH, TEX_BEAMDIST_HEIGHT)
texture2D texBeamDist { Width = TEX_BEAMDIST_WIDTH; Height = TEX_BEAMDIST_HEIGHT; Format = RGB10A2; };
sampler2D samplerBeamDist { Texture = texBeamDist; AddressV = WRAP; };
#define TEX_ELECTRONBEAMS_SIZE int2(CONTENT_WIDTH, CONTENT_HEIGHT)
texture2D texElectronBeams < pooled = true; > { Width = CONTENT_WIDTH; Height = CONTENT_HEIGHT; Format = RGBA16; };
sampler2D samplerElectronBeams { Texture = texElectronBeams; AddressU = BORDER; AddressV = BORDER; };
#define TEX_BEAMCONVERGENCE_WIDTH CONTENT_WIDTH
#define TEX_BEAMCONVERGENCE_HEIGHT CONTENT_HEIGHT
#define TEX_BEAMCONVERGENCE_SIZE TEX_ELECTRONBEAMS_SIZE
LEAN_TARGET(BeamConvergence, CONTENT_WIDTH, CONTENT_HEIGHT)
#define TEX_BLOOMAPPROXVERT_WIDTH CONTENT_WIDTH
#define TEX_BLOOMAPPROXVERT_HEIGHT int(CONTENT_HEIGHT / bloomapprox_downsizing_factor)
#define TEX_BLOOMAPPROXHORIZ_WIDTH int(CONTENT_WIDTH / bloomapprox_downsizing_factor)
#define TEX_BLOOMAPPROXHORIZ_HEIGHT TEX_BLOOMAPPROXVERT_HEIGHT
LEAN_TARGET(BloomApproxHoriz, TEX_BLOOMAPPROXHORIZ_WIDTH, TEX_BLOOMAPPROXHORIZ_HEIGHT)
// One pass writes BloomApproxHoriz directly. The vertical target only exists so the unmodified
// Royale pixel shaders still compile; it aliases the horizontal one and is never bound.
#define texBloomApproxVert texBloomApproxHoriz
sampler2D samplerBloomApproxVert { Texture = texBloomApproxVert; };
#define TEX_BLURVERTICAL_SIZE int2(TEX_BLOOMAPPROXHORIZ_WIDTH, TEX_BLOOMAPPROXHORIZ_HEIGHT)
#define TEX_BLURHORIZONTAL_SIZE TEX_BLURVERTICAL_SIZE
LEAN_TARGET(BlurVertical, TEX_BLOOMAPPROXHORIZ_WIDTH, TEX_BLOOMAPPROXHORIZ_HEIGHT)
LEAN_TARGET(BlurHorizontal, TEX_BLOOMAPPROXHORIZ_WIDTH, TEX_BLOOMAPPROXHORIZ_HEIGHT)
#define TEX_FREEZEFRAME_HEIGHT CONTENT_HEIGHT
LEAN_TARGET(Deinterlace, CONTENT_WIDTH, CONTENT_HEIGHT)
texture2D texFreezeFrame { Width = CONTENT_WIDTH; Height = CONTENT_HEIGHT; Format = RGBA16; };
sampler2D samplerFreezeFrame { Texture = texFreezeFrame; };
texture2D texPhosphorMask { Width = CONTENT_WIDTH; Height = CONTENT_HEIGHT; Format = RG16; };
sampler2D samplerPhosphorMask { Texture = texPhosphorMask; };
texture2D texPhosphorBlue { Width = CONTENT_WIDTH; Height = CONTENT_HEIGHT; Format = R16; };
sampler2D samplerPhosphorBlue { Texture = texPhosphorBlue; };
// PreblurVert is dead after PreblurHoriz; mask writes the whole surface.
#define texMaskedScanlines texPreblurVert
sampler2D samplerMaskedScanlines { Texture = texMaskedScanlines; };
// Mask is the last Deinterlace consumer; history stays in texFreezeFrame.
#define texBrightpass texDeinterlace
sampler2D samplerBrightpass { Texture = texBrightpass; };
#define TEX_BLOOMVERTICAL_WIDTH CONTENT_WIDTH
#define TEX_BLOOMVERTICAL_HEIGHT CONTENT_HEIGHT
// Mask consumed BeamConvergence after bloom approximation and history.
#define texBloomVertical texBeamConvergence
sampler2D samplerBloomVertical { Texture = texBloomVertical; };
// Beam reconstruction consumed PreblurHoriz before any bloom composite runs.
#define texBloomHorizontal texPreblurHoriz
sampler2D samplerBloomHorizontal { Texture = texBloomHorizontal; };
#define LEAN_ORIGIN_X ((BUFFER_WIDTH - int(CONTENT_WIDTH)) * 0.5 + CONTENT_CENTER_X)
#define LEAN_ORIGIN_Y ((BUFFER_HEIGHT - int(CONTENT_HEIGHT)) * 0.5 + CONTENT_CENTER_Y)
#define LEAN_ALIGNED (LEAN_ORIGIN_X == int(LEAN_ORIGIN_X) && LEAN_ORIGIN_Y == int(LEAN_ORIGIN_Y))
static const bool leanAlignedOutput = LEAN_ALIGNED;
// Beam emission is dead after convergence. Reuse its full-sized scratch target
// for geometry instead of allocating another texture for curved/filtered output.
#define texGeometry texElectronBeams
sampler2D samplerGeometry { Texture = texElectronBeams; };
// D3D11 with an 8-bit backbuffer: the fused compute pass writes the finished, output-encoded
// image here instead of the 16-bit composite, and Output only copies it to the backbuffer.
#ifndef BUFFER_COLOR_BIT_DEPTH
#define BUFFER_COLOR_BIT_DEPTH 8
#endif
#if __RENDERER__ >= 0xb000 && __RENDERER__ < 0xc000 && BUFFER_COLOR_BIT_DEPTH == 8
#define LEAN_FINAL_STORE 1
texture2D texFinal < pooled = true; > { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler2D samplerFinal { Texture = texFinal; };
#else
#define LEAN_FINAL_STORE 0
#endif
#undef LEAN_TARGET
#endif
