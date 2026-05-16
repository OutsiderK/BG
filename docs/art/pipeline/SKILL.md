---
name: zhewei-art-pipeline
description: 《折维圣徒》项目级美工生产管线。当用户输入 /hatch-player、/hatch-enemy、/hatch-room、/hatch-fx、/hatch-ui，或者要求"为某个角色/敌人/场景生成 sprite sheet 与动画"时使用。该 skill 复用 Hatch Pet 的"任务图 + 身份锁定 + 两层 QA + 最小修复"模式，把游戏角色的完整动作集（idle / run / attack / hurt / unfold / death 等）以 sprite sheet 形式产出，AI 化目标 90% 以上。
---

# 折维圣徒美工管线 Skill

本 skill 是项目级美工产线，目标是把绘画/上色/连贯动作这种"不确定创作"交给图像生成模型，把几何/切帧/打包/验证/Godot 接入这种"确定工程"交给 Python 脚本，由 Claude Code 或 Codex 充当编排者。

设计原型来自 OpenAI Codex 的 Hatch Pet skill。把它从"桌面像素宠物 8x9 sprite sheet"放大到"游戏角色/敌人/场景的完整动作集 sprite sheet"。

## 触发场景

| 用户输入 | 实际任务 |
| --- | --- |
| `/hatch-player [角色名]` | 生成主角全套动作 sprite sheet + Godot 资源 |
| `/hatch-enemy [敌人名]` | 生成敌人全套动作 sprite sheet + Godot 资源 |
| `/hatch-boss [boss名]` | 同上，但有更复杂的动作集和特殊招式 |
| `/hatch-weapon [武器名]` | 生成武器静态图 + 攻击弧 FX sprite sheet |
| `/hatch-room [房间名]` | 生成房间背景层（远景/中景/前景） |
| `/hatch-fx [效果名]` | 生成单一 FX 的逐帧 sprite sheet（剑气、命中爆点等） |
| `/hatch-ui [组件名]` | 生成 UI 元素（图标、徽章、HUD 装饰） |
| 用户口述："为 XXX 生成动画"、"做一套 XXX 的 sprite sheet" | 同上，根据目标类型推断 |

## 核心原理（搬运自 Hatch Pet）

1. **两段式**：确定性脚本管几何 / 验证 / 打包；AI 模型管"画什么"
2. **任务图**：每个角色一张 JSON，列出 base + 所有 row 及依赖关系
3. **身份锁定**：先生成 1 张 canonical pose（base），后续 row 把 base 作为参考喂回去
4. **镜像/对称衍生**：能翻转得到的（如 run-left 来自 run-right）就不重新生图
5. **轻量 worker**：每行作为独立子任务，最多 2 个并发，用更便宜模型做视觉
6. **两层 QA**：脚本验透明度/尺寸/对齐；多模态 AI 看 contact sheet 与 GIF 判断身份一致性、步态、风格
7. **最小修复**：单行不合格只重做这一行；区分"切帧错误"与"生成错误"

## 工作流（用户可见进度，四步）

每次调用 `/hatch-*` 都按这四步推进，写入用户可见的状态消息：

1. **"准备 \<目标\>"** — 读取 [identity_brief.md](identity_brief.md)、[style_contract.json](style_contract.json) 和任务图 JSON；用 `tools/art/prepare_run.py` 创建 run 目录
2. **"刻画 \<目标\> 的主形象"** — 生成 base canonical pose，作为视觉真实源
3. **"演练 \<目标\> 的动作"** — 依赖图驱动 row 生成；先 `idle` 和 `run-right`（或第一个有方向的行）确认身份和步态；再决定镜像还是新生；再剩余 row
4. **"封装 \<目标\>"** — 切帧、atlas 打包、contact sheet、预览 GIF；脚本验证 + AI 视觉 QA；写入 Godot 资源

## 任务图 schema

