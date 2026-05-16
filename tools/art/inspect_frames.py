#!/usr/bin/env python3
"""Inspect extracted frames for quality issues.

Checks (per row):

- Transparent background: edge 8px of each frame should be < 5% alpha.
- Foot/center anchor drift: compute center-of-mass of opaque pixels for each
  frame and report drift relative to frame 0.
- Empty frame detection: opaque pixel ratio < 1% counts as empty.

Outputs ``qa/inspect_<row>.json`` summarizing findings.

Failures are reported but not fatal here — the strict gate lives in
``validate_atlas.py`` after atlas composition. This script gives Claude/Codex
visibility to decide row-by-row repairs.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

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


def edge_alpha_ratio(image, margin: int) -> float:
    """Fraction of edge pixels (within ``margin``) that are non-transparent."""
    w, h = image.size
    total = 0
    opaque = 0
    for x in range(w):
        for y in (list(range(margin)) + list(range(h - margin, h))):
            total += 1
            if image.getpixel((x, y))[3] > 12:  # alpha threshold ~5%
                opaque += 1
    for y in range(margin, h - margin):
        for x in (list(range(margin)) + list(range(w - margin, w))):
            total += 1
            if image.getpixel((x, y))[3] > 12:
                opaque += 1
    return opaque / max(1, total)


def opaque_ratio(image) -> float:
    w, h = image.size
    total = w * h
    opaque = 0
    for x in range(w):
        for y in range(h):
            if image.getpixel((x, y))[3] > 32:
                opaque += 1
    return opaque / total


def center_of_mass(image) -> tuple[float, float]:
    w, h = image.size
    sx = 0.0
    sy = 0.0
    weight = 0.0
    for x in range(w):
        for y in range(h):
            a = image.getpixel((x, y))[3] / 255.0
            sx += x * a
            sy += y * a
            weight += a
    if weight == 0:
        return (w / 2, h / 2)
    return (sx / weight, sy / weight)


def main() -> None:
    parser = argparse.ArgumentParser(description="Inspect extracted frames for quality issues.")
    parser.add_argument("--row-dir", required=True, help="Directory containing frame-N.png files")
    parser.add_argument("--row-name", required=True)
    parser.add_argument("--edge-margin", type=int, default=8)
    parser.add_argument("--output", required=True, help="Output JSON path")
    args = parser.parse_args()

    Image = _load_pillow()
    row_dir = Path(args.row_dir)
    if not row_dir.is_absolute():
        row_dir = ROOT / row_dir
    if not row_dir.exists():
        fail(f"Row directory not found: {row_dir}")

    frame_paths = sorted(row_dir.glob("frame-*.png"), key=lambda p: int(p.stem.split("-")[1]))
    if not frame_paths:
        fail(f"No frames found under {row_dir}")

    result: dict[str, Any] = {
        "row": args.row_name,
        "frame_count": len(frame_paths),
        "issues": [],
        "frames": [],
    }

    ref_com: tuple[float, float] | None = None
    for idx, fp in enumerate(frame_paths):
        img = Image.open(fp).convert("RGBA")
        edge = edge_alpha_ratio(img, args.edge_margin)
        opaque = opaque_ratio(img)
        com = center_of_mass(img)
        if ref_com is None:
            ref_com = com
        drift = ((com[0] - ref_com[0]) ** 2 + (com[1] - ref_com[1]) ** 2) ** 0.5

        frame_info = {
            "index": idx,
            "path": str(fp.relative_to(ROOT)),
            "edge_alpha_ratio": round(edge, 4),
            "opaque_ratio": round(opaque, 4),
            "center_of_mass": [round(com[0], 2), round(com[1], 2)],
            "drift_px": round(drift, 2),
            "warnings": [],
        }
        if edge > 0.05:
            frame_info["warnings"].append("non_transparent_edge")
            result["issues"].append(f"frame {idx}: edge alpha {edge:.3f} exceeds 5%")
        if opaque < 0.01:
            frame_info["warnings"].append("empty_frame")
            result["issues"].append(f"frame {idx}: opaque ratio {opaque:.3f} below 1%")
        if drift > 2.0 and idx > 0:
            frame_info["warnings"].append("anchor_drift")
            result["issues"].append(f"frame {idx}: anchor drift {drift:.2f}px exceeds 2px")
        result["frames"].append(frame_info)

    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps({"row": args.row_name, "issues": len(result["issues"]), "report": str(output_path.relative_to(ROOT))}, ensure_ascii=False))


if __name__ == "__main__":
    main()
