# Agent Task Board

这些任务单用于多 agent 并行开发 Demo v0。每个 agent 应在独立分支上工作，并只修改自己任务单声明的文件范围。

## 推荐合并顺序

1. `feat/project-foundation`
2. `feat/player-controller`
3. `feat/combat-enemy`
4. `feat/unfold-system`
5. `feat/hud-run-state`
6. `feat/content-demo-room`

## 通用验收

每个 agent 完成后至少运行：

```bash
python3 tools/verify_scaffold.py
git status --short
```

如果本机有 Godot 4 CLI，再运行：

```bash
godot --headless --path . --quit
```

## 任务单

- [A_project_foundation.md](A_project_foundation.md)
- [B_player_controller.md](B_player_controller.md)
- [C_combat_enemy.md](C_combat_enemy.md)
- [D_unfold_system.md](D_unfold_system.md)
- [E_hud_run_state.md](E_hud_run_state.md)
- [F_content_demo_room.md](F_content_demo_room.md)

## 当前迭代

- 总路线图：[../ROADMAP.md](../ROADMAP.md)
- v0.1 手感闭环：[../iterations/v0.1_handfeel_loop.md](../iterations/v0.1_handfeel_loop.md)
- v0.1 prompts：[V0_1_PROMPTS.md](V0_1_PROMPTS.md)
- v0.2 展开可读性：[../iterations/v0.2_unfold_readability.md](../iterations/v0.2_unfold_readability.md)
- v0.2 prompts：[V0_2_PROMPTS.md](V0_2_PROMPTS.md)
- v0.3 美术与武器垂直切片：[../iterations/v0.3_art_weapon_vertical_slice.md](../iterations/v0.3_art_weapon_vertical_slice.md)
- v0.3 高质量动画工具链：[../art/animation_pipeline.md](../art/animation_pipeline.md)
- v0.3.1 主角动作与剑 FX prompts：[V0_3_1_PLAYER_ART_PROMPTS.md](V0_3_1_PLAYER_ART_PROMPTS.md)
