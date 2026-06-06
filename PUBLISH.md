# FocusTimer 发布与更新指南

本文档记录 FocusTimer 的发布、安装、后续更新流程,以及已知限制和故障排查。

---

## 快速参考(最常用)

### 一键重新发布到 /Applications

修改 Swift 代码后,执行下面整段命令即可覆盖安装到 `/Applications`:

```bash
cd /Users/ling/Desktop/Claude_Workspace/FocusTimer && \
xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build && \
pkill -f /Applications/FocusTimer.app 2>/dev/null; \
rm -rf /Applications/FocusTimer.app && \
cp -R ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app /Applications/ && \
codesign --force --deep --sign - /Applications/FocusTimer.app && \
open /Applications/FocusTimer.app && \
echo ">>> 发布完成 ✓"
```

> 何时需要额外执行 `xcodegen generate`:**只改了 `project.yml` / `Assets.xcassets` 目录结构 / `Info.plist` / `entitlements` 等非代码文件时**。纯 Swift 代码改动无需 `xcodegen`。

### 实时日志(发布后验证用)

```bash
/usr/bin/log stream --predicate 'subsystem == "com.example.FocusTimer"' --info
```

---

## 详细流程

### 1. 首次发布(参考,已完成的初始安装)

> 一次性操作,已完成。后续重复"一键重新发布"即可。

```bash
cd /Users/ling/Desktop/Claude_Workspace/FocusTimer

# 生成 Xcode 项目(由 project.yml 派生)
xcodegen generate

# Release 构建(产物:DerivedData/.../Release/FocusTimer.app)
xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build

# 安装到 /Applications
cp -R ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app /Applications/

# Ad-hoc 签名(本地启动必须)
codesign --force --deep --sign - /Applications/FocusTimer.app

# 启动
open /Applications/FocusTimer.app
```

### 2. 后续更新(主要场景)

代码改动后,推荐使用顶部的「一键重新发布」。**注意三件事:**

1. **退出旧版再覆盖** — `pkill` 防止运行中替换
2. **重新签名** — 路径变化后必须 `--force` 重新签
3. **首次启动若拦截** — 参见下方 Gatekeeper 部分

### 3. 可选:封装为 `publish.sh` 脚本

将以下内容保存为 `/Users/ling/Desktop/Claude_Workspace/FocusTimer/publish.sh`,`chmod +x publish.sh` 后,以后只需 `./publish.sh`:

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"

echo ">>> 1. xcodegen generate"
xcodegen generate

echo ">>> 2. Release 构建"
xcodebuild -project FocusTimer.xcodeproj -scheme FocusTimer -configuration Release build

echo ">>> 3. 退出旧版"
pkill -f /Applications/FocusTimer.app 2>/dev/null || true

echo ">>> 4. 覆盖安装到 /Applications"
rm -rf /Applications/FocusTimer.app
cp -R ~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app /Applications/

echo ">>> 5. Ad-hoc 签名"
codesign --force --deep --sign - /Applications/FocusTimer.app

echo ">>> 6. 启动"
open /Applications/FocusTimer.app

echo ">>> 完成 ✓"
```

---

## 启动方式

| 方式 | 操作 |
|---|---|
| **Finder** | 应用程序 → 双击 FocusTimer |
| **Spotlight** | `Cmd+空格` → 输入 "FocusTimer" → 回车 |
| **命令行** | `open -a FocusTimer` 或 `open /Applications/FocusTimer.app` |
| **Launchpad** | 在启动台中查找 |

### Gatekeeper 首次启动拦截

Ad-hoc 签名(无 Developer ID)在首次启动会被 Gatekeeper 拦截。**处理方法(只需做一次):**

1. 在 Finder 中找到 `/Applications/FocusTimer.app`
2. **右键 → 打开** → 弹窗中再点"打开"
3. 之后即可正常双击

如果以后又被拦截(常见于 macOS 升级后),清除隔离属性:

```bash
xattr -cr /Applications/FocusTimer.app
codesign --force --deep --sign - /Applications/FocusTimer.app
```

---

## 故障排查

### Spotlight 搜不到 FocusTimer

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/FocusTimer.app
```

### 提示"应用已损坏,无法打开"

Xcode 自带的对象生命周期偶尔会留下 `quarantine` 属性。清除即可:

```bash
xattr -cr /Applications/FocusTimer.app
codesign --force --deep --sign - /Applications/FocusTimer.app
```

