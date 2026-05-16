# Agent D: Unfold System

## Branch

`feat/unfold-system`

## Goal

实现平面展开核心：按 `1` 展开/主动结束、过渡状态、热度消耗、风险/侵蚀增加、玩家和敌人的坐标映射、受击坍缩接口。

## Owned Files

- `game/scripts/unfold/**`
- `game/scripts/rooms/room_lane_profile.gd`
- 可新增：`game/scripts/rooms/**`
- 可新增：`game/data/rooms/**`
- 可新增：`game/scenes/rooms/**`

## Do Not Touch

- `game/scripts/player/player_controller.gd`，除非只调用公开接口并在 PR 中说明。
- `game/scripts/enemies/**`，除非只调用 `enter_unfolded(lane)` / `exit_unfolded()`。
- `game/scripts/ui/**`

## Tasks

1. `UnfoldManager` 状态机：Vertical、Transition、Unfolded、Cooldown。
2. 按 `1` 展开；展开中再按 `1` 主动结束。
3. 展开期间按 5 热度/秒消耗；热度上限越高，展开越久。
4. 自然结束：风险 +0.5%，侵蚀 +1。
5. 主动结束：风险 +0.2%，侵蚀 +0.5。
6. 坍缩：风险 +1%，侵蚀 +2，热度归零。
7. 单局展开风险增量上限 +4%。
8. 坐标映射：玩家 X 保留；敌人 X 保留，Z 按房间 lane。
9. 坍缩还原：玩家吸附最近平台；幸存敌人吸附最近合法地面点。

## Acceptance

- 符合 [spec_展开机制.md](../../spec_展开机制.md)。
- `python3 tools/verify_scaffold.py` 通过。
- 可在主场景中看到展开状态开始、结束、风险和侵蚀变化。

