#!/usr/bin/env python3
"""Import a finalized sprite sheet into the Godot project.

Copies the atlas to ``game/art/sprites/<subject>/spritesheet.png`` and emits a
Godot ``SpriteFrames`` resource (``anim.tres``) wired with one animation per
row in the manifest. The resource is hand-written as a text ``.tres`` file —
Godot will pick it up on next editor load and AnimatedSprite2D can reference
it directly.

The generated file uses Godot 4 ``.tres`` syntax. If Godot project version
changes, the resource header (``[gd_resource ...]``) may need updating.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def gen_tres(subject: str, manifest: dict, sheet_godot_path: str) -> str:
    """Build a Godot 4 SpriteFrames .tres text resource."""
    cell_w, cell_h = manifest["cell_size"]
    fps = manifest.get("frame_rate", 12)
    grid_cols, _grid_rows = manifest["grid"]

    high_speed = {"dash", "sword-attack-1", "sword-attack-2"}

    # Count atlas textures we need to declare: one per frame.
    # In Godot 4, SpriteFrames stores frames as Texture2D resources, each
    # frame typically references an AtlasTexture sub-resource.
    sub_resources: list[str] = []
    animations: list[str] = []
    next_id = 1

    # Ext resource for the spritesheet PNG
    sheet_ext_id = "1_sheet"
    ext_block = (
        f'[ext_resource type="Texture2D" path="{sheet_godot_path}" id="{sheet_ext_id}"]\n'
    )

    for row in manifest["rows"]:
        frame_refs: list[str] = []
        row_fps = 24 if row["name"] in high_speed else fps
        loop = row["name"] in {"idle", "run-right", "run-left", "fall", "unfold-loop"}
        for col in range(row["frame_count"]):
            sub_id = f"AtlasTexture_{row['name'].replace('-', '_')}_{col}"
            sub_resources.append(
                f'[sub_resource type="AtlasTexture" id="{sub_id}"]\n'
                f'atlas = ExtResource("{sheet_ext_id}")\n'
                f'region = Rect2({col * cell_w}, {row["atlas_row"] * cell_h}, {cell_w}, {cell_h})\n'
            )
            frame_refs.append(
                "{\n"
                f'\t\t"duration": 1.0,\n'
                f'\t\t"texture": SubResource("{sub_id}")\n'
                "\t}"
            )
        animations.append(
            "{\n"
            f'\t"frames": [{", ".join(frame_refs)}],\n'
            f'\t"loop": {"true" if loop else "false"},\n'
            f'\t"name": &"{row["name"]}",\n'
            f'\t"speed": {row_fps}.0\n'
            "}"
        )

    total_steps = len(sub_resources) + 1  # +1 for the spritesheet ExtResource
    header = f'[gd_resource type="SpriteFrames" load_steps={total_steps} format=3]\n\n'
    body = (
        ext_block + "\n"
        + "\n".join(sub_resources) + "\n"
        + "[resource]\n"
        + "animations = [" + ", ".join(animations) + "]\n"
    )
    return header + body


def main() -> None:
    parser = argparse.ArgumentParser(description="Import sprite sheet into Godot project.")
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--target", help="Default game/art/sprites/<subject>/")
    parser.add_argument("--subject", help="Override subject name; defaults from manifest")
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    if not run_dir.is_absolute():
        run_dir = ROOT / run_dir
    manifest_path = run_dir / "final" / "manifest.json"
    atlas_path = run_dir / "final" / "spritesheet.png"
    if not manifest_path.exists() or not atlas_path.exists():
        fail(f"Missing final atlas/manifest under {run_dir}/final/")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    subject = args.subject or manifest["subject"]

    target = Path(args.target) if args.target else ROOT / "game" / "art" / "sprites" / subject
    if not target.is_absolute():
        target = ROOT / target
    target.mkdir(parents=True, exist_ok=True)

    # Copy atlas
    shutil.copy(atlas_path, target / "spritesheet.png")
    shutil.copy(manifest_path, target / "manifest.json")

    # Generate .tres. Godot paths must use res:// prefix.
    target_rel = target.relative_to(ROOT).as_posix()
    sheet_godot_path = f"res://{target_rel}/spritesheet.png"
    tres = gen_tres(subject, manifest, sheet_godot_path)
    (target / "anim.tres").write_text(tres, encoding="utf-8")

    # Write a small import.json to allow incremental updates / round-trips
    import_meta = {
        "subject": subject,
        "version": manifest["version"],
        "imported_from_run": str(run_dir.relative_to(ROOT)),
        "atlas": f"{target_rel}/spritesheet.png",
        "anim_resource": f"{target_rel}/anim.tres",
    }
    (target / "import.json").write_text(json.dumps(import_meta, indent=2, ensure_ascii=False), encoding="utf-8")

    print(json.dumps({
        "target": target_rel,
        "atlas": import_meta["atlas"],
        "anim_resource": import_meta["anim_resource"],
        "subject": subject,
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
