# v0.3.1 Player Art And Weapon Prompts

本轮目标：在已完成 `player_saint` base、`idle`、`run-right`、`run-left` 的基础上，补齐主角关键动作、剑攻击视觉和基础 FX，使当前 demo 的玩家表现从“能动”推进到“能展示”。

本轮不扩敌人、房间和 UI。先把主角动作风格锁住，再进入 H2/H3。

## 当前基线

- 基线分支：`feat/demo-v0-integration`
- 已提交：
  - `game/art/source/player_saint/base_v0_3.png`
  - `game/art/sprites/player_saint/spritesheet.png`
  - `game/art/sprites/player_saint/manifest.json`
  - `game/scripts/actors/animated_actor.gd`
  - `tools/godot/animated_actor_smoke.gd`
  - `tools/godot/sword_event_smoke.gd`
- 已接入的真实动作行：
  - `idle`
  - `run-right`
  - `run-left`
- 仍是 mock 或未通过 QA 的动作行：
  - `jump-start`
  - `fall`
  - `dash`
  - `sword-attack-1`
  - `sword-attack-2`
  - `hurt`
  - `death`
  - `unfold-enter`
  - `unfold-loop`
  - `unfold-exit`

## 通用协作规则

每个 agent 必须使用独立 worktree，不要直接在主目录 `/home/coder/workspace/Work/CBZ` 修改代码。

创建 worktree 模板：

```bash
cd /home/coder/workspace/Work
git -C CBZ fetch origin
git -C CBZ worktree add -b <branch-name> <worktree-path> feat/demo-v0-integration
cd <worktree-path>
```

如果分支已经存在，改用：

```bash
cd <worktree-path>
git fetch origin
git switch <branch-name>
git rebase origin/feat/demo-v0-integration
```

所有 agent 都要遵守：

- 你不是唯一的开发者，当前有多个 worker 并行推进；不要回滚其他人的改动。
- 只修改自己任务单声明的文件范围。
- 不提交 `docs/art/runs/`，它是生成中间产物目录，已被 `.gitignore` 忽略。
- 可提交经过验收的源帧到 `game/art/source/player_saint/rows/<row-name>/`。
- 内容生成 agent 不直接修改 `game/art/sprites/player_saint/spritesheet.png`，最终 atlas 由集成 agent 统一更新。
- 使用 `game/art/source/player_saint/base_v0_3.png` 作为主角身份参考。
- 主角 base 不手持剑；攻击动作行可以出现朴素短剑或长剑，但不能出现十字、圣骑士纹章、教会图标、文字、水印。
- 攻击弧优先交给程序化 FX，不要把大面积光弧画死在角色 sprite 里。

图像生成原则：

- 优先用当前环境可用的 `imagegen` / `codex-imagegen`。
- 需要透明背景时，先生成纯 `#00ff00` 色键背景，再用本地 chroma-key 移除。
- 每个动作行必须保留 prompt、原始 strip、透明 strip、切帧结果和 QA 摘要，但只把最终验收源帧与简短记录提交到 `game/art/source/player_saint/rows/`。
- 若连续 3 次生成同一行仍有严重身份漂移、宗教十字符号、裁切、动作语义错误，停止该行并在最终报告里说明，不要把坏图塞进 atlas。

通用验收命令：

```bash
python3 tools/verify_scaffold.py
python3 tools/art/validate_atlas.py --atlas game/art/sprites/player_saint/spritesheet.png --manifest game/art/sprites/player_saint/manifest.json --output docs/art/runs/player_saint_validation.json
godot4 --headless --path . --quit
```

Godot smoke tests 要顺序运行，不要并行跑多个 headless Godot 进程。

## 推荐并行结构

这一轮采用 `3 个内容生成 agent + 1 个工程 FX agent + 1 个集成 agent`。

推荐合并顺序：

1. H1-A：移动动作源帧
2. H1-B：剑攻击动作源帧
3. H1-C：受击/死亡/展开动作源帧
4. H1-D：剑 FX 与武器视觉接口
5. H1-I：统一 atlas 集成与 smoke 验收

H1-A / H1-B / H1-C / H1-D 可以并行。H1-I 必须等它们完成后再做。

## Agent H1-A：移动动作源帧

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-1-player-motion` 工作。当前分支应为 `feat/v0-3-1-player-motion`。

任务：生成并验收主角 `jump-start`、`fall`、`dash` 三行动作源帧。

负责文件：

- 可新增 `game/art/source/player_saint/rows/jump-start/`
- 可新增 `game/art/source/player_saint/rows/fall/`
- 可新增 `game/art/source/player_saint/rows/dash/`
- 可新增 `game/art/source/player_saint/rows/README.md`

禁止修改：

- `game/art/sprites/player_saint/spritesheet.png`
- `game/art/sprites/player_saint/manifest.json`
- 玩家脚本和场景

动作要求：

- `jump-start`：4 帧，压腿起跳到离地，剪影应和当前 base/idle/run 一致。
- `fall`：4 帧，下落姿态，可循环，不要像攻击或受击。
- `dash`：4 帧，高速前冲，身体前倾，可有轻微残影感，但主体轮廓不能糊成光团。
- 三行动作都不应手持剑；腰间可保留极小剑柄/鞘影。
- 透明帧尺寸统一 128×128，脚底/身体中心锚点相对稳定。

交付格式：

```text
game/art/source/player_saint/rows/<row-name>/
  frame-0.png
  frame-1.png
  ...
  prompt.md
  qa.json
