# Image to 3D with TRELLIS.2 MLX

Generate one textured GLB from an image on an Apple Silicon Mac. This tool runs independently of the Prosio game. Use a regular macOS terminal so MLX can access Metal.

## Install the engine

1. Install Git with the macOS command line tools if needed. Run `git --version` to check and `xcode-select --install` if Git is unavailable.
2. Install [uv](https://docs.astral.sh/uv/getting-started/installation/). For example, use `brew install uv` if you have Homebrew. Use an arm64 terminal and check that `uname -m` prints `arm64`.
3. Install the pinned [TRELLIS.2 MLX](https://github.com/lyonsno/trellis2mlx) checkout and Python environment. If you already installed this revision, reuse the checkout and its `.venv`.

```bash
export TRELLIS2MLX_DIR="$HOME/Software/trellis2mlx"
mkdir -p "$(dirname "$TRELLIS2MLX_DIR")"
git clone https://github.com/lyonsno/trellis2mlx.git "$TRELLIS2MLX_DIR"
git -C "$TRELLIS2MLX_DIR" checkout 449bfbc011401fe03d684a01f0b1068bfe8f6ceb
cd "$TRELLIS2MLX_DIR"
uv venv --python 3.11 .venv
uv pip install --python .venv/bin/python -e .
.venv/bin/python -c 'import mlx.core as mx; print(mx.default_device()); mx.eval(mx.array([1.0]) + 1)'
```

The probe should report a GPU device. The native MLX route uses the Apple GPU and its Python dependencies are installed in `.venv`.

## Download the weights

Request access on the [DINOv3 model page](https://huggingface.co/facebook/dinov3-vitl16-pretrain-lvd1689m). After approval, create a read-capable Hugging Face token on that account and supply it to `.venv/bin/hf auth login` when prompted. The Microsoft weights listed below total about 12.4 GB, plus the DINOv3 model and background-removal files. Leave room for the virtual environment and any saved runs. See the [Hugging Face CLI guide](https://huggingface.co/docs/huggingface_hub/en/guides/cli) for download options.

Run these from the TRELLIS checkout, with downloads enabled:

```bash
export TRELLIS_WEIGHTS_DIR="$HOME/.cache/huggingface/hub"
export HF_HUB_OFFLINE=0

.venv/bin/hf auth login
.venv/bin/hf download microsoft/TRELLIS.2-4B \
  ckpts/ss_flow_img_dit_1_3B_64_bf16.safetensors \
  ckpts/slat_flow_img2shape_dit_1_3B_512_bf16.safetensors \
  ckpts/slat_flow_img2shape_dit_1_3B_1024_bf16.safetensors \
  ckpts/shape_dec_next_dc_f16c32_fp16.safetensors \
  ckpts/slat_flow_imgshape2tex_dit_1_3B_512_bf16.safetensors \
  ckpts/tex_dec_next_dc_f16c32_fp16.safetensors \
  --revision af44b45f2e35a493886929c6d786e563ec68364d \
  --cache-dir "$TRELLIS_WEIGHTS_DIR"
.venv/bin/hf download microsoft/TRELLIS-image-large \
  ckpts/ss_dec_conv3d_16l8_fp16.safetensors \
  --revision 25e0d31ffbebe4b5a97464dd851910efc3002d96 \
  --cache-dir "$TRELLIS_WEIGHTS_DIR"
.venv/bin/hf download facebook/dinov3-vitl16-pretrain-lvd1689m model.safetensors \
  --revision ea8dc2863c51be0a264bab82070e3e8836b02d51 \
  --cache-dir "$TRELLIS_WEIGHTS_DIR"
.venv/bin/python -c 'from rembg import new_session; new_session("u2net")'
```

The final command warms the U²-Net background-removal cache. Set `TRELLIS2MLX_DIR` and `TRELLIS_WEIGHTS_DIR` in your environment or edit their defaults at the top of `generate.sh`. Set the weights variable to the directory containing the `models--*` folders, as used by `--cache-dir`. Keep the snapshot directories under it. The runner redirects the pinned engine's weight lookup to this path and uses Hugging Face in offline mode during generation.

## Run the CLI

Run the examples from the Prosio repository's `img2model/` folder. Put your reference in `input/`. A full-body, single-subject image with separated limbs and a clean background is a good starting point for a character. A transparent PNG works well.

```bash
./generate.sh -h
./generate.sh -i input/character.png
./generate.sh -i input/character.png -o output/character-preview \
  --no-cascade --seed 42 --steps 8 --target-faces 120000 --texture-size 1024
```

The second command writes `output/character.glb`. The third writes `output/character-preview.glb`. The default output directory is relative to the script, while explicit image, model and checkpoint paths are relative to the terminal's current directory. The runner protects existing GLBs. Both `input/` and `output/` are Git-ignored.

`-h` lists the usual modeling controls. The runner also accepts full option names from the pinned engine. With no modeling flags, TRELLIS uses a 1024 cascade, 12 steps, a 200,000-face simplification target and 1024-pixel textures. A face target controls simplification and the final triangle count can differ. Save checkpoints to test different cleanup, face targets or texture resolutions on the same generated asset.

## Prosio recipes

Use the clean-shaven full-body reference with a transparent background at `input/prosio.png`. The reference used in the measured runs has SHA-256 `828cf81f97a74e57778e0293b4863f861ab644456b99d369fd7de032c04ebe8a`.

| Pass | Resolution | Steps | Seed | Target faces | Texture |
|---|---|---:|---:|---:|---:|
| Screen character inputs and seeds | 512 single pass | 8 | Start at 42 | 120,000 | 1024 |
| Compare a detail candidate | 768 cascade | 12 | Match the selected 512 seed | 200,000 | 2048 |

```bash
./generate.sh -i input/prosio.png -o output/prosio-512-s42 \
  --seed 42 --no-cascade --steps 8 --target-faces 120000 --texture-size 1024 \
  --simplify-first --no-hole-fill --repair-exterior-surface \
  --save-checkpoints output/prosio-512-s42-checkpoints

./generate.sh -i input/prosio.png -o output/prosio-768-s42 \
  --seed 42 --resolution 768 --steps 12 --target-faces 200000 --texture-size 2048 \
  --simplify-first --no-hole-fill --repair-exterior-surface \
  --save-checkpoints output/prosio-768-s42-checkpoints
```

On the M3 Max, the 512 run with seed 42 exported 113,174 triangles in 1m43s. The 768 run with seed 123 exported 176,839 triangles in 5m03s. In Blender the 512 face and belly looked smoother, but the back had a large stray strip. The 768 had a lump at the tail and debris near the hands. These runs used different seeds and finishing settings. Try the matched-seed 768 recipe before choosing a base mesh. To isolate the effect of the cascade, match the steps, face target and texture size too. Inspect the hands, tail attachment and rear silhouette from several angles.

Once a shape is worth keeping, re-export for cleanup and texture comparisons without resampling it. This example tries keeping the largest connected component to remove detached fragments. Compare the result in Blender because a detached detail you want to keep could also be removed, and attached lumps need mesh editing.

```bash
./generate.sh --resume output/prosio-512-s42-checkpoints \
  -o output/prosio-512-s42-largest \
  --target-faces 120000 --texture-size 1024 \
  --simplify-first --no-hole-fill --repair-exterior-surface --keep-largest
```

The generated GLBs are source meshes for cleanup, retopology and rigging. Choose the final game mesh budget after an in-game test at the normal camera distance.

## Troubleshooting

- **No Metal device available.** Run the GPU probe and generation in a regular arm64 macOS terminal with Metal access.
- **Missing weight.** The runner checks the required snapshots before inference and prints targeted `hf download` commands. Use the same `TRELLIS_WEIGHTS_DIR` for installation and generation.
- **DINOv3 access denied.** Complete Meta's approval step, then authenticate the Hugging Face CLI with the approved account. The native model file is loaded from the pinned snapshot.
- **Still waiting to acquire lock.** Check the path printed by the CLI with `lsof 'path-to-lock'`. Let an active download finish or stop its process if it has stalled. To retry over regular HTTP, prefix the download with `HF_HUB_DISABLE_XET=1`. To avoid an old lock while diagnosing, download to a separate fresh `TRELLIS_WEIGHTS_DIR` using `--cache-dir`. Point inference at that directory once all required weights are there.
- **Resume reports missing files.** Finishing needs both `mesh_raw.npz` and `texture.npz`. If texture decoding failed before the texture checkpoint, rerun with `-i`.
