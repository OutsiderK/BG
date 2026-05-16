# Agent A: Project Foundation

## Branch

`feat/project-foundation`

## Goal

把 Godot 工程骨架稳定下来，确保项目能被 Godot 4 打开，基础 autoload、输入映射、目录结构和校验脚本可用。

## Owned Files

- `project.godot`
- `AGENTS.md`
- `tools/verify_scaffold.py`
- `game/scripts/core/balance.gd`
- `game/scenes/main/Main.tscn`
- `game/scripts/main/main.gd`
- `game/data/**`
- `docs/agents/**`

## Do Not Touch

- `game/scripts/player/**`
- `game/scripts/enemies/**`
- `game/scripts/unfold/**`
- `game/scripts/ui/**`

## Tasks

1. 检查 `project.godot` 是否能作为 Godot 4 项目入口。
2. 确认 input actions：`move_left/right/up/down`、`dash`、`attack`、`special`、`interact`、`unfold`。
3. 确认 autoload 顺序：`Balance`、`RunState`、`UnfoldManager`。
4. 完善 `tools/verify_scaffold.py`，让它能检查关键文件、输入映射和核心常量。
5. 不实现玩法，只保证其他 agent 有稳定落点。

## Acceptance

- `python3 tools/verify_scaffold.py` 通过。
- `project.godot` 中 `unfold` 是按键 `1`，`interact` 是 `E`。
- 无 Godot 导入产物或本地配置被提交。