```

`qa.json` 至少包含：

```json
{
  "row": "jump-start",
  "frames": 4,
  "visual_qa": "pass",
  "notes": "identity stable; no forbidden symbols; anchor drift acceptable"
}
```

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

提交信息：`feat: 生成主角移动动作源帧`

最终报告要说明：每行动作的生成轮数、是否做过锚点修正、是否有轻微遗留问题。

## Agent H1-B：剑攻击动作源帧

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-1-player-sword-rows` 工作。当前分支应为 `feat/v0-3-1-player-sword-rows`。

任务：生成并验收主角 `sword-attack-1`、`sword-attack-2` 两行动作源帧。

负责文件：

- 可新增 `game/art/source/player_saint/rows/sword-attack-1/`
- 可新增 `game/art/source/player_saint/rows/sword-attack-2/`

禁止修改：

- `game/art/sprites/player_saint/spritesheet.png`
- `game/art/sprites/player_saint/manifest.json`
- `game/scripts/actors/animated_actor.gd`
- `game/scripts/combat/sword_attack.gd`
- 玩家场景

动作要求：

- `sword-attack-1`：6 帧，横斩。第 2 帧是命中开始帧，第 4 帧是命中结束/收招帧。
- `sword-attack-2`：6 帧，返斩或轻下劈，能接在第一段之后。第 2 帧命中开始，第 4 帧命中结束。
- 攻击帧里可以出现朴素剑刃，但不要把巨大的攻击弧画入角色 sprite；攻击弧由 H1-D 的 FX 表现。
- 禁止：十字、加号形圣徽、教会纹章、金色大披风、脸部十字符号、文字、水印。
- 主角身份必须贴近 `base_v0_3.png`：无脸面罩、冷白/暗蓝灰/少量圣痕金、薄斗篷、克制轮廓。
- 剑刃方向要和现有右朝向一致；左朝向后续由 `set_facing()` 镜像处理。

交付格式：

```text
game/art/source/player_saint/rows/<row-name>/
  frame-0.png
  frame-1.png
  ...
  prompt.md
  qa.json
```

`qa.json` 必须额外标注事件帧：

```json
{
  "row": "sword-attack-1",
  "frames": 6,
  "visual_qa": "pass",
  "hit_start_frame": 2,
  "hit_end_frame": 4,
  "notes": "plain blade only; no arc baked into sprite; no forbidden symbols"
}
```

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/sword_event_smoke.gd
```

提交信息：`feat: 生成主角剑击动作源帧`

最终报告要说明：是否存在符号误读风险；若失败，明确是哪一行失败，不要提交失败帧。

## Agent H1-C：受击、死亡与展开动作源帧

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-1-player-state-rows` 工作。当前分支应为 `feat/v0-3-1-player-state-rows`。

任务：生成并验收主角状态动作源帧：`hurt`、`death`、`unfold-enter`、`unfold-loop`。`unfold-exit` 由集成阶段倒序衍生。

负责文件：

- 可新增 `game/art/source/player_saint/rows/hurt/`
- 可新增 `game/art/source/player_saint/rows/death/`
- 可新增 `game/art/source/player_saint/rows/unfold-enter/`
- 可新增 `game/art/source/player_saint/rows/unfold-loop/`

禁止修改：

- `game/art/sprites/player_saint/spritesheet.png`
- `game/art/sprites/player_saint/manifest.json`
- 玩家脚本和场景

动作要求：

- `hurt`：4 帧，短促后仰/白闪趋势，不做夸张血腥。
- `death`：8 帧，跪倒或碎成坐标片，强调“坐标磨损”，不做血腥死亡。
- `unfold-enter`：6 帧，身体被坐标线压平/锁定，可读但不要太亮。
- `unfold-loop`：4 帧，展开状态悬浮/微动，可循环。
- 不出现手持剑动作。
- 风格要和已接入 idle/run 保持一致。

交付格式同 H1-A。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
```

提交信息：`feat: 生成主角状态动作源帧`

最终报告要说明：`unfold-enter` 是否适合倒放成 `unfold-exit`。

## Agent H1-D：剑 FX 与武器视觉接口

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-1-sword-fx` 工作。当前分支应为 `feat/v0-3-1-sword-fx`。

任务：实现程序化剑攻击弧和命中火花的最小工程接口，使 `AnimatedActor.spawn_fx("sword_arc", position)` 能在玩家攻击事件帧触发视觉反馈。

负责文件：

