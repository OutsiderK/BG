#!/usr/bin/env python3
"""Derive a row from another by mirroring or reversing.

Two modes:

- ``--method=mirror``: horizontally flip every frame of the source row.
  Typical use: ``run-left`` from ``run-right``.
- ``--method=reverse``: reverse the time order of the source row.
  Typical use: ``unfold-exit`` from ``unfold-enter``.

Safe to invoke even when the source row is missing — script exits non-zero
with a clear message and Claude/Codex can fall back to generating the row.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def _load_pillow():
    try:
        from PIL import Image, ImageOps  # type: ignore
        return Image, ImageOps
    except ImportError:
        fail("Pillow is required. Install with: pip install Pillow")


def main() -> None:
    parser = argparse.ArgumentParser(description="Derive a row by mirroring or reversing.")
    parser.add_argument("--from-dir", required=True, help="Source row decoded directory")
    parser.add_argument("--to-dir", required=True, help="Target row decoded directory")
    parser.add_argument("--method", choices=["mirror", "reverse"], required=True)
    args = parser.parse_args()

    Image, ImageOps = _load_pillow()
    src = Path(args.from_dir)
    dst = Path(args.to_dir)
    if not src.is_absolute():
        src = ROOT / src
    if not dst.is_absolute():
        dst = ROOT / dst
    if not src.exists():
        fail(f"Source row directory missing: {src}")

    src_frames = sorted(src.glob("frame-*.png"), key=lambda p: int(p.stem.split("-")[1]))
    if not src_frames:
        fail(f"Source row has no frames: {src}")

    dst.mkdir(parents=True, exist_ok=True)

    if args.method == "mirror":
        for idx, fp in enumerate(src_frames):
            img = Image.open(fp).convert("RGBA")
            mirrored = ImageOps.mirror(img)
            mirrored.save(dst / f"frame-{idx}.png")
    else:  # reverse
        total = len(src_frames)
        for idx, fp in enumerate(src_frames):
            img = Image.open(fp).convert("RGBA")
            img.save(dst / f"frame-{total - 1 - idx}.png")

    print(f"OK: derived {len(src_frames)} frames via {args.method} from {src.relative_to(ROOT)} to {dst.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