每个角色/敌人/场景一个 JSON，放在 `docs/art/jobs/<subject>_<version>.json`：

```json
{
  "subject": "player_saint",
  "version": "v0.3",
  "style_contract": "docs/art/pipeline/style_contract.json",
  "identity_brief": "docs/art/pipeline/identity_brief.md",
  "prompt_overrides": "docs/art/pipeline/prompts/overrides/player_saint.txt",
  "cell_size": [128, 128],
  "atlas_grid": [8, 12],
  "frame_rate": 12,
  "base": {
    "pose": "neutral-facing-right",
    "size": [512, 512],
    "notes": "斗篷自然下垂、剑挂腰间、面罩可见、双脚平站、表情克制"
  },
  "rows": [
    { "name": "idle",           "frames": 6, "deps": ["base"] },
    { "name": "run-right",      "frames": 8, "deps": ["base", "idle"] },
    { "name": "run-left",       "method": "mirror", "from": "run-right" },
    { "name": "jump-start",     "frames": 4, "deps": ["base"] },
    { "name": "fall",           "frames": 4, "deps": ["base", "jump-start"] },
    { "name": "dash",           "frames": 4, "deps": ["base"] },
    { "name": "sword-attack-1", "frames": 6, "deps": ["base"] },
    { "name": "sword-attack-2", "frames": 6, "deps": ["base", "sword-attack-1"] },
    { "name": "hurt",           "frames": 4, "deps": ["base"] },
    { "name": "death",          "frames": 8, "deps": ["base"] },
    { "name": "unfold-enter",   "frames": 6, "deps": ["base"] },
    { "name": "unfold-loop",    "frames": 4, "deps": ["unfold-enter"] },
    { "name": "unfold-exit",    "method": "reverse", "from": "unfold-enter" }
  ]
}
```

字段说明：

- `cell_size`：每帧像素尺寸。主角默认 128×128；普通敌人 96×96；Boss 192×192。
- `atlas_grid`：图集列×行。列固定为 8，行根据动作数。
- `method`：`mirror`（水平翻转）、`reverse`（时间倒放）、`generate`（默认，缺省）
- `deps`：列出的 row 完成后才能开始生成本行；身份锁定时把这些 row 的选中帧作为参考图喂给图像模型

## 目录结构

```
docs/art/
├── animation_pipeline.md       # 总体方案（解释为什么走这条路）
├── pipeline/
│   ├── SKILL.md                # 本文件
│   ├── style_contract.json     # 全局风格契约
│   ├── identity_brief.md       # 美术 DNA（从设定.md 提取）
│   └── prompts/
│       ├── _base_template.md   # base 图通用 prompt 模板
│       ├── _row_template.md    # row 通用 prompt 模板
│       └── overrides/          # 每个 subject 的额外指令
│           ├── player_saint.txt
│           ├── enemy_bark_corrupt.txt
│           └── boss_thinforest_deer.txt
├── jobs/                       # 任务图 JSON
│   ├── player_saint_v0.3.json
│   ├── enemy_bark_corrupt_v0.3.json
│   └── room_thinforest_v0.3.json
└── runs/                       # 每次 hatch 的工作目录（gitignore）
    └── <subject>-<timestamp>/
        ├── jobs.json           # 本次任务图快照
        ├── base/               # canonical pose 候选
        ├── rows/               # 各行原始输出（条带）
        ├── decoded/            # 切帧后选中的输出
        ├── final/              # atlas + manifest
        └── qa/
            ├── contact_sheet.png
            ├── previews/*.gif
            └── review.json

tools/art/
├── README.md
├── prepare_run.py
├── extract_strip_frames.py
├── inspect_frames.py
├── compose_atlas.py
├── validate_atlas.py
├── make_contact_sheet.py
├── render_animation_previews.py
├── derive_mirrored_row.py
└── godot_import.py
```

## 图像生成后端（可插拔）

