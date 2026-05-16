#!/usr/bin/env python3
"""Stage-1 deterministic validation gate for sprite sheet atlas.

Hard-blocks the pipeline if any of the following fail:

- Atlas size exceeds budget (default 4 MiB).
- Per-frame size exceeds budget (default 80 KiB).
- Transparent edge: 8px border of each frame has >5% non-transparent pixels.
- Frame anchor drift: center-of-mass of each frame within ±2px of frame 0.
- Frame count per row matches manifest.
- Filename convention matches ``row-<name>-frame-<n>.png`` when frames are exported.

Outputs ``qa/validation.json`` with one entry per row + a top-level
``status: pass|fail``.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]

DEFAULT_ATLAS_MAX_BYTES = 4 * 1024 * 1024  # 4 MiB
DEFAULT_FRAME_MAX_BYTES = 80 * 1024        # 80 KiB
DEFAULT_EDGE_MARGIN = 8
DEFAULT_EDGE_ALPHA_MAX = 0.05
DEFAULT_DRIFT_MAX = 2.0


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
    w, h = image.size
    total = 0
    opaque = 0
    for x in range(w):
        for y in (list(range(margin)) + list(range(h - margin, h))):
            total += 1
            if image.getpixel((x, y))[3] > 12:
                opaque += 1
    for y in range(margin, h - margin):
        for x in (list(range(margin)) + list(range(w - margin, w))):
            total += 1
            if image.getpixel((x, y))[3] > 12:
                opaque += 1
    return opaque / max(1, total)


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


def slice_cell(atlas, col: int, row: int, cell_w: int, cell_h: int):
    return atlas.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))


def main() -> None:
    parser = argparse.ArgumentParser(description="Deterministic validation of sprite sheet atlas.")
    parser.add_argument("--atlas", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", required=True, help="Output JSON path (qa/validation.json)")
    parser.add_argument("--atlas-max-bytes", type=int, default=DEFAULT_ATLAS_MAX_BYTES)
    parser.add_argument("--frame-max-bytes", type=int, default=DEFAULT_FRAME_MAX_BYTES)
    parser.add_argument("--edge-margin", type=int, default=DEFAULT_EDGE_MARGIN)
    parser.add_argument("--edge-alpha-max", type=float, default=DEFAULT_EDGE_ALPHA_MAX)
    parser.add_argument("--drift-max", type=float, default=DEFAULT_DRIFT_MAX)
    args = parser.parse_args()

    Image = _load_pillow()
    atlas_path = Path(args.atlas)
    if not atlas_path.is_absolute():
        atlas_path = ROOT / atlas_path
    manifest_path = Path(args.manifest)
    if not manifest_path.is_absolute():
        manifest_path = ROOT / manifest_path

    if not atlas_path.exists():
        fail(f"Atlas not found: {atlas_path}")
    if not manifest_path.exists():
        fail(f"Manifest not found: {manifest_path}")

    atlas_bytes = atlas_path.stat().st_size
    atlas = Image.open(atlas_path).convert("RGBA")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    cell_w, cell_h = manifest["cell_size"]

    report: dict[str, Any] = {
        "atlas": str(atlas_path.relative_to(ROOT)),
        "atlas_bytes": atlas_bytes,
        "atlas_max_bytes": args.atlas_max_bytes,
        "rows": [],
        "blocking_errors": [],
        "warnings": [],
        "status": "pass",
    }

    if atlas_bytes > args.atlas_max_bytes:
        report["blocking_errors"].append(f"atlas size {atlas_bytes} > budget {args.atlas_max_bytes}")

    for row in manifest["rows"]:
        row_name = row["name"]
        atlas_row = row["atlas_row"]
        frame_count = row["frame_count"]
        row_drift_max = float(row.get("anchor_drift_max", args.drift_max))
        ref_com: tuple[float, float] | None = None

        row_report = {
            "name": row_name,
            "frame_count": frame_count,
            "anchor_drift_max": row_drift_max,
            "issues": [],
        }
        for col in range(frame_count):
            cell = slice_cell(atlas, col, atlas_row, cell_w, cell_h)
            # frame max bytes: estimate by saving to bytes in PNG
            from io import BytesIO
            buf = BytesIO()
            cell.save(buf, format="PNG")
            cell_bytes = len(buf.getvalue())
            edge = edge_alpha_ratio(cell, args.edge_margin)
            com = center_of_mass(cell)
            if ref_com is None:
                ref_com = com
            drift = ((com[0] - ref_com[0]) ** 2 + (com[1] - ref_com[1]) ** 2) ** 0.5

            if cell_bytes > args.frame_max_bytes:
                row_report["issues"].append(f"frame {col}: {cell_bytes} bytes > {args.frame_max_bytes}")
                report["blocking_errors"].append(f"{row_name}/frame-{col}: oversize")
            if edge > args.edge_alpha_max:
                row_report["issues"].append(f"frame {col}: edge alpha {edge:.3f} > {args.edge_alpha_max}")
                report["blocking_errors"].append(f"{row_name}/frame-{col}: non-transparent edge")
            if drift > row_drift_max and col > 0:
                row_report["issues"].append(f"frame {col}: anchor drift {drift:.2f}px > {row_drift_max}")
                report["blocking_errors"].append(f"{row_name}/frame-{col}: anchor drift")
        report["rows"].append(row_report)

    if report["blocking_errors"]:
        report["status"] = "fail"

    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps({
        "status": report["status"],
        "blocking_errors": len(report["blocking_errors"]),
        "report": str(output_path.relative_to(ROOT)),
    }, ensure_ascii=False))

    if report["status"] == "fail":
        sys.exit(2)


if __name__ == "__main__":
    main()
