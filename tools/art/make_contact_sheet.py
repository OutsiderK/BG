#!/usr/bin/env python3
"""Build a contact sheet for AI visual QA.

Layout:

- One row per animation row in the manifest.
- Row label (row name + frame count) rendered on the left.
- All frames placed side-by-side at native resolution.
- Optional ``--with-base`` shows the canonical base pose in a header band.

The contact sheet exists for one purpose: let Claude/Codex (or a human) look at
all frames at once and judge identity consistency across rows.

Outputs ``qa/contact_sheet.png`` and ``qa/identity_strip.png`` (header band).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

LABEL_WIDTH = 160
HEADER_HEIGHT = 32
PADDING = 8
BACKGROUND_RGB = (24, 28, 36)
LABEL_RGB = (220, 220, 220)


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def _load_pillow():
    try:
        from PIL import Image, ImageDraw  # type: ignore
        return Image, ImageDraw
    except ImportError:
        fail("Pillow is required. Install with: pip install Pillow")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build contact sheet for AI visual QA.")
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--with-base", action="store_true", help="Render base pose at top.")
    parser.add_argument("--output", help="Default <run-dir>/qa/contact_sheet.png")
    args = parser.parse_args()

    Image, ImageDraw = _load_pillow()
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
    cols = manifest["grid"][0]

    header_height = HEADER_HEIGHT
    base_band_height = 0
    base_img = None
    if args.with_base:
        base_selected = run_dir / "base" / "selected.png"
        if base_selected.exists():
            base_img = Image.open(base_selected).convert("RGBA")
            base_band_height = base_img.height + PADDING * 2 + 24
        else:
            print("WARN: --with-base set but base/selected.png missing")

    body_height = sum(cell_h + PADDING for _ in manifest["rows"])
    width = LABEL_WIDTH + cols * cell_w + PADDING * 3
    height = header_height + base_band_height + body_height + PADDING

    sheet = Image.new("RGB", (width, height), BACKGROUND_RGB)
    draw = ImageDraw.Draw(sheet)

    # Header
    draw.text((PADDING, PADDING), f"{manifest['subject']} v{manifest['version']} - contact sheet", fill=LABEL_RGB)

    cursor_y = header_height
    if base_img is not None:
        draw.text((PADDING, cursor_y), "BASE (canonical pose)", fill=LABEL_RGB)
        sheet.paste(base_img, (LABEL_WIDTH, cursor_y + 16), base_img)
        cursor_y += base_band_height

    for row in manifest["rows"]:
        atlas_row = row["atlas_row"]
        frame_count = row["frame_count"]
        label = f"{row['name']}\nframes={frame_count}\nmethod={row.get('method', 'generate')}"
        draw.multiline_text((PADDING, cursor_y + 4), label, fill=LABEL_RGB)
        for col in range(frame_count):
            cell = atlas.crop((col * cell_w, atlas_row * cell_h, (col + 1) * cell_w, (atlas_row + 1) * cell_h))
            sheet.paste(cell, (LABEL_WIDTH + col * cell_w, cursor_y), cell)
        cursor_y += cell_h + PADDING

    output_path = Path(args.output) if args.output else run_dir / "qa" / "contact_sheet.png"
    if not output_path.is_absolute():
        output_path = ROOT / output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)

    # Identity strip: base + idle frame 0 + first frame of every row, lined up.
    identity_path = run_dir / "qa" / "identity_strip.png"
    samples = []
    if base_img is not None:
        samples.append(("base", base_img))
    for row in manifest["rows"]:
        cell = atlas.crop((0, row["atlas_row"] * cell_h, cell_w, (row["atlas_row"] + 1) * cell_h))
        samples.append((row["name"], cell))
    if samples:
        strip_h = max(s[1].height for s in samples) + 24
        strip_w = sum(s[1].width + PADDING for s in samples) + PADDING
        strip = Image.new("RGB", (strip_w, strip_h), BACKGROUND_RGB)
        sx = PADDING
        sdraw = ImageDraw.Draw(strip)
        for name, img in samples:
            strip.paste(img, (sx, 20), img if img.mode == "RGBA" else None)
            sdraw.text((sx, 4), name, fill=LABEL_RGB)
            sx += img.width + PADDING
        strip.save(identity_path)

    print(json.dumps({
        "contact_sheet": str(output_path.relative_to(ROOT)),
        "identity_strip": str(identity_path.relative_to(ROOT)),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
