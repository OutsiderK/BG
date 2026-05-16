# Agent B: Player Controller

## Branch

`feat/player-controller`

## Goal

实现 Demo v0 的玩家横版移动、俯视移动、冲刺、受击、死亡信号和与展开系统的最小对接。

## Owned Files

- `game/scripts/player/player_controller.gd`
- `game/scenes/player/Player.tscn`
- 可新增：`game/scripts/player/**`

## Do Not Touch

- `project.godot`
- `game/scripts/unfold/**`
- `game/scripts/enemies/**`
- `game/scripts/ui/**`
- `game/scenes/main/Main.tscn`，除非只调整 Player 节点暴露属性

## Tasks

1. 横版状态：A/D 移动，W 跳跃，重力，落地判断。
2. 俯视展开状态：WASD 平面移动，无跳跃高度概念。
3. 空格冲刺：最多 2 连发，起手 0.2 秒无敌，短冷却。
4. 受击：扣血、0.5 秒受击无敌、每次受击 +5 圣痕热度。
5. 展开中受击：调用 `UnfoldManager.end_unfold("collapse")`。
6. 血量归零：发出 `died` 信号，不直接处理死亡结算。

## Acceptance

- 玩家脚本不直接修改彻底死亡概率，只通过 `RunState`/`UnfoldManager` 接口。
- `python3 tools/verify_scaffold.py` 通过。
- 如果能运行 Godot：玩家可在主场景中移动、跳跃、按 `1` 触发展开状态切换。

