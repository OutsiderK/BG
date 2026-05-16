# Agent E: HUD And Run State

## Branch

`feat/hud-run-state`

## Goal

实现 HUD、死亡结算占位、风险反馈、灾厄侵蚀显示和存档/中断的最小框架。

## Owned Files

- `game/scripts/run/run_state.gd`
- `game/scripts/ui/**`
- `game/scenes/ui/**`
- 可新增：`game/scripts/save/**`
- 可新增：`game/scenes/ui/**`

## Do Not Touch

- `game/scripts/player/**`
- `game/scripts/enemies/**`
- `game/scripts/unfold/**`，除非只连接信号

## Tasks

1. HUD 显示：血量占位、圣痕热度、灰币占位、彻底死亡概率、当前武器占位、冲刺占位、灾厄侵蚀等级。
2. 风险变化时：数字短暂放大或颜色变化占位。
3. 死亡结算占位：显示普通重塑/彻底死亡判定结果。
4. RunState 维护：热度、风险、侵蚀、死亡判定。
5. 自动存档框架占位：每房清理后可调用 `save_run_checkpoint()`。
6. 中途退出续局的数据结构占位。

## Acceptance

- HUD 能响应 RunState 信号。
- 死亡判定可打印或显示结果。
- `python3 tools/verify_scaffold.py` 通过。

