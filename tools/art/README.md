# tools/art — AI 美工管线脚本

确定性脚本部分，对应 [../../docs/art/pipeline/SKILL.md](../../docs/art/pipeline/SKILL.md) 的"几何 / 切帧 / 验证 / 打包"阶段。所有脚本只做"图像处理 + 文件 IO"，不调用图像生成 API；API 调用由 Claude/Codex 在跑 `/hatch-*` 时通过 Bash 间接驱动。

## 依赖

```
Python 3.10+
Pillow >= 10.0
```

只用 Pillow + 标准库。**故意不引入 numpy/opencv**，让 CI / Windows 用户能 `pip install Pillow` 一行装完。

CI 验证用：

```bash
pip install Pillow
python3 tools/art/prepare_run.py --backend mock --subject player_saint --version v0.3 --dry-run
```

## 脚本清单

| 脚本 | 作用 | 输入 | 输出 |
| --- | --- | --- | --- |
| `prepare_run.py` | 准备 run 目录、加载任务图、校验后端、初始化 jobs.json 状态 | `--subject` + `--version` + `--jobs` JSON | `docs/art/runs/<subject>-<ts>/` |
| `extract_strip_frames.py` | 从水平条带切出单帧 | `--strip` + `--frames` + `--method` | `decoded/<row>/frame-N.png` |
| `inspect_frames.py` | 帧质量检查（透明度、锚点漂移） | `decoded/<row>/` | `qa/inspect_<row>.json` |
| `compose_atlas.py` | 把所有 row 合成最终 atlas | run dir + grid 配置 | `final/spritesheet.png` + `final/manifest.json` |
| `validate_atlas.py` | 层 1 确定性验证 | atlas + manifest | `qa/validation.json` |
| `make_contact_sheet.py` | 生成 contact sheet（给 AI 视觉 QA 看） | run dir | `qa/contact_sheet.png` |
| `render_animation_previews.py` | 每行生成 GIF 预览 | run dir + fps | `qa/previews/<row>.gif` |
| `derive_mirrored_row.py` | 镜像衍生（如 run-left = run-right 翻转） | 源 row 帧 | 目标 row 帧 |
| `godot_import.py` | 复制 atlas 到 `game/art/sprites/` + 生成 manifest / 可选 `anim.tres` | run dir + 目标路径 | Godot 可消费的 sprite 资源目录 |

## 调用顺序

标准 `/hatch-*` 流程：

```
prepare_run.py
  └── (Claude/Codex 调图像 API 生成 base + 每行 strip)
extract_strip_frames.py   # 每行一次
inspect_frames.py         # 每行一次
derive_mirrored_row.py    # 仅 method=mirror 的行
compose_atlas.py
validate_atlas.py         # 层 1 验证（脚本）
make_contact_sheet.py
render_animation_previews.py
  └── (Claude/Codex 看 contact sheet + GIF 做层 2 AI 视觉 QA)
  └── (修复循环：失败行重跑 extract/inspect)
godot_import.py
```

## 退路：mock 后端

任何脚本都支持 mock 输入。在没有 GPU / API key 的环境（CI / 没图像模型的工程师机器）下：

```bash
ZHEWEI_IMAGEGEN_BACKEND=mock python3 tools/art/prepare_run.py --subject player_saint --version v0.3
```

`prepare_run.py` 会自己生成"灰色矩形 + 帧号水印"的占位条带，后续脚本全部跑通。这样 CI 可以验证管线骨架本身，不依赖任何外部模型。

## 与 `tools/verify_scaffold.py` 的关系

`verify_scaffold.py` 在每次 PR 都跑一遍。不要在它里面强制要求 `game/art/sprites/<subject>/spritesheet.png` 存在——AI 生成 sprite 是异步的任务，分支可能在没有 sprite 的状态下提交。`game/scripts/actors/animated_actor.gd` 必须能在没有 sprite 资源时优雅降级到 ColorRect 占位。

Godot 集成优先读取 `spritesheet.png` + `manifest.json` 并在运行时构造 `SpriteFrames`。这是为了避免 headless/CI 环境依赖 `.import` 产物；`anim.tres` 可以继续作为工具输出和编辑器辅助资源，但不要让玩法场景直接依赖它。

## 常见问题

**Q: 这些脚本能不能在 Windows 上跑？**
A: 全部用 `pathlib` + Pillow，理论上跨平台。Windows 用户跑前确保 `pip install Pillow` 完成。

**Q: 图像 API 调用谁负责？**
A: 不是这些脚本。是 Claude Code 或 Codex 在执行 `/hatch-*` 流程时通过 Bash 调用图像 API（或 `$imagegen` skill）。脚本只负责"图像已经在磁盘上之后的事"。

**Q: 为什么不用 opencv？**
A: 安装麻烦，CI 上拖慢启动。Pillow 已经足够：基本的 alpha 检测、裁剪、调整大小、合成都覆盖。

**Q: 如果某个脚本失败了，下游脚本怎么办？**
A: 每个脚本失败时 exit code 非 0，并把错误信息写到 `qa/<stage>_error.json`。Claude/Codex 看到 exit 非 0 必须停下报告，不要硬跑下游。
