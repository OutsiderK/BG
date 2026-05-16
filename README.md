# 折维圣徒 Demo v0

Godot 4 roguelike 原型工程。当前目标是先跑通一个可玩的单房间 demo，验证移动、战斗、圣痕热度、平面展开、坍缩、HUD 和死亡结算。

## 快速运行

主场景已配置为：

```text
game/scenes/main/Main.tscn
```

在 Linux/macOS 或装好 Godot CLI 的环境中：

```bash
godot --path .
```

如果命令名是 `godot4`：

```bash
godot4 --path .
```

Windows 同步和运行方式见 [docs/windows_godot_runbook.md](docs/windows_godot_runbook.md)。

## 当前分支

Demo v0 集成分支：

```bash
git switch feat/demo-v0-integration
```

## 当前操作

- `A/D`：左右移动
- `W`：跳跃
- `Space`：冲刺
- 鼠标左键：剑攻击
- `1`：平面展开 / 提前坍缩
- `E`：交互预留

## 本地校验

```bash
python3 tools/verify_scaffold.py
```

如果安装了 Godot CLI：

```bash
godot --headless --path . --quit
```

敌人 AI smoke test：

```bash
godot4 --headless --path . --script tools/godot/enemy_ai_smoke.gd
```

## 下一步

下一轮工程优先级见 [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md)。
