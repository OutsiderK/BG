#!/usr/bin/env python3
"""Render per-row animated GIF previews for AI visual QA.

For each row in ``manifest.json``, render an animated GIF that loops the row's
frames at the manifest's ``frame_rate`` (or override). High-speed rows
(``dash``, ``sword-attack-*``) get bumped to 24 FPS automatically unless
overridden.

Outputs ``qa/previews/<row>.gif``.

GIF is intentionally chosen over MP4 — Pillow ships with GIF writer, no FFmpeg
required, and the resulting files are small enough for AI multimodal review.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

HIGH_SPEED_ROWS = {"dash", "sword-attack-1", "sword-attack-2"}


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
    parser = argparse.ArgumentParser(description="Render animated GIF previews per row.")
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--fps", type=int, help="Override frame rate; defaults to manifest's frame_rate")
    parser.add_argument("--scale", type=int, default=2, help="Integer upscale (default 2x for visibility)")
    args = parser.parse_args()

    Image = _load_pillow()
    run_dir = Path(args.run_dir)
    if not run_dir.is_absolute():
        run_dir = ROOT / run_dir
    manifest_path = run_dir / "final" / "manifest.json"
    atlas_path = run_dir / "final" / "spritesheet.png"
    if not manifest_path.exists() or not atlas_path.exists():
        fail(f"Missing final atlas/manifest under {run_dir}/final/")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    atlas = Image.open(atlas_path).convert("RGBA")
    cell_w, cell_h = manifest["cell_size"]

    base_fps = args.fps if args.fps is not None else manifest.get("frame_rate", 12)
    previews_dir = run_dir / "qa" / "previews"
    previews_dir.mkdir(parents=True, exist_ok=True)

    output_paths = []
    for row in manifest["rows"]:
        row_fps = 24 if row["name"] in HIGH_SPEED_ROWS and args.fps is None else base_fps
        duration_ms = max(1, int(1000 / row_fps))
        frames = []
        for col in range(row["frame_count"]):
            cell = atlas.crop((col * cell_w, row["atlas_row"] * cell_h,
                               (col + 1) * cell_w, (row["atlas_row"] + 1) * cell_h))
            if args.scale > 1:
                cell = cell.resize((cell.width * args.scale, cell.height * args.scale),
                                   resample=Image.NEAREST)
            # GIF wants paletted images; composite over transparent-aware background to avoid trails.
            bg = Image.new("RGB", cell.size, (24, 28, 36))
            bg.paste(cell, (0, 0), cell)
            frames.append(bg.convert("P", palette=Image.ADAPTIVE))

        if not frames:
            print(f"WARN: row '{row['name']}' has no frames, skipping GIF")
            continue
        out_path = previews_dir / f"{row['name']}.gif"
        frames[0].save(out_path, save_all=True, append_images=frames[1:], duration=duration_ms, loop=0, disposal=2)
        output_paths.append(str(out_path.relative_to(ROOT)))

    print(json.dumps({"previews": output_paths, "fps_default": base_fps}, ensure_ascii=False))


if __name__ == "__main__":
    main()
