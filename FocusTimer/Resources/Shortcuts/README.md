# Resources/Shortcuts/

此目录用于存放一键创建功能所需的预制 `.shortcut` 文件。

## 开发者一次性准备

1. 打开 macOS **Shortcuts** App
2. 创建两个 Shortcut,各添加一个 "Set Focus" 动作:
   - 名为 **"开启专注"** 的 Shortcut → "Turn [Do Not Disturb] On" 或 "Set Focus → On"
   - 名为 **"关闭专注"** 的 Shortcut → "Turn [Do Not Disturb] Off" 或 "Set Focus → Off"
3. 在 Shortcuts App 中,**右键 → Export** 这两个 Shortcut,保存为 `.shortcut` 文件
4. 把这两个文件重命名后放入本目录:
   - `EnableFocus.shortcut` — 内部 Shortcut 名为 "开启专注"
   - `DisableFocus.shortcut` — 内部 Shortcut 名为 "关闭专注"

## 关键约束

- 文件名(`EnableFocus.shortcut` / `DisableFocus.shortcut`)是**固定的** — 应用通过它查找资源
- 文件**内部**的 Shortcut 名称(用户看到的)可以自定义,但**必须**与 App 默认配置
  `LiveShortcutInstaller.defaultEnableName` / `defaultDisableName` 一致(目前是
  "开启专注" / "关闭专注")
- 如需在 App 中改用其他名称,同步修改 `ShortcutInstaller.swift` 中的 `defaultEnableName`
  / `defaultDisableName` 和 `FocusTimerModel.swift` 中的 `defaultEnableShortcut` /
  `defaultDisableShortcut`

## 验证

```bash
# 编译后查看 Bundle 中是否包含:
ls -la /Applications/FocusTimer.app/Contents/Resources/EnableFocus.shortcut
ls -la /Applications/FocusTimer.app/Contents/Resources/DisableFocus.shortcut
```

如果文件不存在,App 启动时 `bundledShortcutURL(for:)` 会返回 `nil`,`importBoth()` 会
抛 `Bundle 缺少 EnableFocus.shortcut` 错误,并通过系统通知告知用户。
