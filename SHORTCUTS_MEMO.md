# 创建与导出 Shortcut 的备忘

> 适用于 FocusTimer 的「一键创建 Shortcut」功能。
> 涉及对 `FocusTimer/Resources/Shortcuts/EnableFocus.shortcut` 与 `DisableFocus.shortcut` 的更新。
>
> 最后更新:2026-06-13(对应 macOS 26 / Shortcuts App 当前版本)

---

## TL;DR(快速操作)

1. 打开 **Shortcuts** App
2. 创建(或编辑)Shortcut:
   - **开启专注** — 包含 "Set Focus" / "Turn Do Not Disturb On" 动作
   - **关闭专注** — 包含 "Set Focus" / "Turn Do Not Disturb Off" 动作
3. **双击进入编辑器** → 顶部菜单栏 → **File** → **Export...** → 保存为 `.shortcut` 文件
4. 把文件改名为 `EnableFocus.shortcut` / `DisableFocus.shortcut`
5. 放到 `FocusTimer/Resources/Shortcuts/` 目录下,覆盖旧文件
6. `xcodegen generate && xcodebuild ...`

---

## 详细步骤(带截图位)

### 1. 创建 Shortcut(首次)

打开 **Shortcuts** App,点击右上 **+** 新建:

- 命名:**开启专注**
- 添加动作:搜索 "Set Focus" 或 "Do Not Disturb"
  - 中文系统:动作名是 **「设置专注模式」** 或 **「开启勿扰模式」**
  - 英文系统:动作名是 **"Set Focus"** / **"Turn Do Not Disturb On"**
- 配置动作为「启用 / On」
- 保存(系统会自动加入 Shortcuts 库)

对「关闭专注」重复上述步骤,动作为「关闭 / Off」。

### 2. 编辑现有 Shortcut(如已存在)

打开 Shortcuts App,在库中找到目标 Shortcut → **双击**进入编辑器。

> **重要**:右键库中的 Shortcut **没有** 「Export as File」选项(只有 Share 子菜单,见下文「踩坑记录」)。必须**双击进入编辑器**才能在 File 菜单看到 Export。

### 3. 导出为 .shortcut 文件

在编辑器视图:

1. 顶部菜单栏 → **File**(文件)
2. 找到 **Export Shortcut...**(或类似名称,可能显示为 "导出快捷指令")
3. 保存对话框:选择存放位置,**保持默认的 `.shortcut` 扩展名**

> **注意**:macOS 26 的 Shortcuts App 导出的 `.shortcut` 文件实际上是**签名格式**(magic `AEA1`),内含 `SigningCertificateChain`。这种格式与旧版未签名的 ZIP 格式在功能上等价——Shortcuts App 的「Add Shortcut」对话框两种都接受。无需额外处理。

### 4. 重命名 + 放到项目

- 把导出的文件**重命名**为 `EnableFocus.shortcut` 或 `DisableFocus.shortcut`
- 文件名是项目约定,与 Shortcut 内部名称无关
- 放到 `FocusTimer/Resources/Shortcuts/` 下(覆盖旧文件)

### 5. 重新生成 Xcode 项目并构建

```bash
cd /Users/ling/Desktop/Claude_Workspace/FocusTimer
xcodegen generate
xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build
```

验证资源已打包进 app:

```bash
ls -la ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app/Contents/Resources/*.shortcut
```

应该看到两个文件,各 ~21KB。

---

## 踩坑记录

### ❌ 库中右键菜单的「分享」没有「Save as File」

macOS 26 的 Shortcuts App,在**库视图**中右键 Shortcut → **分享** → 子菜单里只有:
- 添加到阅读列表、隔空投送、邮件、信息、备忘录、无边记、Simulator、手记、提醒事项、快捷指令、暂存架、微信、拷贝 iCloud 链接、拷贝、更多……

**找不到「存储到文件」或「Save as .shortcut」**。这是当前 macOS 版本的实际行为,不是误操作。

✅ 正确入口:**双击进入编辑器** → 顶部菜单栏 File 菜单

### ❌ AirDrop / 共享给自己无法直接得到 .shortcut 文件

- AirDrop 收到的是「链接」,在 Shortcuts App 中"打开",不会得到磁盘上的 `.shortcut` 文件
- iCloud 链接是 URL,不是文件

✅ 正确方式:用 File → Export 得到真正的 `.shortcut` 文件

### ❌ `unzip` 无法打开导出的文件

导出文件的内部结构是 macOS 的**签名快捷指令格式**:

