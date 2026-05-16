# Row strip prompt 模板

本模板由 `tools/art/prepare_run.py` 在生成每一行动作条带时拼装。

## 调用合约

输入变量：

- `<<subject_name>>`、`<<subject_kind>>`：同 base
- `<<row_name>>`：例如 `idle`、`run-right`、`sword-attack-1`、`hurt`、`unfold-enter`
- `<<row_frames>>`：本行帧数
- `<<row_semantics>>`：该 row 的运动语义说明（见下表）
- `<<row_phases>>`：阶段分解（如 attack 的 windup/hit/recovery；hurt 的 impact/recover）
- `<<cell_size_w>>`、`<<cell_size_h>>`
- `<<strip_total_w>>`：`cell_size_w * row_frames`
- `<<base_reference_path>>`：base canonical pose 图路径（作为参考图传给图像 API）
- `<<dep_reference_paths>>`：依赖 row 的选中帧路径数组
- `<<style_global_prefix>>`、`<<style_global_negative>>`：同 base
- `<<identity_excerpt>>`：同 base

## row 语义表

| row_name | row_semantics |
| --- | --- |
| `idle` | 静止呼吸循环；幅度 ≤ 2px；斗篷或圣痕微动；不能僵死、不能漂移；首末帧可衔接 |
| `run-right` | 向右奔跑步态循环；交替左右脚；首末帧可衔接；脚底锚点严格稳定；不能漂浮 |
| `run-left` | 通常通过镜像 `run-right` 衍生，跳过本模板 |
| `jump-start` | 起跳前压腿 + 离地一瞬；不能像瞬移；要有膝盖弯曲与重心下沉 |
| `fall` | 下落姿态；身体略向下；斗篷向上扬；可循环 |
| `dash` | 横向冲刺；身体前倾；可带 1-2 个残影；末帧回到接近 idle 姿态便于衔接 |
| `sword-attack-1` | 横斩；阶段为 windup → hit → recovery；hit 帧剑身水平展开 |
| `sword-attack-2` | 返斩或下劈，给连段留口；区别于 sword-attack-1 的轨迹方向 |
| `hurt` | 受击后仰；阶段为 impact → recover；持续 0.15-0.25s；身体压缩感 |
| `death` | 跪倒或被压扁为坐标碎片；最后一帧逐渐淡出但保留剪影残形 |
| `unfold-enter` | 角色被压成更扁的薄片、圣痕亮起；身体短暂分解成几何坐标片 |
| `unfold-loop` | 展开状态下的悬浮或俯视姿态；可循环；坐标线在体周环绕 |
| `unfold-exit` | 通常通过倒序 `unfold-enter` 衍生 |

## 模板

```
<<style_global_prefix>>

Subject: <<subject_name>>
Row: <<row_name>>
Frame count: <<row_frames>>

== Identity (anchor — must match the reference image exactly) ==
<<identity_excerpt>>

== Motion ==
<<row_semantics>>

Phase breakdown:
<<row_phases>>

== Strip layout ==
Render as a horizontal strip of <<row_frames>> frames, each frame <<cell_size_w>>x<<cell_size_h>>.
Total strip size: <<strip_total_w>>x<<cell_size_h>>.
- Each frame must be tightly aligned to its cell; do not leak across cell boundaries.
- Frames read left-to-right in time order.
- Frame 1 must read as the natural starting pose of this motion.
- For loopable rows (idle / run / unfold-loop), frame N must connect seamlessly back to frame 1.
- Foot anchor point (or visual center for airborne motions) must stay within ±2px across all frames.

== Hard constraints ==
- 2px outline #0F1418, no cast shadow, no rim light, no glow halo, no smoke trail.
- Transparent background. Each cell's edge 8px must be empty.
- Identity must match the supplied reference image (same face/cape/weapon/color/proportion).
- Stay strictly within the subject color palette from identity_brief.
- No text, no watermark, no signature, no UI overlay, no frame numbers, no margin labels, no checkered background.

Negative: <<style_global_negative>>
```

## 参考图传入约定

不同后端调用方式不同，但语义相同——把这些图作为视觉参考输入：

| 类型 | 内容 | 权重建议 |
| --- | --- | --- |
| `identity_reference` | `<<base_reference_path>>` | 高（0.85-0.95） |
| `motion_reference` | `<<dep_reference_paths>>` 中最末一帧 | 中（0.5-0.7） |
| `pose_skeleton`（仅 ComfyUI + ControlNet 时） | stickfigure 骨架图 | 高（0.8） |

## 失败重试规则

- AI 视觉 QA 返回 `repair_rows` 包含本 row → 重新调用本模板，但 prompt 中追加 `repair_notes` 文字
- 切帧失败（透明区不清晰、帧边界不准） → **先重跑 `extract_strip_frames.py --method stable-slots --allow-stable-slots`，不重生图**
- 第 N+1 轮仍失败：停下报告，把失败 row 名、retry_prompt 路径、最后一次 review.json 一并交回
