# LeanCRT

LeanCRT is a faster rework of CRT Royale for ReShade.

CRT Royale is a CRT shader by TroggleMonkey. Alex Gunter (akgunter) ported it to ReShade. LeanCRT rebuilds the render pipeline of that port. The look and the settings stay the same. The shader uses less GPU time and less memory.

- Same uniform names and Royale controls as the original.
- 20% to 66% less GPU time than the original in our tests (see [Benchmarks](#benchmarks)).
- About 237 MiB less declared texture memory at 4K.
- No extra add-on and no texture assets. ReShade supplies the FX runtime.

## Benchmarks

**Original** is akgunter's CRT Royale v2.1.0 for ReShade. **LeanCRT** is this repository. Lower is better.

Test setup:

- GPU: NVIDIA RTX 5060 Ti, hardware D3D11, SDR output.
- Settings: Royale defaults, ReShade Performance Mode.
- Method: median of three runs. Runs alternate the order of the two shaders.
- The numbers are shader GPU time. They are not game frame rates.

### Synthetic input, default settings

| Output | Original (ms) | LeanCRT (ms) | Less time |
| --- | ---: | ---: | ---: |
| 1080p | 0.389 | 0.256 | 34.3% |
| 1440p | 0.731 | 0.404 | 44.8% |
| 2160p | 1.857 | 0.889 | 52.1% |

### Harder input and curved geometry

The default test pattern is easy to compress. These rows are more representative.

| Case | Original (ms) | LeanCRT (ms) | Less time |
| --- | ---: | ---: | ---: |
| 4K, RGB detail | 2.354 | 0.951 | 59.6% |
| 4K, native-pixel noise | 3.522 | 1.193 | 66.1% |
| 1080p, RGB detail | 0.441 | 0.271 | 38.5% |
| 1080p, native-pixel noise | 0.557 | 0.344 | 38.4% |
| 4K, curved (mode 1) | 1.867 | 1.041 | 44.2% |
| 1080p, curved (mode 1) | 0.390 | 0.301 | 22.9% |
| 4K, cylinder (mode 3), RGB detail | 2.350 | 1.109 | 52.8% |

### Real game input

The game is Shining Force II (Genesis). The test scales its frames with nearest-neighbor to a centered 4:3 content box. The test does one shader execution for each frame. It does not include emulator work.

| Scene / output | Original (ms) | LeanCRT (ms) | Less time |
| --- | ---: | ---: | ---: |
| Lit castle / 1080p | 0.224 | 0.180 | 19.5% |
| Town / 1080p | 0.225 | 0.180 | 20.0% |
| Lit castle / 2160p | 1.001 | 0.640 | 36.1% |
| Town / 2160p | 1.062 | 0.640 | 39.8% |

## How LeanCRT is faster

The original pipeline is largely memory-bound. It writes and reads many full-size 16-bit textures. LeanCRT removes most of this memory traffic. It does not lower quality settings.

| Stage | Change |
| --- | --- |
| Beams | The shader rebuilds beam emission in the destination stage. It skips the preblur copies when their radius is zero. |
| Phosphor mask | The mask cache uses an RG16 texture and an R16 texture, not RGBA16. The cache is 25% smaller. |
| Scratch textures | Four pairs of passes share one texture each. This removes four full-size RGBA16 textures (253 MiB at 4K). |
| Bloom approximation | The two passes are one pass. The result is bit-identical. |
| Mask, brightpass, bloom, composite | On D3D11, one compute pass does all four. Each tile and its halo are recomputed in shared memory. The shader never stores these intermediate textures. This is the largest gain. |
| Final image | For flat output on an 8-bit backbuffer, the compute pass writes the finished image. The Output pass only copies it. |
| Geometry | Geometry and Output are one pass when the crop and anti-aliasing settings permit. |
| Curved output | The fused pass rounds 16-bit conversions and texture taps in the same way as the GPU. This keeps curved output close to the original. |

Some settings use the older, slower paths:

- Wide bloom kernels (selected only by the Royale triad-size defines) use tiled bloom at 4K-sized outputs. Below that size they use raster bloom. A fused pass for these kernels was slower in tests.
- Other graphics APIs use the raster schedule.

## Quality and limits

LeanCRT does not give bit-identical output to the original in all cases. Read this section before you use the shader.

- **Synthetic tests:** 74 of 79 configurations are within one 8-bit level of the original. Four curved or live-transition cases are above one level. The original gives different results between runs in the same cases, so these cases do not show a LeanCRT regression.
- **Real game test:** 8 of 16 configurations are within one level. All flat 4K cases pass. At 1080p, a few pixels in near-black areas differ by two levels (58 of 6,220,800 pixels in the town scene). Curved motion reaches six levels. Motion with live settings changes reaches nine levels. The cause is not known.
- **Hardware:** All tests used one GPU (RTX 5060 Ti) on Windows with D3D11 and SDR output. The fused pass copies the way this GPU rounds numbers. We measured that behavior on this GPU only. On a different GPU, set `LEAN_UNORM16_ROP_OFFSET` in `Shaders/leancrt/pipeline.fxh`. A wrong value gives two-level and three-level errors in near-black ramps.
- **Not tested:** other GPUs, Vulkan, OpenGL, HDR and 10-bit backbuffers, combat scenes, long play sessions and other games.

The benchmarks came from a private D3D11 test harness. It compiles the FX files and times them with GPU timestamps. The harness is not in this repository.

## Install

1. Copy the contents of `Shaders/` into your ReShade shader search directory. This is usually `reshade-shaders/Shaders`.
2. Reload the effects in ReShade and enable `LeanCRT`.
3. Disable the original CRT Royale technique when you compare the two shaders. Both effects can load together.
4. Set the content size and the Royale controls as usual. Enable Performance Mode after you edit the settings.

The shader was tested with ReShade 6.6.2 (64-bit). The fast path needs D3D11.

### Migrate a preset

- Copy the settings from the `[crt-royale.fx]` section into a `[LeanCRT.fx]` section.
- Use `LeanCRT@LeanCRT.fx` in the technique list.
- The content-box defines (`CONTENT_WIDTH`, `CONTENT_HEIGHT`, `CONTENT_CENTER_X`, `CONTENT_CENTER_Y`) work as before.
- The output always fills the backbuffer. The area outside the content box is black. This is also true when `USE_VERTEX_UNCROPPING` is defined.
- `CONTENT_BOX_VISIBLE` shows a preview of the content box.

## Repository layout

| Path | Content |
| --- | --- |
| `Shaders/LeanCRT.fx` | The one entry point and the technique. |
| `Shaders/leancrt/resources.fxh` | Texture layout. All textures use `leanTex*` names, so they do not collide with the original effect. |
| `Shaders/leancrt/pipeline.fxh` | Render passes, and the 16-bit conversion and texture-tap rounding rules. |
| `Shaders/leancrt/fused-bloom.fxh` | The fused compute pass. |
| `Shaders/leancrt/tiled-bloom.fxh` | Tiled bloom for wide kernels. |
| `Shaders/leancrt/royale/` | Unmodified helper headers from akgunter's v2.1.0 source. |
| `Shaders/leancrt/ReShade.fxh` | ReShade header (CC0). |

## Credits and license

LeanCRT is free software under GPL-2.0-or-later. See [LICENSE](LICENSE).

- CRT Royale: TroggleMonkey (copyright 2014).
- ReShade port: [Alex Gunter](https://github.com/akgunter/crt-royale-reshade), commit `7ca7f7cbb7e7d016ca1756d0855879c3b7d0cc05` (v2.1.0). The files in `Shaders/leancrt/royale/` keep their original notices.
- `ReShade.fxh`: Patrick Mours, CC0-1.0, from [crosire/reshade-shaders](https://github.com/crosire/reshade-shaders).
