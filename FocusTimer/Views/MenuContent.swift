//
//  MenuContent.swift
//  FocusTimer
//
//  点击菜单栏图标后的弹窗主体:
//  - 头部:大字显示当前状态/剩余时间 + Focus 系统状态
//  - 时长选择:15/30/45/60/90 + 自定义
//  - Shortcut 配置:开启/关闭 Focus 的 Shortcut 名称(持久化到 UserDefaults)
//  - 控制:Start / Pause / Resume / Reset
//  - 底部:退出按钮
//

import SwiftUI

struct MenuContent: View {
    @Bindable var model: FocusTimerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            DurationPicker(model: model)
            Divider()
            shortcutSettings
            Divider()
            controlButtons
            footer
        }
        .padding(16)
        .frame(width: 320)
        .task {
            // 弹窗首次出现时检查一次 Shortcut 安装状态
            await model.refreshInstallationStatus()
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(statusTitle)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                Spacer()
                focusStatusBadge
            }
            Text(statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        let _ = model.nowTick
        switch model.state.phase {
        case .idle:    return "就绪"
        case .running: return formatTime(model.state.remaining)
        case .paused:  return formatTime(model.state.remaining)
        }
    }

    private var statusSubtitle: String {
        switch model.state.phase {
        case .idle:
            let mins = Int(model.state.totalDuration / 60)
            return "将专注 \(mins) 分钟"
        case .running: return "专注中…"
        case .paused:  return "已暂停(系统 Focus 保持)"
        }
    }

    private var focusStatusBadge: some View {
        // 徽章读 model.appFocusOn —— 由 start/reset/complete 维护,反映 App 意图而非系统真实状态
        Group {
            if model.appFocusOn {
                Label("Focus ON", systemImage: "moon.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.purple.opacity(0.2)))
                    .foregroundStyle(.purple)
            } else {
                Label("Focus OFF", systemImage: "moon")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Shortcut 配置

    private var shortcutSettings: some View {
        DisclosureGroup("Focus 快捷指令设置", isExpanded: $showShortcutSettings) {
            VStack(alignment: .leading, spacing: 8) {
                Text("macOS 无公开 API 编程启用 Focus,需在 Shortcuts App 中创建两个快捷指令,然后在此填入名称。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("开启:")
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    TextField("Shortcut 名", text: $model.enableShortcut)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("关闭:")
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)
                    TextField("Shortcut 名", text: $model.disableShortcut)
                        .textFieldStyle(.roundedBorder)
                }

                Button("打开 Shortcuts App") {
                    NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                }
                .font(.caption)
                .buttonStyle(.borderless)

                Divider()
                    .padding(.vertical, 4)

                Button {
                    Task { await model.installShortcuts() }
                } label: {
                    Label("一键创建 Shortcut", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                installationStatusRow
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private var installationStatusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(installationStatusColor)
                .frame(width: 6, height: 6)
            Text(installationStatusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var installationStatusColor: Color {
        switch model.installationStatus {
        case .bothPresent:                       return .green
        case .enableMissing, .disableMissing:    return .orange
        case .bothMissing:                       return .red
        }
    }

    private var installationStatusText: String {
        switch model.installationStatus {
        case .bothPresent:
            return "Shortcut 已就位 ✓"
        case .enableMissing:
            return "未找到「开启」Shortcut,点上方按钮一键创建"
        case .disableMissing:
            return "未找到「关闭」Shortcut,点上方按钮一键创建"
        case .bothMissing:
            return "未找到任何 Shortcut,点上方按钮一键创建"
        }
    }

    @State private var showShortcutSettings = false

    // MARK: - 控制按钮

    private var controlButtons: some View {
        HStack(spacing: 8) {
            switch model.state.phase {
            case .idle:
                Button {
                    Task { await model.start() }
                } label: {
                    Label("开始", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)

                Button {} label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(true)

            case .running:
                Button {
                    Task { await model.pause() }
                } label: {
                    Label("暂停", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await model.reset() }
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

            case .paused:
                Button {
                    Task { await model.resume() }
                } label: {
                    Label("继续", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task { await model.reset() }
                } label: {
                    Label("重置", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - 底部

    private var footer: some View {
        HStack {
            Spacer()
            Button("退出 FocusTimer") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    // MARK: - 辅助

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}
