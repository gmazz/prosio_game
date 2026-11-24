#!/bin/bash
set -euo pipefail

# Local installation and the root containing the Hugging Face models--* folders.
TRELLIS2MLX_DIR="${TRELLIS2MLX_DIR:-$HOME/Software/trellis2mlx}"
TRELLIS_WEIGHTS_DIR="${TRELLIS_WEIGHTS_DIR:-$HOME/.cache/huggingface/hub}"

workflow_dir="$(cd -- "$(dirname -- "$0")" && pwd)"

usage() {
    cat <<'HELP'
Usage: generate.sh -i IMAGE [-o MODEL] [TRELLIS OPTIONS]
       generate.sh --resume CHECKPOINT_DIR -o MODEL [TRELLIS OPTIONS]

  -h, --help              Show this help.
  -i, --image IMAGE       Generate one textured 3D model from this image.
  -o, --output MODEL      Write this path, adding .glb if needed.
                          Default: img2model/output/<image stem>.glb.
  --save-checkpoints DIR  Save intermediates for re-export.
  --resume DIR            Re-export a completed mesh and texture checkpoint.

Common TRELLIS options and defaults:
  --seed N                Random seed (42).
  --steps N               Sampler steps (12).
  --resolution N          Cascade grid size (1024). Try 768 for detail.
  --no-cascade            Use one 512 pass and ignore --resolution.
  --max-tokens N          Cascade token budget (49152).
  --target-faces N        Simplification target (200000). 0 disables it.
  --texture-size N        Atlas size in pixels (1024).
  --uv-method METHOD      auto, xatlas, lscm or cube (auto).
  --texture-backend MODE  gpu or cpu (gpu).
  --quantize BITS         Flow weight quantization: 0, 4 or 8 (0).
  --no-rembg              Skip automatic background removal.
  --simplify-first        Simplify before cleanup.
  --no-hole-fill          Skip hole filling.
  --keep-largest          Keep only the largest connected component.
  --repair-exterior-surface
                          Repair exterior orientation when unambiguous.

Other full TRELLIS option names are forwarded to the installed generator.
Explicit paths are relative to your current directory. Existing GLBs are
protected. Edit TRELLIS2MLX_DIR and TRELLIS_WEIGHTS_DIR at the top of this
script or set them in the environment.
HELP
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

input=
output=
resume=
needs_cascade=1
args=()
while (( $# )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -i|--image|-o|--output|--resume)
            [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || die "$1 needs a path"
            case "$1" in
                -i|--image) input="$2" ;;
                -o|--output) output="$2" ;;
                --resume) resume="$2" ;;
            esac
            shift 2
            ;;
        --image=*|--output=*|--resume=*)
            die "Use a separate path argument after ${1%%=*}"
            ;;
        --no-cascade)
            needs_cascade=0
            args+=("$1")
            shift
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

if [[ -n "$resume" ]]; then
    [[ -z "$input" && -n "$output" ]] || die "--resume requires -o and cannot be combined with -i"
    [[ -s "$resume/mesh_raw.npz" && -s "$resume/texture.npz" ]] ||
        die "Resume needs mesh_raw.npz and texture.npz in $resume"
    args+=(--resume "$resume")
else
    [[ -n "$input" ]] || die "Supply an input with -i IMAGE or see -h"
    [[ -f "$input" && -r "$input" ]] || die "Input image is not readable: $input"
    if [[ -z "$output" ]]; then
        filename="${input##*/}"
        stem="${filename%.*}"
        output="$workflow_dir/output/${stem:-$filename}.glb"
    fi
    args+=(--image "$input")
fi

[[ "$output" != */ ]] || die "-o needs a filename"
case "$output" in
    *.[gG][lL][bB]) ;;
    *) output="$output.glb" ;;
esac
[[ ! -e "$output" && ! -L "$output" ]] || die "Output already exists: $output. Choose another path with -o"

trellis_dir="$(cd -- "$TRELLIS2MLX_DIR" && pwd)" ||
    die "TRELLIS.2 MLX checkout missing. See $workflow_dir/README.md"
python="$trellis_dir/.venv/bin/python"
[[ -f "$trellis_dir/generate.py" && -x "$python" ]] ||
    die "TRELLIS.2 MLX checkout or virtual environment incomplete. See $workflow_dir/README.md"

if [[ -z "$resume" ]]; then
    missing_weights=0
    while read -r repo revision file; do
        if [[ "$needs_cascade" = 0 && "$file" = ckpts/slat_flow_img2shape_dit_1_3B_1024_bf16.safetensors ]]; then
            continue
        fi
        path="$TRELLIS_WEIGHTS_DIR/models--${repo//\//--}/snapshots/$revision/$file"
        if [[ ! -f "$path" || ! -r "$path" || ! -s "$path" ]]; then
            printf 'Missing or unreadable weight: %s\n' "$path" >&2
            printf '  HF_HUB_OFFLINE=0 %q download %q %q --revision %q --cache-dir %q\n' \
                "$trellis_dir/.venv/bin/hf" "$repo" "$file" "$revision" "$TRELLIS_WEIGHTS_DIR" >&2
            missing_weights=1
        fi
    done <<'WEIGHTS'
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/ss_flow_img_dit_1_3B_64_bf16.safetensors
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/slat_flow_img2shape_dit_1_3B_512_bf16.safetensors
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/slat_flow_img2shape_dit_1_3B_1024_bf16.safetensors
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/shape_dec_next_dc_f16c32_fp16.safetensors
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/slat_flow_imgshape2tex_dit_1_3B_512_bf16.safetensors
microsoft/TRELLIS.2-4B af44b45f2e35a493886929c6d786e563ec68364d ckpts/tex_dec_next_dc_f16c32_fp16.safetensors
microsoft/TRELLIS-image-large 25e0d31ffbebe4b5a97464dd851910efc3002d96 ckpts/ss_dec_conv3d_16l8_fp16.safetensors
facebook/dinov3-vitl16-pretrain-lvd1689m ea8dc2863c51be0a264bab82070e3e8836b02d51 model.safetensors
WEIGHTS
    (( missing_weights == 0 )) || exit 1
fi

mkdir -p -- "$(dirname -- "$output")"
export TRELLIS_WEIGHTS_DIR HF_HUB_OFFLINE=1
exec "$python" -u "$workflow_dir/run_trellis.py" "$trellis_dir" "${args[@]}" --output "$output"
