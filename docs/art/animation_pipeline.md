# 高质量 2D 动画工具链

状态：v0.3 采用的动画管线决策稿。

## 结论

如果目标是“高要求、流畅、可扩展”的 2D 动画，主角、主要敌人和武器动画不应该主要依赖 Godot 内建节点手工补间，也不应该只用逐帧 sprite sheet 硬堆。当前项目建议采用：

**主动画管线：Spine 2D + spine-godot runtime**

**辅助管线：Godot AnimationPlayer/AnimationTree + 少量逐帧 sprite sheet**

这套组合的原因很直接：Spine 更适合做角色骨骼、网格变形、IK、换装/换武器、动画混合和事件帧；Godot 负责玩法状态机、碰撞、FX 生命周期、HUD 和相机。逐帧动画只用于剑气、命中爆点、灾厄裂纹、死亡碎片等高冲击短效果。

## 工具分工

| 工具 | 用途 | 在本项目中的定位 |
| --- | --- | --- |
| Spine 2D | 角色骨骼动画、网格变形、IK、皮肤/附件、动画事件 | 主角、普通敌人、精英/Boss、武器挂点的主方案 |
| spine-godot | 在 Godot 中播放 Spine 动画 | 把 Spine 导出的骨骼动画接入 Godot 4 项目 |
| Godot AnimationPlayer/AnimationTree | 动画状态切换、混合、UI/FX/相机动画 | 驱动游戏状态，不作为复杂角色主编辑器 |
| Toon Boom Harmony / Krita / Clip Studio | 高质量逐帧特效或关键表演帧 | 攻击残影、爆点、死亡碎片、过场短动画 |
| Aseprite | 小尺寸 sprite、像素风 FX、快速 sprite sheet | 可做临时 FX 或小图标，不作为本项目主角主动画方案 |
| TexturePacker 或同类 atlas 工具 | 打包逐帧 FX 图集 | 控制贴图尺寸和 draw call |

## 为什么不是只用 Godot 内建动画

Godot 本身有很强的动画系统，也支持 `AnimatedSprite2D`、`AnimationPlayer`、`AnimationTree` 和 2D skeleton。它适合项目集成和状态控制，但对高质量角色生产来说，问题在于：

- 复杂角色在 Godot 里直接绑骨、调权重、调曲线，效率不如专门动画软件。
- 多个角色、多把武器、多套皮肤时，资产复用和动画版本管理会变重。
- 攻击动画需要挂点、事件帧、混合、取消窗口、命中帧对齐，专门工具更稳。
- 高要求动画不是“能动”就够，而是要能快速迭代、稳定复用、方便美术人员工作。

所以 Godot 内建动画保留，但定位为运行时编排层。

## 为什么首选 Spine

Spine 的官方 runtime 覆盖 Godot，并且官方说明 runtime 用于在游戏工具链中还原 Spine 动画、支持混合和运行时控制。对本项目最关键的是：

- 角色可以骨骼驱动，不需要每个动作都画完整帧。
- 支持网格变形，斗篷、树皮敌人、灾厄裂纹可以更顺。
- 支持皮肤/附件，后续武器、圣痕、装备表现能复用。
- 支持事件帧，可以把攻击命中帧、脚步、音效、残影生成点和玩法脚本对齐。
- 支持动画混合，idle/run/attack/hurt/dash/unfold 之间能减少生硬切换。

代价：

- Spine 编辑器是商业软件，需要预算。
- Godot 侧要引入 spine-godot runtime，构建和导出流程比纯 GDScript 更复杂。
- CI/headless 和 Windows 导出要专门验证 runtime 插件。

结论：如果你对美工要求高，这个代价是合理的。

## 动画质量标准

### 运行标准

- 游戏运行目标：60 FPS。
- 角色动画播放必须支持平滑插值，不能出现肉眼明显卡帧。
- 攻击动作允许快，但必须有预备、命中、收招三个可读阶段。
- 命中帧必须和碰撞激活帧对齐，误差目标小于 `33ms`。
- 动画切换不能让角色脚底、武器挂点或碰撞中心明显漂移。

### 主角最低动作集

v0.3 要求做“完整主角垂直切片”，不是最终全动作库。

| 动作 | 规格 |
| --- | --- |
| idle | 1 套，可循环，斗篷/呼吸/圣痕微动 |
| run | 1 套，可循环，脚底接触点稳定 |
| jump_start | 起跳前 4-6 帧感觉，不能像瞬移 |
| fall | 下落姿态，和 jump_start 能顺接 |
| dash | 0.12 秒左右，可配残影，方向清楚 |
| sword_attack_1 | 横斩，命中帧清晰 |
| sword_attack_2 | 返斩或下劈，给后续连段留口 |
| hurt | 受击后仰，0.15-0.25 秒 |
| death | 可先做短版，身体碎成坐标片或跪倒去饱和 |
| unfold_enter | 被压成平面/坐标锁定的短动作 |
| unfold_loop | 展开状态悬浮或俯视姿态 |
| unfold_exit | 坍缩回横版的短动作 |

