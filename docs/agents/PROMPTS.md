# Copy-Paste Prompts For Parallel Agents

使用方式：

1. 先在当前仓库提交 harness 基线。
2. 每个 agent 使用独立 `git worktree` 或独立 clone，避免多个窗口争用同一个工作目录。
3. 每个 agent 复制对应 prompt 开跑。

建议先提交基线：

```bash
git status --short
python3 tools/verify_scaffold.py
git add AGENTS.md project.godot game docs tools 设定.md spec_展开机制.md spec_数值基线.md spec_流程UI存档引导.md
git commit -m "feat: 搭建 Demo v0 工程骨架"
```

如果基线分支暂时还没合入 `main`，可以让 agent 从当前基线分支创建 worktree。示例：

```bash
git worktree add ../CBZ-player -b feat/player-controller HEAD
git worktree add ../CBZ-combat -b feat/combat-enemy HEAD
git worktree add ../CBZ-unfold -b feat/unfold-system HEAD
git worktree add ../CBZ-ui -b feat/hud-run-state HEAD
git worktree add ../CBZ-room -b feat/content-demo-room HEAD
```

---

## Agent A Prompt: Project Foundation

你是 Agent A，负责《折维圣徒》Demo v0 的工程基础。

工作目录：使用你所在的独立 worktree。  
分支：`feat/project-foundation`。  
任务单：阅读 `docs/agents/A_project_foundation.md`。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. 稳定 Godot 4 工程入口 `project.godot`。
2. 确认输入映射：WASD、空格、鼠标左键、Q、E 交互、1 展开。
3. 确认 autoload：`Balance`、`RunState`、`UnfoldManager`。
4. 完善 `tools/verify_scaffold.py`，让后续 agent 可用它做静态验收。
5. 不实现具体玩法，只保证其他 agent 有稳定工程基础。

验收：

```bash
python3 tools/verify_scaffold.py
git status --short
```

完成后总结：

- 修改了哪些文件。
- 如何验证。
- 还有哪些留给其他 agent。

---

## Agent B Prompt: Player Controller

你是 Agent B，负责《折维圣徒》Demo v0 的玩家控制器。

工作目录：使用你所在的独立 worktree。  
分支：`feat/player-controller`。  
任务单：阅读 `docs/agents/B_player_controller.md`。  
规格依据：`spec_展开机制.md`、`spec_数值基线.md`。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. 实现横版状态：A/D 移动、W 跳跃、重力、落地。
2. 实现展开状态：WASD 平面移动，无跳跃高度。
3. 实现空格冲刺：最多 2 连发、起手 0.2 秒无敌、短冷却。
4. 实现受击：扣血、0.5 秒无敌、每次受击给 `RunState` +5 圣痕热度。
5. 展开中受击调用 `UnfoldManager.end_unfold("collapse")`。
6. HP 归零发出 `died` 信号，不直接做死亡结算。

写入范围：

- `game/scripts/player/player_controller.gd`
- `game/scenes/player/Player.tscn`
- 可新增 `game/scripts/player/**`

验收：

```bash
python3 tools/verify_scaffold.py
```

如果本机有 Godot：

```bash
godot --headless --path . --quit
```

完成后总结玩家控制状态机、输入、受击和未完成事项。

---

## Agent C Prompt: Combat And Enemy

你是 Agent C，负责《折维圣徒》Demo v0 的战斗和敌人基础。

工作目录：使用你所在的独立 worktree。  
分支：`feat/combat-enemy`。  
任务单：阅读 `docs/agents/C_combat_enemy.md`。  
规格依据：`spec_数值基线.md`、`spec_道具协同参考.md`。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. 实现敌人 HP、伤害、死亡信号。
2. 实现 `apply_damage(amount)`。
3. 实现剑的最小普攻命中区域。
4. 命中敌人给 +2 圣痕热度。
5. 击杀普通敌人给 +5 圣痕热度。
6. 第 1 区普通怪 HP 以 10 为基准，剑应约 2-3 下击杀。

写入范围：

