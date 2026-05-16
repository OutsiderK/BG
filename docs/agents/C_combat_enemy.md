# Agent C: Combat And Enemy

## Branch

`feat/combat-enemy`

## Goal

实现最小战斗闭环：剑普攻、命中判定、敌人受伤死亡、命中停顿/击退占位，以及一个普通敌人。

## Owned Files

- `game/scripts/enemies/**`
- `game/scenes/enemies/**`
- 可新增：`game/scripts/combat/**`
- 可新增：`game/scenes/combat/**`
- 可新增：`game/data/enemies/**`
- 可新增：`game/data/weapons/**`

## Do Not Touch

- `project.godot`
- `game/scripts/unfold/**`
- `game/scripts/ui/**`
- `game/scripts/player/player_controller.gd`，除非只连接攻击接口且在 PR 中说明

## Tasks

1. 实现敌人基础属性：HP、伤害、死亡信号。
2. 实现 `apply_damage(amount)`，死亡时给圣痕热度击杀奖励。
3. 实现剑的最小普攻命中区域。
4. 普攻命中给 +2 圣痕热度。
5. 普通敌人能被 2-3 次攻击击杀，匹配 `spec_数值基线.md`。
6. 为后续锚钉修士预留反展开攻击接口，但 Demo v0 可先不做。

## Acceptance

- 剑能打死 DummyEnemy 或普通敌人。
- 敌人死亡后不复活。
- `python3 tools/verify_scaffold.py` 通过。