本管线**不绑死任何图像模型**。具体调用通过环境变量决定：

| 环境变量 | 含义 | 示例 |
| --- | --- | --- |
| `ZHEWEI_IMAGEGEN_BACKEND` | 后端名称 | `openai` / `gemini` / `comfyui` / `mock` |
| `OPENAI_API_KEY` | OpenAI 模型 | `gpt-image-1` |
| `GOOGLE_API_KEY` | Gemini / Imagen | `imagen-3` / `gemini-2.5-flash-image` |
| `COMFYUI_HOST` | 本地 ComfyUI | `http://127.0.0.1:8188` |

调用规则：

- Codex 用户：把 `ZHEWEI_IMAGEGEN_BACKEND=codex-imagegen`，调度时直接交给 Codex 的 `$imagegen` skill
- Claude Code 用户：默认 `ZHEWEI_IMAGEGEN_BACKEND=gemini`（Gemini 2.5 Flash Image 角色一致性强）或 `comfyui`（本地 SDXL + IP-Adapter + ControlNet）
- CI / 没有 GPU 也没 API key 时：`ZHEWEI_IMAGEGEN_BACKEND=mock`，用占位灰图跑通管线

`tools/art/prepare_run.py` 在启动时校验后端可用性，缺失则提示用户配置。

## 身份锁定策略

身份漂移（同一角色看起来像两个人）是 sprite sheet AI 化最大的坑。多层防御：

1. **base 是真实源**：所有后续 row 调用图像生成时，必须把 `base/selected.png` 作为参考图传入
2. **过去帧作为运动参考**：生成 `sword-attack-2` 时，把 `sword-attack-1` 的最后一帧作为运动起点参考
3. **风格契约文字提示**：每次 prompt 都拼上 [style_contract.json](style_contract.json) 里的色板和剪影规则
4. **prompt 模板包裹**：用户描述只填进 `<<subject_description>>` 占位符，身份锁定文字模板在外层
5. **IP-Adapter（仅 ComfyUI 后端）**：权重 0.7-0.9 锁定脸部和服装
6. **AI 视觉 QA**：contact sheet 上能看到所有 row 并排，AI 会直接判断身份是否一致

## 两层 QA

### 层 1：确定性脚本验证（阻塞）

由 `tools/art/validate_atlas.py` 产出 `qa/validation.json`，下列任一失败即阻塞封装：

- 透明背景：每帧边缘 8px 内 alpha < 5% 占比 > 95%
- 帧锚点：脚底/中心相对 base 的漂移 ≤ 2px
- 单元格对齐：每帧严格落在 `cell_size` 内，无溢出
- 帧数一致：每行帧数与任务图 schema 一致
- 文件预算：atlas ≤ 4MB、单帧 ≤ 80KB
- 命名一致：`row-<name>-frame-<n>.png` 严格匹配

### 层 2：AI 视觉 QA（必须，阻塞）

视觉 QA worker 看 `qa/contact_sheet.png` + `qa/previews/*.gif` + `qa/identity_strip.png`，输出 `qa/review.json`：

```json
{
  "visual_qa": "pass",
  "qa_note": "整体一致；run-left 第 3 帧斗篷略短，但在可接受范围",
  "repair_rows": [],
  "repair_notes": {}
}
```

或者：

```json
{
  "visual_qa": "fail",
  "qa_note": "sword-attack-1 第 4 帧角色脸部走样，看起来像不同角色",
  "repair_rows": ["sword-attack-1"],
  "repair_notes": {
    "sword-attack-1": "重做时强调脸部锁定，参考 base 第 1 帧；攻击弧可以更明显"
  }
}
```

阻塞清单（必须 fail）：

- 身份漂移（同一角色跨行看起来像不同角色）
- 空帧 / 半空帧 / 复制的引导标记残留
- 非透明背景 / 色键伪影 / 阴影或光晕粘连
- 裁剪到身体或武器
- 运动语义错（idle 在跑、run 不交替、hurt 没有后仰）
- 武器朝向 / 持械手错位
- 风格漂移（笔触、调色板、剪影粗细脱离 style contract）

