# 高质量 2D 动画工具链

状态：v0.3 采用的动画管线决策稿。本版从原"Spine 主管线"改为"sprite sheet AI 管线主线 + 程序化几何/shader 辅助"。变更动机见末尾"路线变更说明"。

## 结论

主角、敌人、Boss、武器、特效、UI 装饰的视觉内容**全部以 sprite sheet 形式产出**，由项目级 AI 美工管线生成。Godot 侧用 `AnimatedSprite2D` / `SpriteFrames` 直接消费，配合少量 shader 和 `_draw()` 做程序化补强。

具体管线：

**主管线：AI sprite sheet 生产线（见 [pipeline/SKILL.md](pipeline/SKILL.md)）**

- 输入：[pipeline/identity_brief.md](pipeline/identity_brief.md) + [pipeline/style_contract.json](pipeline/style_contract.json) + 任务图 JSON
- 后端可插拔：OpenAI `$imagegen`、Google Gemini 2.5 Flash Image / Imagen、本地 ComfyUI（SDXL + IP-Adapter + ControlNet）、mock（CI 用）
- 输出：透明背景 atlas + `SpriteFrames` `.tres` + contact sheet + 预览 GIF + 验证报告

**辅助管线：Godot 程序化补强**

- `AnimationPlayer` / `AnimationTree`：玩法状态机、混合、UI/相机动画
- 自绘 shader：剑气拖尾、坍缩扭曲、屏幕震动、灾厄裂纹、坐标线扩散
- `_draw()` 程序化绘制：HUD 圣痕条、热度环、锚率指示、lane 提示
- SVG / `Polygon2D`：UI 边框、几何祭坛、撤离点光圈

**完全不再使用：Spine / DragonBones / Inochi2D / Rive 等骨骼运行时**

不是它们不好，而是这些工具要求"图形编辑器交互"，AI agent 不能驱动。维持本项目"95%+ AI 化"目标，必须走 AI 擅长的路径：**生成图片**。

## 工具分工

| 工具 | 用途 | 在本项目中的定位 |
| --- | --- | --- |
| Codex `$imagegen` / Gemini Image API / 本地 ComfyUI | sprite sheet 帧生成 | 主管线图像生成后端，由 [pipeline/SKILL.md](pipeline/SKILL.md) 编排 |
| Python (Pillow / numpy) | 切帧、atlas 合成、验证、contact sheet、GIF | 完全确定性的"几何/打包/QA 验证"管线，由 `tools/art/` 提供 |
| Godot `AnimatedSprite2D` + `SpriteFrames` | 运行时动画播放 | 直接消费 sprite sheet，不需要外部 runtime |
| Godot `AnimationPlayer` / `AnimationTree` | 状态机、混合、事件帧 | 玩法状态控制层，触发 `AnimatedSprite2D` 切换动画 |
| Godot shader / `CanvasItemMaterial` | 剑气、坍缩、扭曲、裂纹 | 程序化 FX，AI agent 直接写 shader 代码 |
| Godot `_draw()` / `Polygon2D` / `Line2D` | HUD、UI 装饰、几何元素 | 程序化绘制，AI agent 直接写代码 |
| Inkscape（可选） | SVG 矢量素材：圣纹、祭坛装饰 | 手工/AI 生成 SVG 后导入 Godot |
| Krita / LibreSprite（可选） | 关键特写或人工修补 | 仅在 AI 视觉 QA 反复失败时人工介入；非主路径 |

## 为什么放弃骨骼动画路线

Spine、DragonBones、Inochi2D、Rive 都是**图形编辑器**——它们的工作流核心是"人在图形软件里调骨头、调权重、调插值"。这些步骤本质上**不能被 AI agent 完成**：

- AI agent 是写代码 / 调用 API / 处理文本的工具
- AI agent 无法操作图形软件 GUI
- 即使用 Python 脚本驱动 Blender，生成的也只是机械动作，不具备"美术判断"

如果坚持骨骼动画路线：

- 美术工作只有 30-50% 能 AI 化（写脚本/接管/调状态机）
- 剩余 50-70% 必须人来做绑骨、调权重、调动作韵律
- 与项目"95%+ AI 化"目标冲突

sprite sheet 路线的代价：

- 单动作迭代要重生成几张图（不像骨骼调一根曲线那么快）
- 文件体积更大（每帧独立保存）
- 动作流畅度受帧数限制（建议 ≥ 8 帧/动作）

但 sprite sheet 的关键优势：

