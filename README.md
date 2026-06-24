# FocusTimer

macOS 14+ 菜单栏倒计时应用,倒计时期间自动启用系统「专注模式」,结束或重置时自动关闭。

## 功能

- **菜单栏倒计时**:数字直接显示在 macOS 菜单栏,空闲时显示 `Focus 60:00`,运行中显示 `00:42:13`。
- **可配置时长**:默认 1 小时,提供 15 / 30 / 45 / 60 / 90 分钟快捷按钮,以及 1-1440 分钟的自定义输入。
- **Focus 自动切换**:开始 → 启用专注;暂停 → 专注保持;重置 / 完成 → 关闭专注。
- **暂停 / 继续 / 重置**:倒计时可中断,恢复后从冻结的剩余时间继续,专注状态保持。
- **系统通知**:倒计时完成时弹出系统通知。
- **全屏休息提醒**:倒计时自然完成后默认打开全屏「该休息了」提醒,可选择 5 / 15 / 30 分钟休息倒计时,结束后响铃。
- **Focus 意图徽章**:弹窗中显示本 App 上一轮请求的 Focus ON/OFF 状态。

## 关键技术决策:为什么用 Shortcuts

**macOS 没有任何公开的 API 允许第三方应用编程启用/关闭 Focus 模式。** `Intents` 框架中的 `INFocusStatusCenter` 是**只读**的(用于读取用户是否专注,如 Messages 的"对方正在专注中"提示),没有 setter。

本应用通过 macOS 自带的 `/usr/bin/shortcuts` CLI(`Process` 调用)触发用户在 **Shortcuts App** 中预配置的快捷指令来切换 Focus。**这要求用户先在 Shortcuts App 中创建两个简单的 Shortcut**,但比使用私有 API(不稳定 + App Store 拒绝)要可靠得多。

> 旧版本使用 `shortcuts://` URL scheme 触发,首次启动后需要先手动打开 Shortcuts App 才能让系统专注模式生效。改用 CLI 后,该问题已修复:`shortcuts` CLI 直接与 `com.apple.shortcuts` 后台服务通信,**不依赖 Shortcuts GUI 应用是否运行**。

## 前置设置(只需一次)

### 方案 A(推荐,一键)

无需手动操作。第一次运行 FocusTimer 后:

1. 点击菜单栏图标,展开「Focus 快捷指令设置」折叠区
2. 点击「一键创建 Shortcut」按钮
3. Shortcuts App 会依次弹出两个「Add '开始专注'?」「Add '关闭专注'?」导入对话框
4. 在每个对话框中点 **"Add Shortcut"**(每个 ~1 秒)
5. 弹窗底部状态点变绿,显示「Shortcut 已就位 ✓」
6. 之后任何时候删除了 Shortcut,重复上述流程即可恢复

> App 内部已携带两个预制的 `.shortcut` 文件,终身跟随 Bundle。导入后的 Shortcut 名称是 **「开始专注」/「关闭专注」**,与 App 内置配置一致,UI **不可编辑**(采用固定名称以保证一键创建流程始终可用)。

### 方案 B(手动,可选,适合高级用户)

在 **Shortcuts** App 中创建两个 Shortcut,必须分别命名为 **"开始专注"** 和 **"关闭专注"**(与 App 内置配置严格一致,不可自定义):

#### 开始专注
1. 打开 Shortcuts App → 顶部 **+** 新建
2. 添加动作 **"设置专注模式"** → 选择「启用」,选择你希望使用的专注模式(如「勿扰模式」或自定义的工作模式)
3. 保存为 **"开始专注"**(必须用此名,App 不可编辑配置)

#### 关闭专注
1. 同样新建,添加 **"设置专注模式"** → 选择「关闭」
2. 保存为 **"关闭专注"**(必须用此名,App 不可编辑配置)

## 构建

需要 macOS、Xcode 15+ 和 `xcodegen`(`brew install xcodegen`)。

```bash
# 在项目根目录
xcodegen generate
open FocusTimer.xcodeproj
# Xcode 中按 Cmd-R 运行
```

或者纯命令行:
```bash
xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Debug/FocusTimer.app
```

## 使用

1. 启动 App,菜单栏出现 `Focus 60:00`。
2. 点击菜单栏图标 → 弹窗中调整时长 → 点击 **开始**。
3. 系统会弹出权限请求:
   - **Shortcuts 自动化权限**:首次运行 "开始专注" 时会请求(只弹一次)。**无需先手动打开 Shortcuts App。**
   - **通知权限**:允许接收完成通知。
4. 倒计时开始,菜单栏显示剩余时间,系统专注模式被启用。
5. 暂停 → 倒计时冻结但 Focus 保持;继续 → 从冻结值继续。
6. 重置 → 倒计时清零,Focus 关闭。
7. 自然完成 → 通知弹出,Focus 关闭,默认显示全屏休息提醒。
8. 在休息界面点击 `5:00` / `15:00` / `30:00` 开始休息倒计时;倒计时结束后系统铃声响一次,界面停留到手动关闭。

## 项目结构

