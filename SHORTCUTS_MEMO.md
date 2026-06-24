# 创建与导出 Shortcut 的备忘

> 适用于 FocusTimer 的「一键创建 Shortcut」功能。
> 涉及 `FocusTimer/Resources/Shortcuts/开始专注.shortcut` 与 `FocusTimer/Resources/Shortcuts/关闭专注.shortcut`。
>
> 验证环境:2026-06-13,macOS 26 / Shortcuts App。

## TL;DR

1. 打开 **Shortcuts** App
2. 创建或编辑两个 Shortcut:
   - **开始专注** — 包含 "Set Focus" / "Turn Do Not Disturb On" 动作
   - **关闭专注** — 包含 "Set Focus" / "Turn Do Not Disturb Off" 动作
3. 双击 Shortcut 进入编辑器 → 顶部菜单栏 **File** → **Export...** → 保存为 `.shortcut`
4. 把文件重命名为 `开始专注.shortcut` / `关闭专注.shortcut`
5. 覆盖放入 `FocusTimer/Resources/Shortcuts/`
6. 执行 `xcodegen generate && xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build`

## 详细步骤

### 1. 创建 Shortcut

打开 **Shortcuts** App,点击右上 **+** 新建:

- 命名:**开始专注**
- 添加动作:搜索 "Set Focus" 或 "Do Not Disturb"
  - 中文系统:动作名是 **「设置专注模式」** 或 **「开启勿扰模式」**
  - 英文系统:动作名是 **"Set Focus"** / **"Turn Do Not Disturb On"**
- 配置动作为「启用 / On」
- 保存

对 **关闭专注** 重复上述步骤,动作为「关闭 / Off」。

### 2. 导出为 `.shortcut`

必须先双击 Shortcut 进入编辑器,再从顶部菜单栏使用 **File → Export...**。库视图右键的 Share 菜单不会给出稳定的 `.shortcut` 文件。

导出的 `.shortcut` 在 2026-06-13 验证环境中是签名格式(magic `AEA1`),内含 `SigningCertificateChain`。Shortcuts App 的 Add Shortcut 对话框可直接导入,本项目代码也不需要解析该文件。

### 3. 文件名是协议的一部分

2026-06-13 实测:删除原 Shortcut 后通过「一键创建 Shortcut」导入 `.shortcut` 文件时,Shortcuts App 使用**文件名**作为导入后的 Shortcut 名称,不是文件内部保存的名称。

所以资源文件名必须固定为:

- `FocusTimer/Resources/Shortcuts/开始专注.shortcut`
- `FocusTimer/Resources/Shortcuts/关闭专注.shortcut`

这些名称必须与代码常量保持一致:

- `FocusTimerModel.defaultEnableShortcut`
- `FocusTimerModel.defaultDisableShortcut`
- `LiveShortcutInstaller.defaultEnableName`
- `LiveShortcutInstaller.defaultDisableName`
- `ShortcutRole.bundledResourceName`

UI 不可编辑 Shortcut 名称。旧版 UserDefaults 中的可编辑名称 key 会在 `FocusTimerModel` 初始化时移除。

## 踩坑记录

### 库中右键 Share 不能稳定导出文件

库视图右键 Shortcut → Share 更偏向分享链接或发送到其他 App。维护 Bundle 资源时使用编辑器窗口的 File → Export。

### AirDrop / iCloud 链接不是项目需要的文件

AirDrop 或 iCloud 分享拿到的是 Shortcuts App 处理的链接,不是仓库里要提交的 `.shortcut` 文件。

### `unzip` 和 `plistlib` 不能解析签名格式

签名 `.shortcut` 不是标准 ZIP。不要在 FocusTimer 中解析它;`NSWorkspace.open(url)` 直接交给 Shortcuts App 处理即可。

## 验证清单

更新 `.shortcut` 资源后逐项确认:

- [ ] `FocusTimer/Resources/Shortcuts/开始专注.shortcut` 存在,约 21KB
- [ ] `FocusTimer/Resources/Shortcuts/关闭专注.shortcut` 存在,约 21KB
- [ ] `xcodegen generate` 成功
- [ ] `xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build` 成功
- [ ] 编译产物包含两个资源:

```bash
ls -la ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app/Contents/Resources/开始专注.shortcut
ls -la ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app/Contents/Resources/关闭专注.shortcut
```

- [ ] 安装到 `/Applications/FocusTimer.app` 后,删除现有 Shortcut 再点「一键创建 Shortcut」
- [ ] Shortcuts App 弹两个导入对话框,分别显示 `Add '开始专注'?` 与 `Add '关闭专注'?`
- [ ] App 弹窗状态点变绿,显示「Shortcut 已就位 ✓」
- [ ] `shortcuts list | grep -E '开始专注|关闭专注'` 能看到两个 Shortcut
- [ ] 单元测试通过:`xcodebuild test -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Debug -destination 'platform=macOS'`

## 备选方案

如果将来 `.shortcut` 文件导出格式不可用,可评估 AppleScript 直接命令 Shortcuts App 创建 Shortcut:

```bash
osascript -e 'tell application "Shortcuts"
    set newShortcut to make new shortcut with properties {name:"开始专注"}
end tell'
```

这个方案可能受 Shortcuts App AppleScript 字典限制,添加 "Set Focus" 动作不一定可直接表达。除非导出文件路径失效,不要优先改用它。

## 相关文件

| 文件 | 说明 |
|---|---|
| `FocusTimer/Resources/Shortcuts/开始专注.shortcut` | 启用 Focus 的签名 Shortcut 资源 |
| `FocusTimer/Resources/Shortcuts/关闭专注.shortcut` | 关闭 Focus 的签名 Shortcut 资源 |
| `FocusTimer/Resources/Shortcuts/README.md` | 资源目录内的简版维护说明 |
| `FocusTimer/Services/ShortcutInstaller.swift` | 导入逻辑(`bundledShortcutURL` 读取 Bundle) |
| `FocusTimer/Model/FocusTimerModel.swift` | 固定 Shortcut 名称和旧 key migration |