非阻塞但记录（warn）：

- 单帧微抖（< 3px）
- 阴影位置轻微不稳
- 调色板单值偏移 5% 以内

## 修复循环

由 Claude/Codex 看 `qa/review.json` 决定下一步：

1. **`repair_rows` 不空** → 对每个失败 row 调用 `tools/art/prepare_run.py --repair-row <name>`，重生成该行，喂入 base + 失败说明 + 上次输出的失败帧
2. **`extract_method=auto` 切帧出问题** → 用 `--method stable-slots --allow-stable-slots` 重跑提取，**不重生图**
3. **整体风格漂移** → 重做 base，所有 row 标记 stale；如果 5 轮以内不收敛，停下来人工介入
4. **图像 API 报 4xx/5xx** → 用脚本生成的 `retry_prompt.txt` 重试 1 次；仍失败 → 停下报告

## /hatch-* 命令执行步骤

下面是 Claude/Codex 看到这些命令时的标准执行流程：

### Step 1: 解析意图

- 从命令参数或上下文确定 `subject` 名称、类型（player/enemy/boss/...）、版本号
- 查找现有任务图 `docs/art/jobs/<subject>_<version>.json`；不存在则用模板生成

### Step 2: 准备 run

```bash
python3 tools/art/prepare_run.py \
  --subject <subject> \
  --version <version> \
  --jobs docs/art/jobs/<subject>_<version>.json \
  --output docs/art/runs/<subject>-<timestamp>/
```

校验：

- `identity_brief.md` 存在且包含 subject 段落
- `style_contract.json` 存在且 schema 合法
- 图像生成后端可用（环境变量 + 模型 ping）

### Step 3: 生成 base

调用图像生成后端，prompt = `prompts/_base_template.md` + `style_contract.json` + `prompts/overrides/<subject>.txt` + 任务图 `base.notes`。

通常生成 3-5 张候选，由 AI（或人）选 1 张作为 canonical。candidates 留在 `base/`，选中的复制到 `base/selected.png`。

### Step 4: 按依赖图生成 rows

广度优先：先把 deps 全是已完成的 row 拿出来，最多并发 2 个 worker。每个 row：

- 拼 prompt（base + 依赖 row 选中帧作为参考 + row 描述）
- 调图像生成后端，生成一个"水平条带"图（建议 `frames * 128 × 128` 像素 + 上下少量留白）
- 切帧 → 检查每帧 → 存到 `decoded/<row>/frame-N.png`
- 如果 row 的 `method=mirror` → 直接调 `derive_mirrored_row.py`，不调用图像模型
- 如果 row 的 `method=reverse` → 直接复制倒序

### Step 5: 切帧

```bash
python3 tools/art/extract_strip_frames.py \
  --strip docs/art/runs/<subject>-<timestamp>/rows/<row>/strip.png \
  --frames <frames> \
  --cell-size 128 128 \
  --method auto \
  --output docs/art/runs/<subject>-<timestamp>/decoded/<row>/
```

`--method auto` 会尝试基于 alpha 分布自动找到帧边界；如果失败回退到 `stable-slots`（按等分槽位切）。

### Step 6: 合成 atlas

```bash
python3 tools/art/compose_atlas.py \
  --run-dir docs/art/runs/<subject>-<timestamp>/ \
  --grid 8 12 \
  --cell-size 128 128 \
  --output docs/art/runs/<subject>-<timestamp>/final/spritesheet.png
```

同时生成 `final/manifest.json`（记录每行帧数、起始单元格、帧率）。

### Step 7: 脚本验证

