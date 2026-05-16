# v0.3.2 Enemy, Room, HUD Art Prompts

本轮目标：在 v0.3.1 主角动作与剑 FX 已集成的基础上，把同一房间里的敌人、巨木薄林场景、HUD/武器图标继续从灰盒推进到统一风格。不要新增完整 roguelike 流程；v0.4 才做清场、撤离、结算。

## 当前基线

- 基线分支：`feat/demo-v0-integration`
- 已完成：
  - 主角完整动作 atlas：`game/art/sprites/player_saint/spritesheet.png`
  - 主角源帧：`game/art/source/player_saint/rows/`
  - 剑击弧光 FX：`game/scenes/fx/SwordArcFx.tscn`
  - 动画事件驱动命中盒：`AnimatedActor.hit_start / hit_end / spawn_fx / recoverable`
- 已知美术债：
  - 主角早期 `idle/run` 与新动作行的比例和笔触仍不完全统一，后续 polish 再处理。
  - 敌人、房间、HUD 仍有较明显灰盒感。

## 通用协作规则

每个 agent 必须使用独立 worktree，不要直接在主目录 `/home/coder/workspace/Work/CBZ` 修改代码。

创建 worktree 模板：

```bash
cd /home/coder/workspace/Work
git -C CBZ fetch origin
git -C CBZ worktree add -b <branch-name> <worktree-path> feat/demo-v0-integration
cd <worktree-path>
```

所有 agent 都要遵守：

- 你不是唯一的开发者，当前有多个 worker 并行推进；不要回滚其他人的改动。
- 只修改自己任务单声明的文件范围。
- 不提交 `docs/art/runs/`。
- 不改 `main`，不直接覆盖其他 agent 的输出。
- 不改变玩家战斗数值、展开规则、敌人 AI 规则，除非任务单明确允许。
- 美术资源可以先是程序化/AI sprite，但必须接入 Godot 场景并能在 demo 中看到。

通用验收命令：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

Godot smoke tests 要顺序运行，不要并行跑多个 headless Godot 进程。

## 推荐并行结构

本轮采用 `3 个内容/工程 agent + 1 个集成 agent`。

推荐合并顺序：

1. H2-A：敌人视觉与动画接口
2. H3-A：巨木薄林房间美术层
3. H3-B：HUD/武器图标与风格统一
4. I2：v0.3.2 整合集成与验收

H2-A / H3-A / H3-B 可以并行。I2 必须最后做。

## Agent H2-A：敌人视觉与动画接口

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-2-enemy-visual` 工作。当前分支应为 `feat/v0-3-2-enemy-visual`。

任务：把 `DummyEnemy` 从灰盒替换为“薄林腐化物”的第一版可见敌人，并保留现有 AI/攻击逻辑。

负责文件：

- `game/scenes/enemies/DummyEnemy.tscn`
- `game/scripts/enemies/enemy_base.gd`
- 可新增 `game/scripts/actors/enemy_visual_actor.gd`
- 可新增 `game/art/source/enemy_bark_corrupt/`
- 可新增 `game/art/sprites/enemy_bark_corrupt/`
- 可新增 `tools/godot/enemy_visual_smoke.gd`

禁止修改：

- 玩家脚本、玩家场景、主角 atlas
- 展开系统
- 房间主场景，除非 smoke test 需要临时实例化

视觉要求：

- 敌人剪影低矮、前倾，像树皮/兽形碎片拼成。
- 颜色以腐绿、暗红、断裂白线为主，不能和主角冷白斗篷混淆。
- 至少表现 `idle/move/telegraph/attack/hurt/death` 六种状态，可用程序化帧或 sprite sheet。
- 攻击预警必须仍然清楚，不能被美术遮掉。
- 死亡后仍按现有逻辑消失，不引入新掉落或结算。

工程要求：

- 保留现有 `enemy_base.gd` 的 AI 和伤害接口。
- 如果新增视觉节点，玩法代码只调用稳定方法，如 `play_state(state_name)` 或 `flash_hurt()`。
- 不让视觉节点参与碰撞。
- 不把当前 `ColorRect` 直接删到测试失效；可以隐藏或替换为备用 fallback。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/enemy_ai_smoke.gd
godot4 --headless --path . --script tools/godot/enemy_attack_smoke.gd
```

如新增 smoke，也运行：

```bash
godot4 --headless --path . --script tools/godot/enemy_visual_smoke.gd
```

提交信息：`feat: 添加薄林敌人视觉`

最终报告要说明：敌人哪些状态已有真实表现、哪些仍是占位、是否保留 fallback。