```
FocusTimer/
├── project.yml                 # XcodeGen 项目定义
├── FocusTimer.xcodeproj/       # 由 xcodegen 生成
├── FocusTimer/
│   ├── FocusTimerApp.swift     # @main + MenuBarExtra 场景
│   ├── Model/
│   │   ├── FocusPhase.swift    # 状态机:idle / running(endDate) / paused(remaining)
│   │   ├── TimerState.swift    # 状态结构体
│   │   └── FocusTimerModel.swift  # @Observable @MainActor 视图模型
│   ├── Services/
│   │   ├── TimerEngine.swift          # Task.sleep 驱动的 1Hz 滴答
│   │   ├── FocusModeController.swift  # INFocusStatusCenter 读 + /usr/bin/shortcuts CLI 写
│   │   ├── ShortcutInstaller.swift    # 检测/触发 Shortcuts App 导入(配合 .shortcut 资源)
│   │   ├── ProcessRunner.swift        # 子进程调用抽象(可注入测试桩)
│   │   ├── NotificationManager.swift  # UNUserNotificationCenter 封装(含失败通知)
│   │   ├── RestBreakTimerModel.swift  # 休息提醒内的 5/15/30 分钟倒计时 + 铃声
│   │   ├── RestReminderPresenting.swift
│   │   └── RestReminderWindowController.swift  # 全屏休息提醒窗口
│   ├── Views/
│   │   ├── MenuBarLabel.swift   # 菜单栏文字
│   │   ├── MenuContent.swift    # 弹窗主体
│   │   ├── DurationPicker.swift # 时长选择 UI
│   │   └── RestReminderView.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Shortcuts/           # 开始专注.shortcut / 关闭专注.shortcut
│       ├── Info.plist           # NSFocusStatusUsageDescription
│       └── FocusTimer.entitlements
├── docs/ARCHITECTURE.md
├── PUBLISH.md
├── SHORTCUTS_MEMO.md
└── README.md
```

## 调试日志

所有关键节点都通过 `os.Logger` 输出(subsystem `com.example.FocusTimer`),用 Console.app 过滤:

```
log show --predicate 'subsystem == "com.example.FocusTimer"' --info --debug --last 5m
```

或在 Console.app 中搜索 `subsystem:com.example.FocusTimer`。

主要日志类别:
- `FocusTimerModel`:状态转换(start/pause/resume/reset/complete)
- `TimerEngine`:滴答启动/停止
- `FocusModeController`:Focus 授权 + Shortcut 触发
- `ShortcutInstaller`:Shortcut 安装状态查询 + 导入对话框触发
- `ProcessRunner`:子进程启动/退出/stdout/stderr 摘要
- `NotificationManager`:通知权限 + 调度
- `RestBreakTimerModel`:休息倒计时启动/完成
- `RestReminderWindowController`:全屏休息提醒窗口展示/关闭
- `App`:启动

## 已知限制

1. **一键创建依赖 Bundle 内的 `.shortcut` 资源**:App 携带两个预制的 `.shortcut` 文件(`Resources/Shortcuts/开始专注.shortcut` + `关闭专注.shortcut`)。如果文件丢失或损坏,「一键创建」按钮会弹「Bundle 缺少 开始专注.shortcut」或「Bundle 缺少 关闭专注.shortcut」错误。开发者(本仓库维护者)需手动从 Shortcuts App 重新导出并放回该目录。
2. **Shortcut 触发失败时通过系统通知提示**:本应用通过 `/usr/bin/shortcuts` CLI 调用用户在 Shortcuts App 中预配置的「开始专注」/「关闭专注」。若 Shortcut 不存在、改名或未含「设置专注模式」动作,CLI 退出非 0,本应用会**通过系统通知弹窗**告知用户,并把 stderr 详情记录到 `os.Logger`(category=`FocusModeController`)。查看方式:`log show --predicate 'subsystem == "com.example.FocusTimer" AND category == "FocusModeController"' --info --debug --last 5m`。
3. **强制退出 App 时 Focus 不会自动恢复**:v1 范围不处理 `NSApplicationWillTerminate` 钩子,异常退出后 Focus 可能保持开启。
4. **未配置任何 Focus 模式时 Shortcut 内的"设置专注模式"动作会失败** — 在 Shortcuts App 的运行日志里可以看到。
5. **`@Observable` + 每秒 tick**:`MenuBarLabel` 每秒重绘,但 `DateComponentsFormatter` 复用,无性能问题。
6. **Focus 徽章是 App 意图状态**:徽章显示本 App 上一轮 start/reset/complete 的请求结果,不是系统真实 Focus 状态探针。Shortcut 被用户取消或失败时,以通知和日志为准。
7. **App Sandbox 默认关闭**:本地 dev 阶段不开启。分发时需要重新评估 `/usr/bin/shortcuts`、通知和 Focus 状态读取在沙箱下的行为。

## 状态机

```
       start()              pause()            resume()         (自然完成 / reset())
idle ────────▶ running ──────────▶ paused ──────────▶ running ──────────────────┐
  ▲                │                                                       │
  │                │ reset()                                              │
  │                ▼                                                       │
  │              idle ◀──────────────────────────────────────────────────── reset()
  │                                                                        │
  │                                                                        ▼
  └────────────────────────────────────────────────── idle ◀── (handleCompletion)
```

- **idle → running**:`start()`,endDate = now + totalDuration,通知已调度
- **running → paused**:`pause()`,remaining = endDate - now,通知取消,Focus 保持
- **paused → running**:`resume()`,endDate = now + remaining,通知重调度
- **任意 → idle (reset)**:`reset()`,通知取消,Focus 关闭
- **running → idle (完成)**:剩余时间到 0,通知由系统触发,Focus 关闭