```bash
python3 tools/art/validate_atlas.py \
  --atlas docs/art/runs/<subject>-<timestamp>/final/spritesheet.png \
  --manifest docs/art/runs/<subject>-<timestamp>/final/manifest.json \
  --output docs/art/runs/<subject>-<timestamp>/qa/validation.json
```

任一阻塞项失败 → 进入修复循环。

### Step 8: contact sheet + GIF

```bash
python3 tools/art/make_contact_sheet.py --run-dir ...
python3 tools/art/render_animation_previews.py --run-dir ... --fps 12
```

### Step 9: AI 视觉 QA

Claude/Codex 自己读 `qa/contact_sheet.png` 和 `qa/previews/*.gif`，按上面"层 2 阻塞清单"逐项判断，写出 `qa/review.json`。

### Step 10: 修复或封装

- `visual_qa=fail` → 修复循环
- `visual_qa=pass` → 进入封装

### Step 11: 封装到 Godot

```bash
python3 tools/art/godot_import.py \
  --run-dir docs/art/runs/<subject>-<timestamp>/ \
  --target game/art/sprites/<subject>/
```

生成：

- `game/art/sprites/<subject>/spritesheet.png`
- `game/art/sprites/<subject>/anim.tres`（SpriteFrames 资源，自动产 `idle`、`run-right`、`run-left`、... 每个动画名）
- `game/art/sprites/<subject>/import.json`（manifest 副本，给 godot_import.py 增量更新用）
- 如果 base 已被接受，也可提交 `game/art/source/<subject>/base_<version>.png` 和对应 prompt，作为后续 row 生成的身份参考。`docs/art/runs/` 仍是中间产物目录，不入库。

### Step 12: 报告

输出给用户的总结：

- 任务耗时、API 调用次数 / 成本估算
- 修复轮次和最终 QA 结果
- 生成的文件路径
- 已知 warn（非阻塞）
- 下一步建议（替换占位、跑 smoke test、人工抽检）

## 模式开关

`--mode=quick`：只生成 base + idle + run-right + 1 个 attack，用于风格快速预览。约 5 张图，1-2 分钟。

`--mode=full`：任务图里所有 row。约 80-120 张图，10-30 分钟。

`--mode=repair`：只重做 `--repair-row` 指定的 row（默认从 `qa/review.json` 读取 `repair_rows`）。

`--mode=resume`：从 `runs/<subject>-<timestamp>/jobs.json` 的 state 字段恢复中断的运行。

## 退路：无图像模型时如何 dry-run

若 `ZHEWEI_IMAGEGEN_BACKEND=mock`：

- 每个 row 用 PIL 生成"灰色矩形 + 行名水印 + 帧号"的占位条带
- 所有脚本（切帧/atlas/contact sheet/GIF/Godot 导入）全部跑通
- AI 视觉 QA 在 mock 模式下跳过身份判断，只做"帧数齐全"
- 用于 CI、用于工程师在没有 GPU/API key 时验证管线本身

## 与现有项目验收的关系

- `python3 tools/verify_scaffold.py` 不受影响（本管线产物在 `game/art/sprites/`，不动核心 scaffold）
- `godot4 --headless --path . --quit` 必须不被新 sprite 资源破坏
- v0.3 验收（[../iterations/v0.3_art_weapon_vertical_slice.md](../../iterations/v0.3_art_weapon_vertical_slice.md)）中"20 秒战斗片段录像、动作不卡顿"由本管线产出的 AnimatedSprite2D 资源支撑

## 参考

- OpenAI Hatch Pet SKILL.md：<https://github.com/openai/skills/blob/main/skills/.curated/hatch-pet/SKILL.md>
- 折维圣徒美术总览：[../animation_pipeline.md](../animation_pipeline.md)
- v0.3 验收文档：[../../iterations/v0.3_art_weapon_vertical_slice.md](../../iterations/v0.3_art_weapon_vertical_slice.md)
- Godot SpriteFrames 文档：<https://docs.godotengine.org/en/stable/classes/class_spriteframes.html>
