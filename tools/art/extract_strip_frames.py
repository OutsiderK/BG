#!/usr/bin/env python3
"""Extract individual frames from a horizontal sprite strip.

Two extraction methods:

- ``auto`` (default): infer frame boundaries from alpha distribution. Detects
  empty columns and groups non-empty regions into frames.
- ``stable-slots``: split the strip into ``frames`` equal-width slots. Use this
  when the image generator produced consistent cells but the auto detector
  fails (sparse silhouettes can confuse alpha-based detection).

Outputs one PNG per frame: ``decoded/<row>/frame-<N>.png``.

Part of the AI art pipeline; see ``docs/art/pipeline/SKILL.md``.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def _load_pillow():
    try:
        from PIL import Image  # type: ignore
        return Image
    except ImportError:
        fail("Pillow is required. Install with: pip install Pillow")


def _column_alpha_sum(image, x: int) -> int:
    """Sum of alpha values in column x. Higher = more opaque."""
    total = 0
    for y in range(image.height):
        total += image.getpixel((x, y))[3]
    return total


def detect_auto_boundaries(image, frames: int, cell_w: int) -> list[tuple[int, int]]:
    """Locate ``frames`` non-empty regions along the X axis."""
    width = image.width
    threshold = 5 * image.height  # average alpha of 5 across the column

    in_region = False
    regions: list[tuple[int, int]] = []
    region_start = 0
    for x in range(width):
        opaque = _column_alpha_sum(image, x) > threshold
        if opaque and not in_region:
            in_region = True
            region_start = x
        elif not opaque and in_region:
            in_region = False
            regions.append((region_start, x))
    if in_region:
        regions.append((region_start, width))

    if len(regions) == frames:
        return regions
    if len(regions) < frames:
        return []
    # Too many regions: merge smallest adjacent gaps until we have ``frames`` regions.
    while len(regions) > frames:
        gaps = []
        for i in range(len(regions) - 1):
            gaps.append((regions[i + 1][0] - regions[i][1], i))
        gaps.sort()
        idx = gaps[0][1]
        regions[idx] = (regions[idx][0], regions[idx + 1][1])
        del regions[idx + 1]
    return regions


def stable_slot_boundaries(image, frames: int) -> list[tuple[int, int]]:
    slot_w = image.width // frames
    return [(i * slot_w, (i + 1) * slot_w) for i in range(frames)]


def crop_frame(image, x0: int, x1: int, cell_w: int, cell_h: int):
    """Crop a frame to (cell_w, cell_h), centering content horizontally."""
    Image = _load_pillow()
    sub = image.crop((x0, 0, x1, image.height))
    # If sub is wider/taller than cell, fit into cell preserving aspect.
    if sub.width != cell_w or sub.height != cell_h:
        canvas = Image.new("RGBA", (cell_w, cell_h), (0, 0, 0, 0))
        # scale to fit
        scale = min(cell_w / sub.width, cell_h / sub.height, 1.0)
        if scale < 1.0:
            sub = sub.resize((max(1, int(sub.width * scale)), max(1, int(sub.height * scale))))
        # center paste
        ox = (cell_w - sub.width) // 2
        oy = (cell_h - sub.height) // 2
        canvas.paste(sub, (ox, oy), sub if sub.mode == "RGBA" else None)
        return canvas
    return sub


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract frames from a horizontal sprite strip.")
    parser.add_argument("--strip", required=True, help="Path to input strip PNG")
    parser.add_argument("--frames", type=int, required=True, help="Expected frame count")
    parser.add_argument("--cell-size", nargs=2, type=int, metavar=("W", "H"), required=True)
    parser.add_argument("--method", choices=["auto", "stable-slots"], default="auto")
    parser.add_argument("--allow-stable-slots", action="store_true",
                        help="If --method=auto fails, fall back to stable-slots automatically.")
    parser.add_argument("--output", required=True, help="Output directory")
    args = parser.parse_args()

    Image = _load_pillow()
    strip_path = Path(args.strip)
    if not strip_path.is_absolute():
        strip_path = ROOT / strip_path
    if not strip_path.exists():
        fail(f"Strip not found: {strip_path}")

    image = Image.open(strip_path).convert("RGBA")
    cell_w, cell_h = args.cell_size

    method = args.method
    if method == "auto":
        regions = detect_auto_boundaries(image, args.frames, cell_w)
        if not regions:
            if args.allow_stable_slots:
                print("WARN: auto detection failed, falling back to stable-slots")
                regions = stable_slot_boundaries(image, args.frames)
                method = "stable-slots"
            else:
                fail("Auto detection failed. Re-run with --method stable-slots or pass --allow-stable-slots.")
    else:
        regions = stable_slot_boundaries(image, args.frames)

    output_dir = Path(args.output)
    if not output_dir.is_absolute():
        output_dir = ROOT / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    summary = {"method": method, "strip": str(strip_path.relative_to(ROOT)), "frames": []}
    for i, (x0, x1) in enumerate(regions):
        frame = crop_frame(image, x0, x1, cell_w, cell_h)
        out_path = output_dir / f"frame-{i}.png"
        frame.save(out_path)
        summary["frames"].append({"index": i, "x0": x0, "x1": x1, "path": str(out_path.relative_to(ROOT))})

    summary_path = output_dir / "extract_summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"output_dir": str(output_dir.relative_to(ROOT)), "method": method, "count": len(regions)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