- 帧生成本质上就是"画图"，AI 图像模型的强项
- Godot 原生 `AnimatedSprite2D` 直接消费，零 runtime 集成风险
- 切帧、atlas、验证全部是确定性脚本，可以 100% 由 Claude/Codex 写出
- contact sheet 可以让 AI 自己审查 AI 的产出，形成 QA 闭环

## 动画质量标准

### 运行标准

- 游戏运行目标：60 FPS
- sprite 动画帧率：12 FPS（默认）；高速 row（dash、attack）可单独提到 24 FPS
- 帧间过渡：`AnimatedSprite2D` 不做帧插值（保留剪影感）；状态切换通过 `AnimationTree` 状态混合
- 命中帧必须和碰撞激活帧对齐——通过 `SpriteFrames` 的 `frame_changed` 信号触发碰撞盒激活，**误差锁死在同一 `_physics_process` tick**
- 帧锚点（脚底/中心）跨帧漂移 ≤ 2px（由 `tools/art/validate_atlas.py` 强制校验）

### 主角最低动作集（v0.3 垂直切片）

任务图见 `docs/art/jobs/player_saint_v0.3.json`：

| 动作 | 帧数 | 说明 |
| --- | --- | --- |
| `idle` | 6 | 可循环，斗篷/呼吸/圣痕微动 |
| `run-right` | 8 | 可循环，脚底接触点稳定 |
| `run-left` | (镜像) | 由 run-right 翻转衍生 |
| `jump-start` | 4 | 起跳前压腿 + 离地，不能像瞬移 |
| `fall` | 4 | 下落姿态，可循环 |
| `dash` | 4 | 0.33 秒（24 FPS），可配残影 shader |
| `sword-attack-1` | 6 | 横斩，命中帧第 3 帧 |
| `sword-attack-2` | 6 | 返斩或下劈，给后续连段留口 |
| `hurt` | 4 | 受击后仰，约 0.33 秒 |
| `death` | 8 | 跪倒或碎成坐标片 |
| `unfold-enter` | 6 | 被压成平面/坐标锁定的短动作 |
| `unfold-loop` | 4 | 展开状态悬浮或俯视姿态，可循环 |
| `unfold-exit` | (倒序) | 由 unfold-enter 倒放衍生 |

### 敌人最低动作集

| 动作 | 帧数 | 说明 |
| --- | --- | --- |
| `idle` | 4-6 | 轮廓有生命感 |
| `move` | 6-8 | 与当前追击速度匹配 |
| `telegraph` | 4 | 攻击前摇，至少 0.35s 可读 |
| `attack` | 6 | 命中帧和攻击区域对齐 |
| `hurt` | 4 | 可打断感明确 |
| `death` | 6-8 | 碎裂/散落/淡出 |

### 武器表现

剑作为 v0.3 唯一战斗武器，按下列规则集成：

- **剑作为主角 sprite 的一部分**绑定在 `weapon_socket_main` 位置，**不独立 sprite sheet**
- 攻击弧用 shader 程序化绘制，跟随玩家朝向，由 `AnimationTree` 事件帧触发
- 命中盒激活和动画第 3 帧对齐，通过 `AnimatedSprite2D.frame_changed` 信号

其他 5 武器（矛、弓、法杖、回旋刃、圣铃）：

- 主世界图标：64×64 sprite，由 `/hatch-weapon` 单独生成
- 攻击 FX：每把武器单独的 FX sprite sheet（剑气/箭轨/法阵/回旋/音波）
- v0.3 暂不接入完整玩法，但视觉资产可以并行生产

## AnimatedActor 接口（v0.3 必做）

无论后端如何变化，玩法脚本只通过 `AnimatedActor` 包装层调用。接口锁定如下：

```gdscript
class_name AnimatedActor
extends Node2D

signal hit_start(payload: Dictionary)
signal hit_end(payload: Dictionary)
signal spawn_fx(name: StringName, position: Vector2)
signal footstep()
signal recoverable()
signal anim_finished(name: StringName)

func play_state(state_name: StringName) -> void: ...
func play_attack(attack_name: StringName) -> void: ...
func set_facing(direction: int) -> void: ...      # -1 / +1
func get_weapon_socket_global() -> Vector2: ...
func is_in_recovery_window() -> bool: ...
```

实现内部由 `AnimatedSprite2D` + `AnimationTree` 驱动；玩法脚本永远不直接读 `frame` 字段、不直接调 `play()`。

事件名约定（在 `SpriteFrames` 的 `frame_changed` 信号上挂接）：

- `hit_start` / `hit_end`：命中盒激活/失活
- `spawn_fx`：触发剑气/命中火花
- `footstep`：脚步音
- `recoverable`：可取消动作的最早帧

## 目录建议