### 敌人最低动作集

| 动作 | 规格 |
| --- | --- |
| idle | 可循环，轮廓有生命感 |
| move | 与当前追击速度匹配 |
| telegraph | 攻击前摇，至少 `0.35s` 可读 |
| attack | 命中帧和攻击区域对齐 |
| hurt | 可打断感明确 |
| death | 碎裂/散落/淡出 |

### 剑与武器表现

- 剑不只是贴在手上，必须绑定到武器挂点。
- 攻击时剑身、手臂、攻击弧、命中盒同方向。
- 攻击弧可以用 Spine slot、Godot Line2D/Polygon2D 或短 sprite sheet，但生命周期由攻击动画事件驱动。
- 后续 6 武器都要遵守同一接口：`weapon_socket`、`hit_frame_event`、`fx_spawn_event`、`recovery_event`。

## Godot 接入策略

### v0.3 原型目标

v0.3 不要求一次性把 spine-godot runtime 完全集成到最终结构，但必须完成一次可验证的技术探针：

- 在 `addons/` 或明确目录中引入 spine-godot 的最小可运行方案，或先建立外部依赖说明。
- 新建一个 `AnimatedActor` 包装层，玩法脚本只调用 `play_state("run")`、`play_attack("sword_attack_1")`、`set_facing()`。
- 攻击命中帧由动画事件或兼容接口触发，而不是写死在视觉节点里。
- 如果 runtime 集成在当前环境受阻，必须用 Godot 原生 `AnimationPlayer` 做一个同接口替身，保证后续可替换为 Spine。

### 文件建议

```text
game/art/
  source/
    spine/
      player/
      enemies/
      weapons/
    frame_fx/
  exported/
    spine/
    atlases/
game/scenes/actors/
game/scripts/actors/animated_actor.gd
game/scripts/animation/animation_event_bridge.gd
docs/art/animation_pipeline.md
```

### 命名规范

- 动画状态名使用小写蛇形：`idle`、`run`、`dash`、`sword_attack_1`。
- 事件名使用玩法含义：`hit_start`、`hit_end`、`spawn_fx`、`footstep`、`recoverable`。
- 武器挂点统一：`weapon_socket_main`、`weapon_socket_back`。
- 脚底定位点统一：`ground_anchor`。

## 备选方案

### 预算不足：Godot 原生骨骼 + AnimationTree

可行，但只建议用于 demo 或小规模角色。优点是免费、无外部 runtime；缺点是美术生产效率和复杂动作质量上限较低。

### 强逐帧风格：Toon Boom / Krita / Clip Studio + sprite sheet

画面上限很高，但制作成本高、资源体积大，动作改动贵。适合关键攻击、死亡、Boss 特写，不适合作为所有角色的基础移动和普攻主方案。

### 像素风：Aseprite + Godot importer

如果项目改成像素美术，Aseprite 是很好的选择。但当前“折维圣徒”的二维封印、斗篷、树皮敌人、空间压缩效果更适合骨骼 + 变形 + 局部逐帧 FX。

### Rive / DragonBones

Rive 更偏 UI/矢量交互，Godot 游戏角色战斗管线风险较高。DragonBones 有免费优势，但 Godot 4 生态和长期维护确定性不如 Spine，不建议作为核心管线。

## 验收方式

v0.3 美术验收不只看截图，还要看动起来：

- 录制 20 秒战斗片段：跑动、跳跃、冲刺、两段剑击、受击、展开、坍缩。
- 角色动作没有明显卡顿、脚滑、武器漂移。
- 攻击命中帧和视觉弧线一致。
- 同一角色从 idle 到 run 到 attack 到 hurt 的切换没有突然缩放或穿帮。
- Godot headless 可加载，Windows Godot 可运行。

## 参考

- Spine Godot runtime 文档：https://us.esotericsoftware.com/spine-godot
- Spine runtimes 总览：https://us.esotericsoftware.com/spine-runtimes
- Godot AnimationTree 文档：https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html
- Godot 2D skeletons 文档：https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html
- Godot 2D sprite animation 文档：https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html
- Toon Boom Harmony game export 说明：https://helpcentre.toonboom.com/hc/en-ca/articles/41025010026771-What-are-the-different-types-of-game-exports-in-Harmony
