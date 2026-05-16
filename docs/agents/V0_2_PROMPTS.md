# v0.2 Agent Prompts

把下面对应 prompt 发给独立 agent。每个 agent 必须使用自己的 worktree 路径，不要在主目录 `/home/coder/workspace/Work/CBZ` 直接改代码。

## Agent K：展开/坍缩过渡遮罩

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-2-unfold-transition-fx` 工作。你不是唯一的开发者，当前有多个 worker 并行实现 v0.2；不要回滚其他人的改动，只修改你负责的文件范围。当前分支应为 `feat/v0-2-unfold-transition-fx`。

任务：实现 v0.2 展开/坍缩过渡遮罩。

负责文件：

- `game/scenes/main/Main.tscn`
- `game/scripts/main/main.gd`
- 可新增 `game/scenes/unfold/`
- 可新增 `game/scripts/unfold/unfold_transition_overlay.gd`
- 可新增 `tools/godot/unfold_transition_smoke.gd`

要求：

- 展开进入时显示 0.5s 屏幕压暗、边缘折页/框线、圣纹扩散占位效果。
- 坍缩时显示更短的红色/合拢反馈。
- 过渡视觉通过 `UnfoldManager.unfold_transition_started(kind)`、`unfold_entered`、`unfold_ended(reason)` 驱动。
- 不改 `UnfoldManager` 的状态机核心逻辑。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

如新增 smoke test，也运行它。

提交信息：`feat: 添加展开过渡遮罩`

## Agent L：HUD 展开状态与风险提示

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-2-unfold-hud` 工作。你不是唯一的开发者，当前有多个 worker 并行实现 v0.2；不要回滚其他人的改动，只修改你负责的文件范围。当前分支应为 `feat/v0-2-unfold-hud`。

任务：实现 v0.2 HUD 展开状态与风险提示。

负责文件：

- `game/scripts/ui/hud.gd`
- `game/scenes/ui/HUD.tscn`
- 可新增 `tools/godot/hud_unfold_smoke.gd`

要求：

- HUD 显示当前展开模式：纵平面、展开过渡、展开中、坍缩/冷却。
- 热度满 100 时有可见提示；展开中热度条进入倒计样式。
- 禁展冷却期间显示剩余时间。
- 锚率/侵蚀变化沿用并强化当前风险反馈。
- 不修改展开状态机、玩家、敌人、房间逻辑。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

如新增 smoke test，也运行它。

提交信息：`feat: 增强展开HUD反馈`

## Agent M：lane/落点与房间可读性

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-2-lane-readability` 工作。你不是唯一的开发者，当前有多个 worker 并行实现 v0.2；不要回滚其他人的改动，只修改你负责的文件范围。当前分支应为 `feat/v0-2-lane-readability`。

任务：实现 v0.2 lane/落点与房间可读性。

负责文件：

- `game/scripts/rooms/demo_room.gd`
- `game/scenes/rooms/DemoRoom.tscn`
- 可新增 `tools/godot/lane_mapping_smoke.gd`

要求：

- 展开前后 lane 预览在非展开时弱显示、展开时强显示。
- 玩家/敌人映射到 lane 时生成或更新落点提示。
- 坍缩后显示短暂吸附点提示。
- 使用 `UnfoldManager` 已有信号；如果缺少只读查询，先用现有信号完成，不要改状态机。
- 不改玩家、敌人、HUD 主逻辑。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

如新增 smoke test，也运行它。

提交信息：`feat: 增强展开lane和落点提示`

## Agent N：展开映射验收与边界修正

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-2-unfold-smoke-tests` 工作。你不是唯一的开发者，当前有多个 worker 并行实现 v0.2；不要回滚其他人的改动，只修改你负责的文件范围。当前分支应为 `feat/v0-2-unfold-smoke-tests`。

任务：实现 v0.2 展开映射验收与边界修正。

负责文件：

- `game/scripts/unfold/unfold_manager.gd`
- `game/scripts/unfold/unfold_mapper.gd`
- `game/scripts/rooms/room_lane_profile.gd`
- 可新增 `tools/godot/unfold_mapping_smoke.gd`

要求：

- 增加 headless smoke test：攒满热度、触发展开、验证玩家 X 保留、敌人 lane 分配、主动结束后回到合法地面点。
- 为 UI/房间暴露只读查询方法：当前 transition kind、cooldown、transition progress、是否坍缩过渡。
- 修复 smoke test 暴露的映射边界问题。
- 不添加大视觉表现，视觉由其他 agent 负责。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/enemy_ai_smoke.gd
godot4 --headless --path . --script tools/godot/player_state_smoke.gd
godot4 --headless --path . --script tools/godot/enemy_attack_smoke.gd
godot4 --headless --path . --script tools/godot/unfold_mapping_smoke.gd
```

提交信息：`test: 添加展开映射smoke测试`
