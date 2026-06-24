# Resources/Shortcuts/

此目录存放「一键创建 Shortcut」功能所需的预制 `.shortcut` 文件。

## 固定资源

| 文件 | 导入后的 Shortcut 名称 | 动作 |
|---|---|---|
| `开始专注.shortcut` | `开始专注` | Set Focus / Turn Do Not Disturb On |
| `关闭专注.shortcut` | `关闭专注` | Set Focus / Turn Do Not Disturb Off |

2026-06-13 实测:macOS 26 的 Shortcuts App 导入签名 `.shortcut` 时使用**文件名**作为 Shortcut 名称。因此文件名、App 默认名称、安装状态检测名称必须完全一致。

相关代码常量:

- `ShortcutRole.bundledResourceName`
- `LiveShortcutInstaller.defaultEnableName`
- `LiveShortcutInstaller.defaultDisableName`
- `FocusTimerModel.defaultEnableShortcut`
- `FocusTimerModel.defaultDisableShortcut`

## 更新流程

1. 在 Shortcuts App 中创建或编辑 `开始专注` / `关闭专注`
2. 双击进入编辑器 → File → Export...
3. 导出后重命名为 `开始专注.shortcut` / `关闭专注.shortcut`
4. 覆盖本目录文件
5. 运行 `xcodegen generate`
6. Release 构建后确认 Bundle 中包含两个资源:

```bash
ls -la /Applications/FocusTimer.app/Contents/Resources/开始专注.shortcut
ls -la /Applications/FocusTimer.app/Contents/Resources/关闭专注.shortcut
```

如果资源缺失,`LiveShortcutInstaller.importBoth()` 会抛出「Bundle 缺少 开始专注.shortcut」或「Bundle 缺少 关闭专注.shortcut」,并通过系统通知告知用户。
