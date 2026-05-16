#!/usr/bin/env python3
"""Compose final sprite sheet atlas from decoded row frames.

Reads ``decoded/<row>/frame-*.png`` for every row in ``jobs.json`` and places
them into an N-cols × M-rows grid. Writes:

- ``final/spritesheet.png``: the atlas
- ``final/manifest.json``: per-row metadata (start cell, frame count, fps)

Rows that are ``method=mirror`` or ``method=reverse`` are expected to already
have their decoded frames populated by ``derive_mirrored_row.py`` before this
script runs.
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Compose sprite sheet atlas.")
    parser.add_argument("--run-dir", required=True, help="Run directory (containing decoded/ and jobs.json)")
    parser.add_argument("--grid", nargs=2, type=int, required=True, metavar=("COLS", "ROWS"))
    parser.add_argument("--cell-size", nargs=2, type=int, required=True, metavar=("W", "H"))
    parser.add_argument("--output", help="Output atlas path; default <run-dir>/final/spritesheet.png")
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    if not run_dir.is_absolute():
        run_dir = ROOT / run_dir
    if not run_dir.exists():
        fail(f"Run directory not found: {run_dir}")

    jobs_path = run_dir / "jobs.json"
    if not jobs_path.exists():
        fail(f"jobs.json missing in run dir: {run_dir}")
    state = json.loads(jobs_path.read_text(encoding="utf-8"))

    cols, rows_in_grid = args.grid
    cell_w, cell_h = args.cell_size
    Image = _load_pillow()
    atlas = Image.new("RGBA", (cols * cell_w, rows_in_grid * cell_h), (0, 0, 0, 0))

    decoded_root = run_dir / "decoded"

    manifest: dict[str, Any] = {
        "subject": state["subject"],
        "version": state["version"],
        "cell_size": [cell_w, cell_h],
        "grid": [cols, rows_in_grid],
        "frame_rate": state.get("frame_rate", 12),
        "rows": [],
    }

    for row_index, row in enumerate(state["rows"]):
        if row_index >= rows_in_grid:
            fail(f"Grid only has {rows_in_grid} rows but jobs has {len(state['rows'])} rows")

        row_dir = decoded_root / row["name"]
        if not row_dir.exists():
            fail(f"Decoded dir missing for row '{row['name']}': {row_dir}")
        frame_paths = sorted(row_dir.glob("frame-*.png"), key=lambda p: int(p.stem.split("-")[1]))
        if not frame_paths:
            fail(f"No decoded frames for row '{row['name']}' in {row_dir}")
        if len(frame_paths) > cols:
            fail(f"Row '{row['name']}' has {len(frame_paths)} frames but atlas grid only has {cols} columns")

        for col_index, fp in enumerate(frame_paths):
            frame = Image.open(fp).convert("RGBA")
            if frame.size != (cell_w, cell_h):
                fail(f"Frame size mismatch in '{row['name']}' frame {col_index}: got {frame.size}, want {(cell_w, cell_h)}")
            atlas.paste(frame, (col_index * cell_w, row_index * cell_h), frame)

        manifest["rows"].append({
            "name": row["name"],
            "atlas_row": row_index,
            "frame_count": len(frame_paths),
            "method": row.get("method", "generate"),
        })

    output_path = Path(args.output) if args.output else run_dir / "final" / "spritesheet.png"
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path)

    manifest_path = output_path.parent / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps({
        "atlas": str(output_path.relative_to(ROOT)),
        "manifest": str(manifest_path.relative_to(ROOT)),
        "row_count": len(manifest["rows"]),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
