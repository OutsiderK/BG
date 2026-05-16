# Base canonical pose prompt 模板

本模板由 `tools/art/prepare_run.py` 在生成 base 时拼装，占位符按下列规则替换。

## 调用合约

输入变量：

- `<<subject_kind>>`：`player_saint` / `common_enemy` / `boss` / `weapon` / `room_layer` / `fx` / `ui_icon`
- `<<subject_name>>`：例如 `折维圣徒`、`薄林腐化物`、`薄林鹿王`
- `<<identity_excerpt>>`：从 [../identity_brief.md](../identity_brief.md) 提取的对应 subject 段落（视觉关键词、比例、色板、"不要"清单）
- `<<style_global_prefix>>`：[../style_contract.json](../style_contract.json) `prompt_locked_phrases.global_prefix`
- `<<style_global_negative>>`：[../style_contract.json](../style_contract.json) `prompt_locked_phrases.global_negative`
- `<<base_notes>>`：任务图 `base.notes` 字段
- `<<cell_size_w>>`、`<<cell_size_h>>`：单帧尺寸

## 模板

```
<<style_global_prefix>>

Subject: <<subject_name>>
Subject kind: <<subject_kind>>

== Identity ==
<<identity_excerpt>>

== Base pose requirements ==
- Single character / object, centered in frame.
- Standing neutral facing right (or "front" for room layers, "isometric" for fx).
- Full body visible with 6px safe margin to each edge of a <<cell_size_w>>x<<cell_size_h>> canvas.
- Treat this as the canonical reference image: every subsequent animation row will use this image as the identity anchor.
- Composition: clean silhouette readable at 1/4 scale.
- <<base_notes>>

== Hard constraints ==
- 2px outline #0F1418, no rim light, no cast shadow.
- Transparent background. Pure transparency outside the silhouette.
- Color palette strictly within the subject palette from identity_brief.
- No text, no watermark, no signature, no UI overlay.

Negative: <<style_global_negative>>
```

## 调度

- 通常生成 3-5 张候选（temperature 略高），AI 视觉 QA 选 1 张作为 canonical
- 候选保存到 `runs/<subject>-<ts>/base/candidate-N.png`
- 选中的复制到 `runs/<subject>-<ts>/base/selected.png`

## 失败重试

如果 base 第一轮无可用候选：

1. 检查 `<<identity_excerpt>>` 是否抓取错误段落（最常见）
2. 检查 `prompt_overrides` 是否冲突
3. 第二轮：把 negative prompt 加强，明确写出"不要" 清单中的具体内容
4. 仍不可用：停下，让用户检查 `identity_brief.md` 或调整 `style_contract.json` 调色板
