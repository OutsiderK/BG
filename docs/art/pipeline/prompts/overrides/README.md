# Prompt overrides 目录

每个 hatch subject 可以在本目录放一个 `<subject>.txt`（或 `.md`），内容会被附加到 `_base_template.md` 和 `_row_template.md` 的 prompt 中，作为额外指令。

## 用途

- subject 级别的特殊指令，不适合放进全局 [../identity_brief.md](../identity_brief.md) 或 [../style_contract.json](../style_contract.json)
- 临时实验的 prompt 微调，不污染主文档
- 特殊场合的 hard override（例如 Boss 第二阶段独立的 sprite sheet）

## 文件命名

与任务图 JSON 同名（去掉版本后缀）：

- `player_saint.txt` ↔ `docs/art/jobs/player_saint_v0.3.json`
- `enemy_bark_corrupt.txt` ↔ `docs/art/jobs/enemy_bark_corrupt_v0.3.json`
- `boss_thinforest_deer.txt` ↔ `docs/art/jobs/boss_thinforest_deer_v0.3.json`

## 内容惯例

```
== Subject-specific style ==
（不超过 5-8 行额外说明，针对单一 subject）

== Subject-specific don't ==
（不超过 5 行，对该 subject 特别需要避免的内容）

== Subject-specific phrases to include verbatim ==
（如果某个标志性视觉描述必须照原文进入 prompt，写在这里）
```

## 当前 v0.3 占位

`v0.3` 阶段优先 subject：

- `player_saint.txt`：主角覆盖（初版尚未需要 override，可保持空文件或不创建）
- `enemy_bark_corrupt.txt`：薄林腐化物覆盖
- `boss_thinforest_deer.txt`：薄林鹿王覆盖

不创建空文件——只有真需要的时候才加 override，避免维护负担。
