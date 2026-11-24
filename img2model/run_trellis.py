"""Run the pinned TRELLIS CLI with a configurable Hugging Face cache."""

import os
from pathlib import Path
import runpy
import sys


def main():
    checkout = Path(sys.argv.pop(1))
    cache = Path(os.environ["TRELLIS_WEIGHTS_DIR"]).expanduser().resolve()
    default_cache = "~/.cache/huggingface/hub/"
    dino_snapshots = "models--facebook--dinov3-vitl16-pretrain-lvd1689m/snapshots/"
    dino_revision = "ea8dc2863c51be0a264bab82070e3e8836b02d51"
    expanduser = os.path.expanduser

    def expand_model_path(path):
        # The pinned upstream code uses literal paths for all three model repos.
        if path == default_cache + dino_snapshots:
            return str(cache / dino_snapshots / dino_revision / "model.safetensors")
        if isinstance(path, str) and path.startswith(default_cache + "models--"):
            return os.path.join(cache, path.removeprefix(default_cache))
        return expanduser(path)

    sys.path.insert(0, str(checkout))
    os.path.expanduser = expand_model_path
    try:
        runpy.run_path(str(checkout / "generate.py"), run_name="__main__")
    finally:
        os.path.expanduser = expanduser


if __name__ == "__main__":
    main()