```
AEA1 0000 0000   ← magic (4 bytes "AEA1" + 4 bytes 0)
9b08 0000         ← 长度(4 bytes LE)
bplist00 ...      ← 二进制 plist(包含 SigningCertificateChain)
```

这不是标准 ZIP,所以 `unzip -l xxx.shortcut` 会失败。**但 Shortcuts App 本身能识别**——它的「Add Shortcut」对话框接受这种签名格式,导入时自动剥掉签名。

> 如果未来 Shortcuts App 改成只接受纯 ZIP 格式,可能需要先用 `shortcuts sign` 转换,或重新导出。当前 macOS 26 无此问题。

### ❌ Python `plistlib` 无法解析签名格式

`plistlib.loads(data[12:])` 在签名格式上会抛 `InvalidFileException`,因为 `bplist00` 头部有非标准的偏移量字段(8 字节头,而非标准的 0 字节)。**不需要在代码中解析 .shortcut 文件**——`NSWorkspace.open(url)` 直接交给 Shortcuts App 处理。

### ❌ Shortcut 内部名称与文件名不一致

- 文件名:`EnableFocus.shortcut` / `DisableFocus.shortcut`(项目约定)
- Shortcut **内部**名称(用户看到的):**开启专注** / **关闭专注**(与 App 中 `LiveShortcutInstaller.defaultEnableName` / `defaultDisableName` 一致)

如果改了内部名称,需要**同步**修改:
- `FocusTimer/Services/ShortcutInstaller.swift` 中的 `defaultEnableName` / `defaultDisableName`
- `FocusTimer/Model/FocusTimerModel.swift` 中的 `defaultEnableShortcut` / `defaultDisableShortcut`

否则「一键创建」后 `shortcuts list` 找不到新导入的 Shortcut,状态会一直显示「未就位」。

---

## 验证清单

更新 `.shortcut` 资源后,**必须**逐项确认:

- [ ] `Resources/Shortcuts/EnableFocus.shortcut` 存在,~21KB
- [ ] `Resources/Shortcuts/DisableFocus.shortcut` 存在,~21KB
- [ ] `xcodegen generate` 成功
- [ ] `xcodebuild ... build` 成功,无 Swift 错误
- [ ] 编译产物 `FocusTimer.app/Contents/Resources/*.shortcut` 存在
- [ ] 安装到 `/Applications/FocusTimer.app` 后:
  - [ ] 删除现有 Shortcut
  - [ ] 启动 App,弹窗「Focus 快捷指令设置」中状态点**变红**(未就位)
  - [ ] 点「一键创建 Shortcut」按钮
  - [ ] Shortcuts App 弹两个导入对话框,各点 Add Shortcut
  - [ ] 弹窗中状态点**变绿**,显示「Shortcut 已就位 ✓」
  - [ ] `shortcuts list | grep 开启` 出现新 Shortcut
- [ ] 单元测试通过:`xcodebuild test ...`,20 个用例全过
- [ ] 提交并推送到 GitHub

---

## 备选:不依赖 .shortcut 文件(Plan B)

如果将来 .shortcut 文件导出完全无法使用,可改用 AppleScript 直接命令 Shortcuts App 创建:

```bash
osascript -e 'tell application "Shortcuts"
    set newShortcut to make new shortcut with properties {name:"开启专注"}
    -- 添加 "Set Focus" 动作(API 受限,可能不直接支持)
end tell'
```

**优势**:不依赖 .shortcut 文件、Bundle 更小、跨 macOS 版本一致
**劣势**:
- Shortcuts App 的 AppleScript 字典**有限**,添加复杂动作需 workaround
- 首次需用户在「系统设置 → 隐私与安全性 → 自动化」中允许

当前 macOS 26 + 方案 2(File 菜单 Export)**完全可用**,无需启用 Plan B。

---

## 相关文件

| 文件 | 说明 |
|---|---|
| `FocusTimer/Resources/Shortcuts/EnableFocus.shortcut` | "开启" Shortcut(签名格式) |
| `FocusTimer/Resources/Shortcuts/DisableFocus.shortcut` | "关闭" Shortcut(签名格式) |
| `FocusTimer/Resources/Shortcuts/README.md` | 简版说明(在 Resources 目录内) |
| `FocusTimer/Services/ShortcutInstaller.swift` | 导入逻辑(`bundledShortcutURL` 读取 Bundle) |
| `FocusTimer/Model/FocusTimerModel.swift` | 默认名称(`defaultEnableShortcut` / `defaultDisableShortcut`) |
