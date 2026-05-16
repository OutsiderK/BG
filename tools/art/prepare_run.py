#!/usr/bin/env python3
"""Prepare a hatch-* run directory.

Given a subject + version + jobs JSON, create the working directory under
`docs/art/runs/<subject>-<timestamp>/`, copy the jobs spec, materialize
prompts, validate the chosen imagegen backend, and (in mock mode) generate
placeholder strips so downstream scripts can run end-to-end without any
external image API.

This script is part of the AI art pipeline documented in
`docs/art/pipeline/SKILL.md`.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ART_ROOT = ROOT / "docs" / "art"
RUNS_ROOT = ART_ROOT / "runs"
JOBS_ROOT = ART_ROOT / "jobs"
PIPELINE_ROOT = ART_ROOT / "pipeline"

SUPPORTED_BACKENDS = {"codex-imagegen", "openai", "gemini", "imagen", "comfyui", "mock"}


def fail(message: str) -> "Any":
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def info(message: str) -> None:
    print(f"INFO: {message}")


def load_jobs(jobs_path: Path) -> dict:
    if not jobs_path.exists():
        fail(f"Jobs file not found: {jobs_path}")
    try:
        data = json.loads(jobs_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"Jobs JSON invalid: {jobs_path}: {exc}")
    for key in ("subject", "version", "cell_size", "atlas_grid", "base", "rows"):
        if key not in data:
            fail(f"Jobs JSON missing required key: {key}")
    if not isinstance(data["rows"], list) or not data["rows"]:
        fail("Jobs JSON 'rows' must be a non-empty list")
    return data


def detect_backend() -> str:
    backend = os.environ.get("ZHEWEI_IMAGEGEN_BACKEND", "mock").strip().lower()
    if backend not in SUPPORTED_BACKENDS:
        fail(f"Unknown backend: {backend}. Supported: {sorted(SUPPORTED_BACKENDS)}")
    return backend


def validate_backend_ready(backend: str) -> None:
    """Best-effort check that the backend can be invoked.

    For real backends we only verify the relevant env vars exist; we do NOT
    make network calls here (that happens later when generating images).
    For 'mock' we always pass.
    """
    if backend == "mock":
        return
    required_env = {
        "openai": ["OPENAI_API_KEY"],
        "gemini": ["GOOGLE_API_KEY"],
        "imagen": ["GOOGLE_API_KEY"],
        "comfyui": ["COMFYUI_HOST"],
        "codex-imagegen": [],
    }
    for var in required_env.get(backend, []):
        if not os.environ.get(var):
            fail(
                f"Backend '{backend}' requires env var {var}. "
                f"Set it or switch to ZHEWEI_IMAGEGEN_BACKEND=mock for dry-run."
            )


def make_run_dir(subject: str, timestamp: str) -> Path:
    run_dir = RUNS_ROOT / f"{subject}-{timestamp}"
    if run_dir.exists():
        fail(f"Run directory already exists: {run_dir}")
    for sub in ("base", "rows", "decoded", "final", "qa", "qa/previews"):
        (run_dir / sub).mkdir(parents=True, exist_ok=True)
    return run_dir


def materialize_prompts(jobs: dict, run_dir: Path) -> None:
    """Copy prompt templates and overrides into the run dir for reproducibility."""
    base_tpl = PIPELINE_ROOT / "prompts" / "_base_template.md"
    row_tpl = PIPELINE_ROOT / "prompts" / "_row_template.md"
    for tpl in (base_tpl, row_tpl):
        if not tpl.exists():
            fail(f"Prompt template missing: {tpl}")
        shutil.copy(tpl, run_dir / ("prompts_" + tpl.name.lstrip("_")))

    override_rel = jobs.get("prompt_overrides")
    if override_rel:
        override_path = ROOT / override_rel
        if override_path.exists():
            shutil.copy(override_path, run_dir / "prompt_overrides.txt")
        else:
            info(f"prompt_overrides declared but not found: {override_path} (skipped)")


def init_state(jobs: dict, run_dir: Path, backend: str) -> dict:
    state = {
        "subject": jobs["subject"],
        "version": jobs["version"],
        "backend": backend,
        "started_at": _dt.datetime.utcnow().isoformat() + "Z",
        "cell_size": jobs["cell_size"],
        "atlas_grid": jobs["atlas_grid"],
        "frame_rate": jobs.get("frame_rate", 12),
        "base": {"status": "pending", "selected_path": None, "candidates": []},
        "rows": [],
    }
    for row in jobs["rows"]:
        state["rows"].append({
            "name": row["name"],
            "frames": row.get("frames"),
            "method": row.get("method", "generate"),
            "deps": row.get("deps", []),
            "from": row.get("from"),
            "status": "pending",
            "strip_path": None,
            "decoded_paths": [],
            "qa_notes": [],
            "attempts": 0,
        })
    (run_dir / "jobs.json").write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    return state


def write_mock_strip(strip_path: Path, frames: int, cell_w: int, cell_h: int, row_name: str) -> None:
    """Generate a placeholder horizontal strip with frame numbers, no external deps.

    The placeholder body sits with at least a 12px safe margin from the cell
    edge so that validate_atlas.py's 8px edge-alpha check still passes against
    mock output. This lets CI verify the pipeline end-to-end without an image
    model.
    """
    try:
        from PIL import Image, ImageDraw  # type: ignore
    except ImportError:
        fail("Pillow is required. Install with: pip install Pillow")

    margin = 14  # > 8px so validate_atlas passes
    strip = Image.new("RGBA", (cell_w * frames, cell_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(strip)
    for i in range(frames):
        x0 = i * cell_w
        gray = 80 + (i * 20) % 80
        draw.rectangle(
            [x0 + margin, margin, x0 + cell_w - margin, cell_h - margin],
            fill=(gray, gray, gray, 255),
        )
        label = f"{row_name}\n#{i}"
        draw.multiline_text((x0 + margin + 4, margin + 4), label, fill=(255, 255, 255, 255))
    strip_path.parent.mkdir(parents=True, exist_ok=True)
    strip.save(strip_path)


def generate_mock_assets(jobs: dict, state: dict, run_dir: Path) -> None:
    """In mock mode, populate base + every row's strip so downstream scripts succeed."""
    cell_w, cell_h = jobs["cell_size"]

    # mock base
    try:
        from PIL import Image, ImageDraw  # type: ignore
    except ImportError:
        fail("Pillow is required. Install with: pip install Pillow")
    base_size = tuple(jobs["base"].get("size", [cell_w * 4, cell_h * 4]))
    base = Image.new("RGBA", base_size, (0, 0, 0, 0))
    margin = max(16, base_size[0] // 16)
    ImageDraw.Draw(base).rectangle(
        [margin, margin, base_size[0] - margin, base_size[1] - margin],
        fill=(128, 128, 128, 255),
    )
    selected = run_dir / "base" / "selected.png"
    base.save(selected)
    state["base"]["status"] = "complete"
    state["base"]["selected_path"] = str(selected.relative_to(ROOT))

    # mock each row strip
    for row in state["rows"]:
        if row["method"] in ("mirror", "reverse"):
            # these are derived later; skip mock strip
            row["status"] = "awaiting-derive"
            continue
        strip_path = run_dir / "rows" / row["name"] / "strip.png"
        write_mock_strip(strip_path, row["frames"], cell_w, cell_h, row["name"])
        row["strip_path"] = str(strip_path.relative_to(ROOT))
        row["status"] = "strip-ready"

    (run_dir / "jobs.json").write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    info(f"Mock assets generated under {run_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare a hatch-* run directory.")
    parser.add_argument("--subject", required=True, help="Subject name (e.g. player_saint)")
    parser.add_argument("--version", required=True, help="Subject version (e.g. v0.3)")
    parser.add_argument("--jobs", help="Path to jobs JSON; default docs/art/jobs/<subject>_<version>.json")
    parser.add_argument("--backend", help="Override backend; default reads ZHEWEI_IMAGEGEN_BACKEND env var")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs without creating run dir")
    args = parser.parse_args()

    jobs_path = Path(args.jobs) if args.jobs else JOBS_ROOT / f"{args.subject}_{args.version}.json"
    if not jobs_path.is_absolute():
        jobs_path = ROOT / jobs_path

    jobs = load_jobs(jobs_path)
    if jobs["subject"] != args.subject:
        fail(f"Jobs file subject '{jobs['subject']}' != --subject '{args.subject}'")
    if jobs["version"] != args.version:
        fail(f"Jobs file version '{jobs['version']}' != --version '{args.version}'")

    backend = (args.backend or detect_backend()).lower()
    validate_backend_ready(backend)
    info(f"Backend: {backend}")

    if args.dry_run:
        info("Dry run OK; not creating run directory.")
        return

    timestamp = _dt.datetime.now().strftime("%Y%m%dT%H%M%S")
    run_dir = make_run_dir(args.subject, timestamp)
    info(f"Run dir: {run_dir.relative_to(ROOT)}")

    materialize_prompts(jobs, run_dir)
    state = init_state(jobs, run_dir, backend)

    if backend == "mock":
        generate_mock_assets(jobs, state, run_dir)

    print(json.dumps({"run_dir": str(run_dir.relative_to(ROOT)), "backend": backend, "subject": args.subject}, ensure_ascii=False))


if __name__ == "__main__":
    main()