- `game/scripts/enemies/**`
- `game/scenes/enemies/**`
- 可新增 `game/scripts/combat/**`
- 可新增 `game/scenes/combat/**`
- 可新增 `game/data/enemies/**`
- 可新增 `game/data/weapons/**`

验收：

```bash
python3 tools/verify_scaffold.py
```

完成后总结敌人接口、剑攻击接口、和 Player/Unfold 需要对接的点。

---

## Agent D Prompt: Unfold System

你是 Agent D，负责《折维圣徒》Demo v0 的平面展开系统。

工作目录：使用你所在的独立 worktree。  
分支：`feat/unfold-system`。  
任务单：阅读 `docs/agents/D_unfold_system.md`。  
规格依据：必须严格遵守 `spec_展开机制.md`。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. 实现 `UnfoldManager` 状态机：Vertical、Transition、Unfolded、Cooldown。
2. `1` 展开；展开中再按 `1` 主动结束。
3. 展开期间以 5 热度/秒消耗，热度上限越高持续越久。
4. 自然结束：风险 +0.5%，侵蚀 +1。
5. 主动结束：风险 +0.2%，侵蚀 +0.5。
6. 坍缩：风险 +1%，侵蚀 +2，热度归零。
7. 单局展开风险上限 +4%。
8. 实现玩家和敌人的坐标映射接口：敌人 X 保留，Z 按房间 lane；坍缩后幸存敌人吸附最近合法地面点。

写入范围：

- `game/scripts/unfold/**`
- `game/scripts/rooms/room_lane_profile.gd`
- 可新增 `game/scripts/rooms/**`
- 可新增 `game/data/rooms/**`
- 可新增 `game/scenes/rooms/**`

验收：

```bash
python3 tools/verify_scaffold.py
```

完成后总结展开状态、映射规则、还需要 Player/Enemy/Room 提供的接口。

---

## Agent E Prompt: HUD And Run State

你是 Agent E，负责《折维圣徒》Demo v0 的 HUD、RunState 和流程 UI 框架。

工作目录：使用你所在的独立 worktree。  
分支：`feat/hud-run-state`。  
任务单：阅读 `docs/agents/E_hud_run_state.md`。  
规格依据：`spec_流程UI存档引导.md`、`spec_数值基线.md`。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. HUD 显示血量占位、圣痕热度、灰币占位、彻底死亡概率、武器图标占位、冲刺占位、灾厄侵蚀等级。
2. 风险变化时做视觉反馈占位。
3. 死亡结算占位：显示普通重塑/彻底死亡判定结果。
4. `RunState` 维护热度、风险、侵蚀、死亡判定。
5. 存档框架占位：每房清理后可调用 `save_run_checkpoint()`。

写入范围：

- `game/scripts/run/run_state.gd`
- `game/scripts/ui/**`
- `game/scenes/ui/**`
- 可新增 `game/scripts/save/**`

验收：

```bash
python3 tools/verify_scaffold.py
```

完成后总结 HUD 信号、死亡结算、存档占位接口。

---

## Agent F Prompt: Content Demo Room

你是 Agent F，负责《折维圣徒》Demo v0 的巨木薄林测试房。

工作目录：使用你所在的独立 worktree。  
分支：`feat/content-demo-room`。  
任务单：阅读 `docs/agents/F_content_demo_room.md`。  
规格依据：`设定.md` 的巨木薄林区域、`spec_展开机制.md` 的 lane/坐标映射。  
必须遵守：阅读 `AGENTS.md`，不要修改任务单以外的文件范围。

目标：

1. 创建 `game/scenes/rooms/DemoRoom.tscn`。
2. 放置横版地面和 2-3 个障碍/平台占位。
3. 定义 3-5 条展开 lane。
4. 放置玩家出生点、敌人出生点、坍缩重定位点。
5. 清房后预留门选择/下一房入口占位。
6. 可修改 `game/scenes/main/Main.tscn` 来实例化 DemoRoom。

写入范围：

- `game/scenes/rooms/**`
- `game/scripts/rooms/**`
- `game/data/rooms/**`
- `game/scenes/main/Main.tscn`

验收：

```bash
python3 tools/verify_scaffold.py
```

完成后总结房间节点结构、lane 数据和与 UnfoldManager 的接口。

