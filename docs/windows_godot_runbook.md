# Windows 同步与 Godot 运行手册

这份手册用于把当前 Godot 工程同步到 Windows 电脑，并在 Windows 上运行 Demo v0。

## 目标状态

- Windows 电脑安装 Git for Windows。
- Windows 电脑安装 Godot 4.x。
- 项目通过 GitHub 仓库同步：`https://github.com/OutsiderK/BG.git`
- 运行分支：`feat/demo-v0-integration`
- 主场景：`game/scenes/main/Main.tscn`

## 1. 在开发机推送当前 Demo 分支

在当前 Linux 工作区执行：

```bash
cd /home/coder/workspace/Work/CBZ
git switch feat/demo-v0-integration
git status --short
python3 tools/verify_scaffold.py
git push -u origin feat/demo-v0-integration
```

如果之后新增了文档或修复提交，继续执行：

```bash
git push
```

## 2. Windows 第一次同步

目标位置：`C:\Users\joeyK\BG`

### 方式 A：一键引导脚本（推荐）

安装 Git for Windows 后，打开 PowerShell（普通用户即可，不需要管理员）：

```powershell
$bootstrapUrl = "https://raw.githubusercontent.com/OutsiderK/BG/feat/demo-v0-integration/tools/windows/bootstrap.ps1"
Invoke-WebRequest $bootstrapUrl -OutFile "$env:TEMP\bg_bootstrap.ps1"
powershell -ExecutionPolicy Bypass -File "$env:TEMP\bg_bootstrap.ps1"
```

脚本会：

1. 确认 / 创建 `C:\Users\joeyK\BG`。
2. 如果目录已经是仓库就 `git pull`，否则 `git clone`。
3. 切到 `feat/demo-v0-integration` 分支。

### 方式 B：手动命令

```powershell
cd C:\Users\joeyK
git clone https://github.com/OutsiderK/BG.git BG
cd BG
git switch feat/demo-v0-integration
```

如果 `C:\Users\joeyK` 已经存在同名 `BG` 目录但里面不是仓库，先把它改名或删掉再 clone。

## 3. Windows 日常同步更新

每次 Linux 端推送新提交后，在 Windows PowerShell 执行下面任意一种：

### 方式 A：纯同步

```powershell
cd C:\Users\joeyK\BG
powershell -ExecutionPolicy Bypass -File .\tools\windows\sync_project.ps1
```

### 方式 B：同步并直接运行

```powershell
cd C:\Users\joeyK\BG
powershell -ExecutionPolicy Bypass -File .\tools\windows\sync_and_run.ps1
```

### 方式 C：手动命令

```powershell
cd C:\Users\joeyK\BG
git fetch origin
git switch feat/demo-v0-integration
git pull --ff-only origin feat/demo-v0-integration
```

## 4. 安装 Godot

推荐使用 Godot 4.x。当前工程的 `project.godot` 使用 Godot 4.2 工程格式，Godot 4.2 或更高的 4.x 版本通常可以打开。

两种常见方式：

1. 从 Godot 官网下载 Windows 版，把 `Godot_v4.x...exe` 放到固定目录，例如 `D:\Tools\Godot\Godot.exe`。
2. 把 Godot 可执行文件所在目录加入 Windows `PATH`，让 PowerShell 能直接运行 `godot` 或 `godot4`。

如果不想改 `PATH`，可以在运行前设置环境变量：

```powershell
$env:GODOT_EXE = "D:\Tools\Godot\Godot.exe"
```

## 5. Windows 运行 Demo

方式 A：用脚本运行（自动找 Godot）。

```powershell
cd C:\Users\joeyK\BG
powershell -ExecutionPolicy Bypass -File .\tools\windows\run_demo.ps1
```

方式 B：同步 + 运行一步到位。

```powershell
cd C:\Users\joeyK\BG
powershell -ExecutionPolicy Bypass -File .\tools\windows\sync_and_run.ps1
```

方式 C：直接命令。

```powershell
cd C:\Users\joeyK\BG
godot --path .
```

如果命令名是 `godot4`：

```powershell
godot4 --path .
```

方式 D：用 Godot 编辑器运行。

1. 打开 Godot。
2. 选择 Import / 导入。
3. 选择 `C:\Users\joeyK\BG\project.godot`。
4. 打开工程后按 `F5`。
5. 若提示选择主场景，选择 `game/scenes/main/Main.tscn`。

## 6. Demo 操作

- `A/D`：左右移动
- `W`：跳跃
- `Space`：冲刺
- 鼠标左键：剑攻击
- `1`：平面展开 / 提前坍缩
- `E`：交互预留

## 7. Windows 校验

同步后可以先跑静态校验：

```powershell
cd C:\Users\joeyK\BG
python tools\verify_scaffold.py
```

如果 PowerShell 能找到 Godot CLI，按顺序跑 smoke tests。不要并行启动多个 Godot headless 进程，部分测试会改全局时间或 Autoload 状态。

```powershell
godot --headless --path . --script tools/godot/animated_actor_smoke.gd
godot --headless --path . --script tools/godot/sword_event_smoke.gd
godot --headless --path . --script tools/godot/player_state_smoke.gd
godot --headless --path . --script tools/godot/enemy_ai_smoke.gd
godot --headless --path . --script tools/godot/enemy_attack_smoke.gd
godot --headless --path . --script tools/godot/unfold_mapping_smoke.gd
godot --headless --path . --script tools/godot/lane_mapping_smoke.gd
godot --headless --path . --script tools/godot/hud_unfold_smoke.gd
godot --headless --path . --script tools/godot/unfold_transition_smoke.gd
```

如果你的 Godot 命令名是 `godot4`，把上面的 `godot` 替换成 `godot4`。

## 8. 常见问题

### 找不到 godot 命令

说明 Godot 没有加入 `PATH`。可以使用：

```powershell
$env:GODOT_EXE = "D:\Tools\Godot\Godot.exe"
powershell -ExecutionPolicy Bypass -File .\tools\windows\run_demo.ps1
```

### 分支不存在

说明 Linux 开发机还没有把 `feat/demo-v0-integration` 推到 GitHub。回到 Linux 执行：

```bash
cd /home/coder/workspace/Work/CBZ
git switch feat/demo-v0-integration
git push -u origin feat/demo-v0-integration
```

### Godot 打开后报脚本或场景错误

先记录第一条红色错误和对应文件路径，然后回到开发机修复。当前环境没有 Godot CLI，因此真正的引擎级错误需要在装有 Godot 的电脑上做第一次验证。

### Windows 换行或导入缓存变化

不要提交 `.godot/`、`.import/`、临时构建产物或本机配置。这些已经由 `.gitignore` 过滤。
