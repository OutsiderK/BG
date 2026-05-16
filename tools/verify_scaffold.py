#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = [
    "project.godot",
    "game/scenes/main/Main.tscn",
    "game/scenes/player/Player.tscn",
    "game/scenes/enemies/DummyEnemy.tscn",
    "game/scenes/ui/HUD.tscn",
    "game/scripts/core/balance.gd",
    "game/scripts/run/run_state.gd",
    "game/scripts/unfold/unfold_manager.gd",
    "game/scripts/player/player_controller.gd",
    "game/scripts/enemies/enemy_base.gd",
    "game/scripts/rooms/room_lane_profile.gd",
    "game/scripts/ui/hud.gd",
    "game/scripts/main/main.gd",
    "spec_展开机制.md",
    "spec_数值基线.md",
    "spec_流程UI存档引导.md",
    "spec_道具协同参考.md",
]

EXPECTED_BALANCE = {
    "HEAT_BASE_MAX": "100",
    "HEAT_TRIGGER_THRESHOLD": "100",
    "HEAT_DAMAGED": "5",
    "RISK_UNFOLD_FULL": "0.005",
    "RISK_UNFOLD_EARLY": "0.002",
    "RISK_COLLAPSE": "0.01",
    "RISK_CAP_PER_RUN": "0.04",
}

def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)

def main() -> None:
    for rel in REQUIRED_FILES:
        if not (ROOT / rel).exists():
            fail(f"Missing required file: {rel}")

    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    for action in ["move_left", "move_right", "move_up", "move_down", "dash", "attack", "special", "interact", "unfold"]:
        if f"{action}=" not in project:
            fail(f"Missing input action in project.godot: {action}")

    balance = (ROOT / "game/scripts/core/balance.gd").read_text(encoding="utf-8")
    for key, expected in EXPECTED_BALANCE.items():
        pattern = rf"const\s+{key}\s*:=\s*{re.escape(expected)}(?:\.0)?\b"
        if not re.search(pattern, balance):
            fail(f"Balance constant {key} does not match expected value {expected}")

    unfold_spec = (ROOT / "spec_展开机制.md").read_text(encoding="utf-8")
    if "按 1 键" not in unfold_spec or "| E | 道具交互 | 道具交互 |" not in unfold_spec:
        fail("Unfold spec must keep 1 for unfold and E for interact")
    if "敌人映射规则" not in unfold_spec:
        fail("Unfold spec must include enemy mapping rules")

    print("OK: scaffold files and key constants verified")

if __name__ == "__main__":
    main()