- 可新增 `game/scripts/fx/sword_arc_fx.gd`
- 可新增 `game/scenes/fx/SwordArcFx.tscn`
- 可修改 `game/scripts/player/player_controller.gd`
- 可修改 `game/scenes/player/Player.tscn`
- 可新增 `tools/godot/sword_fx_smoke.gd`
- 可修改 `game/data/weapons/sword_baseline.cfg`，只添加视觉字段

禁止修改：

- `game/art/sprites/player_saint/spritesheet.png`
- `game/art/source/player_saint/rows/`
- `game/scripts/actors/animated_actor.gd`，除非 smoke 证明必须补只读接口
- `game/scripts/combat/sword_attack.gd`，除非发现事件驱动已有 bug

实现要求：

- 新增一个轻量 `SwordArcFx`，生命周期 0.10-0.18 秒。
- 攻击弧颜色默认 `#E8E4D4`，半透明，快速淡出。
- 方向跟随 `AnimatedActor` 的 facing 或玩家当前 `facing`。
- FX 不参与碰撞，不改变伤害逻辑。
- 命中盒仍由 `SwordAttack` 和动画事件驱动。
- 不使用昂贵粒子数量；可用 `_draw()`、`Line2D`、`Polygon2D` 或 shader 风格的简单几何。
- 多次攻击不能留下孤儿节点。

验收：

- 攻击时 `sword-attack-1` 的 `spawn_fx` 事件能生成一段可见弧光。
- 0.3 秒后场景树里没有残留的过期 `SwordArcFx`。
- 现有 `sword_event_smoke` 不失败。

完成后运行：

```bash
python3 tools/verify_scaffold.py
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/animated_actor_smoke.gd
godot4 --headless --path . --script tools/godot/sword_event_smoke.gd
godot4 --headless --path . --script tools/godot/sword_fx_smoke.gd
```

提交信息：`feat: 添加剑击弧光FX`

最终报告要说明：接入点、生命周期、是否修改了玩家脚本。

## Agent H1-I：主角 atlas 集成与整体验收

你在独立 worktree `/home/coder/workspace/Work/CBZ-v0-3-1-player-art-integration` 工作。当前分支应为 `feat/v0-3-1-player-art-integration`。

任务：等待 H1-A/H1-B/H1-C/H1-D 合入或把它们的改动 cherry-pick 到本分支后，统一把验收源帧打入 `game/art/sprites/player_saint/spritesheet.png`，生成 `unfold-exit`，并跑完整 smoke。

负责文件：

- `game/art/sprites/player_saint/spritesheet.png`
- `game/art/sprites/player_saint/manifest.json`，仅当 frame count 或 row metadata 确实需要修正时
- `game/art/sprites/player_saint/import.json`
- `docs/art/runs/player_saint_validation.json`
- 可新增 `game/art/source/player_saint/rows/INTEGRATION_NOTES.md`
- 可修改 `docs/iterations/v0.3_art_weapon_vertical_slice.md` 的状态/已知问题

集成要求：

- 从 `game/art/source/player_saint/rows/` 读取已验收帧。
- `unfold-exit` 由 `unfold-enter` 倒序衍生，不重新生图。
- atlas row 映射必须保持：
  - row 0 `idle`
  - row 1 `run-right`
  - row 2 `run-left`
  - row 3 `jump-start`
  - row 4 `fall`
  - row 5 `dash`
  - row 6 `sword-attack-1`
  - row 7 `sword-attack-2`
  - row 8 `hurt`
  - row 9 `death`
  - row 10 `unfold-enter`
  - row 11 `unfold-loop`
  - row 12 `unfold-exit`
- 若某一行动作没有通过 QA，不要用失败帧覆盖 atlas；保留当前 mock 行并在 notes 里标红。
- 更新后必须确认 `AnimatedActor` 仍能按 manifest 加载全部动画。

验收命令：

```bash
python3 tools/verify_scaffold.py
python3 tools/art/validate_atlas.py --atlas game/art/sprites/player_saint/spritesheet.png --manifest game/art/sprites/player_saint/manifest.json --output docs/art/runs/player_saint_validation.json
godot4 --headless --path . --quit
godot4 --headless --path . --script tools/godot/animated_actor_smoke.gd
godot4 --headless --path . --script tools/godot/sword_event_smoke.gd
godot4 --headless --path . --script tools/godot/player_state_smoke.gd
```

如果 H1-D 已合入，也运行：

```bash
godot4 --headless --path . --script tools/godot/sword_fx_smoke.gd
```

提交信息：`feat: 集成主角完整动作atlas`

最终报告必须包含：

- 哪些 row 已替换真实素材。
- 哪些 row 仍保留 mock 或存在已知问题。
- smoke test 结果。
- Windows 端同步运行命令是否仍然适用。

## 给用户的开窗顺序

如果你手动开新窗口，建议这样发：

1. 先开 H1-A、H1-B、H1-C、H1-D 四个窗口并行。
2. 等四个 agent 都报告提交完成。
3. 再开 H1-I，把四个分支合进集成 worktree，统一打包和验收。

如果由主 agent 调度子 agent，也按同样顺序：先并发 H1-A/H1-B/H1-C/H1-D，主线程不重复做它们的工作，只做状态跟踪和最终集成。