### 改了 `project.yml` 但没生效

`project.yml` 是 xcodegen 的输入,`.xcodeproj` 是输出。修改 `project.yml` 后必须:

```bash
xcodegen generate
```

### 改了 Info.plist / entitlements / Assets.xcassets 目录结构

同上,需要 `xcodegen generate` + 重新 `xcodebuild`。

### 菜单栏不显示文字 / 点击无反应

- 确认进程已起:`pgrep -lf FocusTimer`
- 实时日志:`/usr/bin/log show --predicate 'subsystem == "com.example.FocusTimer"' --info --debug --last 5m`
- Force Quit 后重新启动

### 持久化的总时长 / Shortcut 名称丢失

- 配置文件:`~/Library/Preferences/com.example.FocusTimer.plist`
- 跟随 Bundle ID `com.example.FocusTimer`。**如果改了 `PRODUCT_BUNDLE_IDENTIFIER`,旧数据不会被新版本读到**
- 查看内容:`defaults read com.example.FocusTimer`

### 启动崩溃

崩溃报告路径:`~/Library/Logs/DiagnosticReports/`,文件名含 "FocusTimer"。

### 重新打开后 Shortcut 失败 / Focus 没切换

App 依赖 Shortcuts App 里的"开启专注"和"关闭专注"两个 Shortcut。如果 Shortcut 被改名或删除,功能失效。打开弹窗的"Focus 快捷指令设置"区域修改名称。

---

## 已知限制

1. **Ad-hoc 签名,不能分发给他人**
   - 只能在当前 Mac 上运行
   - 需给其他 Mac 安装:在每台机器上各自执行发布流程,或购买 Apple Developer 账号做 Developer ID 签名

2. **手动更新,无自动升级**
   - 没有 Sparkle / Squirrel 等自动更新
   - 代码改动需手动跑发布命令

3. **App Sandbox 关闭**
   - `Resources/FocusTimer.entitlements` 中 `com.apple.security.app-sandbox: false`
   - 本地使用无问题。**如要上架 Mac App Store,需重新开启沙箱并调整 API 行为**(`INFocusStatusCenter` 在沙箱下表现可能不同;`shortcuts://` URL scheme 行为可能受限)

4. **未做 Apple 公证(notarization)**
   - 较新 macOS 上 Gatekeeper 可能持续拦截(右键放行可解)
   - 完整分发体验需要 Developer ID + 公证

5. **无代码混淆**
   - 二进制可被反编译,适合个人/学习项目

---

## 关键路径速查

| 路径 | 用途 |
|---|---|
| `/Applications/FocusTimer.app` | **最终安装位置** |
| `~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Release/FocusTimer.app` | Release 构建产物 |
| `~/Library/Developer/Xcode/DerivedData/FocusTimer-*/Build/Products/Debug/FocusTimer.app` | Debug 构建产物(开发用) |
| `~/Library/Preferences/com.example.FocusTimer.plist` | UserDefaults 持久化(总时长、Shortcut 名) |
| `~/Library/Logs/DiagnosticReports/` | 崩溃日志 |
| `FocusTimer/Resources/Assets.xcassets/AppIcon.appiconset/` | 应用图标源 |
| `project.yml` | XcodeGen 项目定义(改完需 `xcodegen generate`) |

---

## 卸载

```bash
# 退出 + 删除应用
pkill -f /Applications/FocusTimer.app
rm -rf /Applications/FocusTimer.app

# 可选:删除用户配置(下次安装会回到默认 60 分钟、默认 Shortcut 名)
rm -f ~/Library/Preferences/com.example.FocusTimer.plist
```

---

## 日志类别参考

各子系统的日志均带 `subsystem: com.example.FocusTimer`,通过 `category` 区分:

| Category | 内容 |
|---|---|
| `App` | 启动/退出 |
| `FocusTimerModel` | 状态机转换(start/pause/resume/reset/complete) + appFocusOn 变化 |
| `TimerEngine` | 滴答启动/停止 |
| `FocusModeController` | Focus 授权 + Shortcut 触发 |
| `NotificationManager` | 通知权限 + 调度/取消 |

按类别过滤:
```bash
/usr/bin/log show --predicate 'subsystem == "com.example.FocusTimer" AND category == "FocusTimerModel"' --info --debug --last 5m
```