## Agent H3-A：巨木薄林房间美术层

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-2-room-art` 工作。当前分支应为 `feat/v0-3-2-room-art`。

任务：把 `DemoRoom` 的主要背景、地形可读性、lane/落点提示美术统一成“巨木薄林切片”风格。

负责文件：

- `game/scenes/rooms/DemoRoom.tscn`
- `game/scripts/rooms/demo_room.gd`
- 可新增 `game/art/room_thinforest/`
- 可新增 `game/scripts/rooms/thinforest_room_art.gd`
- 可新增 `tools/godot/room_art_smoke.gd`

禁止修改：

- 玩家、敌人 AI、HUD、展开状态机
- 碰撞规则，除非发现现有碰撞与视觉严重不对齐；若必须改，报告里单独说明

视觉要求：

- 远景：薄雾、树影、被压平枝叶，不参与碰撞。
- 中景：树干、枝台、根墙必须和已有平台/墙体碰撞对齐。
- 前景：根须/叶片可有，但透明度低，不能挡住玩家、敌人或攻击预警。
- lane 线从“纯调试线”推进到坐标切片线，但展开可读性不能下降。
- 出口/撤离占位可做成树皮裂隙或坐标门，但先不实现交互流程。

工程要求：

- 优先通过新增视觉层节点完成，不重写房间生成逻辑。
- 任何可站立地形的视觉上沿必须和 `StaticBody2D` 碰撞大致对齐。
- 展开前弱显示 lane，展开中强显示 lane 的既有逻辑不能丢。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/lane_mapping_smoke.gd
godot4 --headless --path . --script tools/godot/unfold_mapping_smoke.gd
godot4 --headless --path . --script tools/godot/unfold_transition_smoke.gd
```

提交信息：`feat: 添加巨木薄林房间美术层`

最终报告要说明：新增了哪些层、是否修改碰撞、展开可读性是否受影响。

## Agent H3-B：HUD/武器图标与风格统一

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-2-hud-weapon-art` 工作。当前分支应为 `feat/v0-3-2-hud-weapon-art`。

任务：美化当前战斗 HUD，加入当前武器“剑”的清晰图标和冷却反馈，但不做完整武器切换 UI。

负责文件：

- `game/scenes/ui/HUD.tscn`
- `game/scripts/ui/hud.gd`
- `game/data/weapons/sword_baseline.cfg`
- 可新增 `game/art/ui/`
- 可新增 `game/art/sprites/weapons/`
- 可新增 `tools/godot/hud_weapon_smoke.gd`

禁止修改：

- 玩家攻击逻辑、SwordAttack 逻辑
- 展开状态机
- 敌人、房间

视觉要求：

- HP、热度、锚率/侵蚀不再只是纯调试文本，但数字可继续保留。
- 热度满 100 时，`1` 展开提示要更清楚。
- 当前武器显示剑图标，能看出这是近战剑。
- 剑攻击冷却有简洁反馈，不需要武器切换菜单。
- HUD 风格使用青白坐标线、金色锚点、少量紫红风险强调；不要盖住战斗。

工程要求：

- 不改 RunState 数据结构，优先消费现有只读状态。
- 若需要读取剑配置，只读 `game/data/weapons/sword_baseline.cfg`。
- smoke test 验证 HUD 能实例化、能刷新热度/锚率、武器图标节点存在。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/hud_unfold_smoke.gd
```

如新增 smoke，也运行：

```bash
godot4 --headless --path . --script tools/godot/hud_weapon_smoke.gd
```

提交信息：`feat: 美化HUD和剑图标`

最终报告要说明：HUD 信息是否仍完整、武器冷却反馈如何表现。

## Agent I2：v0.3.2 整合集成与验收

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-2-world-art-integration` 工作。当前分支应为 `feat/v0-3-2-world-art-integration`。

任务：等待 H2-A/H3-A/H3-B 完成后，整合三条分支，解决场景层级、z-index、HUD 遮挡、视觉冲突，并更新路线图状态。

负责文件：

- `game/scenes/main/Main.tscn`
- `docs/iterations/v0.3_art_weapon_vertical_slice.md`
- `docs/ROADMAP.md`
- 可修改 H2-A/H3-A/H3-B 产生的文件，只做集成修正

验收重点：

- 主角、敌人、房间、HUD 同屏时不互相遮挡。
- 玩家攻击时能看到剑、弧光、敌人受击反馈。
- 展开后 lane/落点仍清楚，房间美术不干扰规则理解。
- HUD 热度满时 `1` 展开提示明确。
- 主场景不再呈现主要裸灰盒角色/敌人。

完整验收命令：

```bash
python3 tools/verify_scaffold.py
python3 tools/art/validate_atlas.py --atlas game/art/sprites/player_saint/spritesheet.png --manifest game/art/sprites/player_saint/manifest.json --output docs/art/runs/player_saint_validation.json
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/animated_actor_smoke.gd
godot4 --headless --path . --script tools/godot/sword_event_smoke.gd
godot4 --headless --path . --script tools/godot/sword_fx_smoke.gd
godot4 --headless --path . --script tools/godot/player_state_smoke.gd
godot4 --headless --path . --script tools/godot/enemy_ai_smoke.gd
godot4 --headless --path . --script tools/godot/enemy_attack_smoke.gd
godot4 --headless --path . --script tools/godot/unfold_mapping_smoke.gd
godot4 --headless --path . --script tools/godot/lane_mapping_smoke.gd
godot4 --headless --path . --script tools/godot/hud_unfold_smoke.gd
godot4 --headless --path . --script tools/godot/unfold_transition_smoke.gd
```

提交信息：`feat: 集成v0.3.2世界美术切片`

最终报告必须包含：

- 三条分支的验收结论。
- 主场景里仍保留的灰盒/占位项。
- 下一步进入 v0.4 单局流程前必须修的美术或工程问题。

