# v0.1 Agent Prompts

把下面对应 prompt 发给独立 agent。每个 agent 只负责自己的文件范围，不要回滚其他人的改动。

## Agent G：玩家受击与死亡状态

你在 `/home/coder/workspace/Work/CBZ` 的 Godot 4 项目中工作。请从 `feat/demo-v0-integration` 创建分支 `feat/v0-1-player-state`。

任务：实现 v0.1 玩家受击与死亡状态。只修改 `game/scripts/player/player_controller.gd`、`game/scenes/player/Player.tscn`，可新增 `tools/godot/player_state_smoke.gd`。不要修改敌人、攻击、房间、HUD 主逻辑。

要求：

- 玩家受击后有短暂无敌视觉反馈。
- 玩家死亡后锁定移动、跳跃、冲刺、攻击、展开输入。
- 受击时有轻量击退或速度打断。
- 保持现有输入键位和展开逻辑。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

提交信息：`feat: 完善玩家受击与死亡状态`

## Agent H：敌人攻击可读性

你在 `/home/coder/workspace/Work/CBZ` 的 Godot 4 项目中工作。请从 `feat/demo-v0-integration` 创建分支 `feat/v0-1-enemy-telegraph`。

任务：实现 v0.1 敌人攻击可读性。只修改 `game/scripts/enemies/enemy_base.gd`、`game/scenes/enemies/DummyEnemy.tscn`，可新增 `tools/godot/enemy_attack_smoke.gd`。不要修改玩家、攻击、房间、HUD 主逻辑。

要求：

- 敌人攻击前摇有视觉预警。
- 前摇期间被攻击可以被打断或明显延后。
- 攻击窗口和冷却清晰。
- 保留现有横版追击和展开追击。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/enemy_ai_smoke.gd
```

提交信息：`feat: 增加敌人攻击预警`

## Agent I：命中反馈与战斗可感知性

你在 `/home/coder/workspace/Work/CBZ` 的 Godot 4 项目中工作。请从 `feat/demo-v0-integration` 创建分支 `feat/v0-1-combat-feedback`。

任务：实现 v0.1 命中反馈。只修改 `game/scripts/combat/sword_attack.gd`、`game/scenes/combat/SwordAttack.tscn`，可新增 `game/scripts/fx/`、`game/scenes/fx/`。不要修改玩家主控制、敌人主 AI、房间逻辑。

要求：

- 剑命中敌人时有短命中停顿。
- 命中时生成临时伤害数字或轻量视觉反馈。
- 空挥不触发命中反馈。
- 击退方向稳定。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

提交信息：`feat: 添加近战命中反馈`

## Agent J：相机跟随与屏幕反馈

你在 `/home/coder/workspace/Work/CBZ` 的 Godot 4 项目中工作。请从 `feat/demo-v0-integration` 创建分支 `feat/v0-1-camera-feedback`。

任务：实现 v0.1 相机跟随和屏幕反馈。只修改 `game/scenes/main/Main.tscn`、`game/scripts/main/main.gd`，可新增 `game/scripts/camera/`。不要修改玩家、敌人、攻击、房间逻辑。

要求：

- 添加 Camera2D 跟随玩家。
- 相机限制在当前 demo 房间范围。
- 提供轻量 shake 方法，后续可以被命中或受击调用。
- Godot headless 可加载。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

提交信息：`feat: 添加相机跟随与震动接口`