```text
game/art/
  README.md
  sprites/
    player_saint/
      spritesheet.png
      anim.tres
      manifest.json
    enemy_bark_corrupt/
    room_thinforest/
    weapons/
    fx/
    ui/
docs/art/
  animation_pipeline.md          # 本文件
  pipeline/
    SKILL.md                     # 项目级 skill 文档
    style_contract.json
    identity_brief.md
    prompts/
  jobs/                          # 任务图 JSON
  runs/                          # AI 生成中间产物（gitignore）

tools/art/
  README.md
  prepare_run.py
  extract_strip_frames.py
  inspect_frames.py
  compose_atlas.py
  validate_atlas.py
  make_contact_sheet.py
  render_animation_previews.py
  derive_mirrored_row.py
  godot_import.py

game/scenes/actors/
game/scripts/actors/animated_actor.gd
game/scripts/animation/animation_event_bridge.gd
```

## 命名规范

- 动画状态名：`idle`、`run-right`、`run-left`、`sword-attack-1`、`unfold-enter`、`unfold-loop`、`unfold-exit`
- 帧文件：`row-<name>-frame-<n>.png`（0-indexed）
- atlas 合成名：`spritesheet.png`（每个 subject 一张）
- Godot 资源名：`anim.tres`（SpriteFrames 资源）
- 事件名（frame_changed 信号回调）：`hit_start`、`hit_end`、`spawn_fx`、`footstep`、`recoverable`
- 武器挂点：`weapon_socket_main`、`weapon_socket_back`
- 脚底定位点：`ground_anchor`

## 图像生成后端

[pipeline/SKILL.md](pipeline/SKILL.md) 的"图像生成后端（可插拔）"段落定义具体接入方式。简表：

| 后端 | 适合场景 | 成本 |
| --- | --- | --- |
| `codex-imagegen` | Codex App 用户 | 计入 Codex 用量 |
| `openai` | 自有 OpenAI API key | $0.04-0.08 / 图 |
| `gemini` | 角色一致性强（Nano Banana） | $0.03 / 图左右 |
| `imagen` | Google Imagen 3 | 视 Vertex AI 报价 |
| `comfyui` | 本地 GPU、零经常性成本 | 仅电费 + 一次性 LoRA 训练时间 |
| `mock` | CI / 没 GPU/API key 时验证管线 | 免费 |

**v0.3 推荐起步组合**：先用 `gemini`（Nano Banana 一致性强且便宜）打通管线 ⇒ 验证质量满意后逐步迁移到 `comfyui` + 项目 LoRA 实现长期零成本。

## 验收方式

v0.3 美术验收（与 [../iterations/v0.3_art_weapon_vertical_slice.md](../iterations/v0.3_art_weapon_vertical_slice.md) 对齐）：

- `python3 tools/verify_scaffold.py` 通过
- `python3 tools/art/validate_atlas.py` 在主角 atlas 上通过
- `godot4 --headless --path . --quit` 通过
- 录制 20 秒战斗片段：跑动、跳跃、冲刺、两段剑击、受击、展开、坍缩——动作不卡、脚不滑、剪影统一
- AI 视觉 QA（contact sheet + GIF）`visual_qa=pass`

## 路线变更说明

本文件初版采用"Spine 主管线 + Godot 编排 + 逐帧 FX"方案。**2026-05-16 改为现在的 sprite sheet AI 管线方案**，原因：

1. 用户明确目标为"95%+ AI 完成美工"
2. 骨骼动画的核心工作（绑骨/调权重/调动作韵律）AI agent 无法完成
3. Hatch Pet（OpenAI Codex 内置 skill）证明了 sprite sheet 任务图 + 身份锁定 + 两层 QA + 最小修复 这套模式可以让 sprite sheet 美工管线达到 90%+ AI 化
4. sprite sheet + Godot AnimatedSprite2D 是 Godot 原生路径，零外部 runtime 依赖
5. AI 图像生成模型（Nano Banana、SDXL + IP-Adapter）的角色一致性已足以支撑战斗角色级别需求

骨骼动画路线作为远期备选保留：若项目后期需要复杂武器换装系统或大量皮肤变体（v0.6 之后），届时再评估是否引入 Spine。

## 参考

- 项目级 skill 详细规范：[pipeline/SKILL.md](pipeline/SKILL.md)
- OpenAI Hatch Pet 源参考：<https://github.com/openai/skills/blob/main/skills/.curated/hatch-pet/SKILL.md>
- Godot SpriteFrames 文档：<https://docs.godotengine.org/en/stable/classes/class_spriteframes.html>
- Godot AnimatedSprite2D 文档：<https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html>
- Godot AnimationTree 文档：<https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html>
