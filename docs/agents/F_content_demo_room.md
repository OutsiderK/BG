# Agent F: Content Demo Room

## Branch

`feat/content-demo-room`

## Goal

制作巨木薄林 Demo 测试房：横版地面、几个障碍物、展开 lane、敌人出生点、基础房间流程。

## Owned Files

- `game/scenes/rooms/**`
- `game/scripts/rooms/**`
- `game/data/rooms/**`
- 可修改：`game/scenes/main/Main.tscn` 用于实例化 DemoRoom

## Do Not Touch

- `project.godot`
- `game/scripts/player/**`
- `game/scripts/enemies/**`
- `game/scripts/unfold/**`，除非只填写房间 lane 数据
- `game/scripts/ui/**`

## Tasks

1. 创建 `DemoRoom.tscn`，主题为巨木薄林测试房。
2. 放置横版地面和 2-3 个障碍/平台占位。
3. 定义 3-5 条展开 lane。
4. 放置玩家出生点、敌人出生点和坍缩重定位点。
5. 清房后预留门选择/下一房入口占位。
6. 不做美术精修，只做可玩碰撞和映射数据。

## Acceptance

- 主场景能进入 DemoRoom。
- 展开系统可以读取或约定使用该房间 lane。
- `python3 tools/verify_scaffold.py` 通过。

