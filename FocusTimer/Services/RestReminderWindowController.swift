//
//  RestReminderWindowController.swift
//  FocusTimer
//
//  休息提醒窗口的底层 NSWindow 控制器。
//
//  设计目标:
//  - 覆盖每个 NSScreen 一块 borderless NSWindow(多显示器全覆盖)
//  - level = .screenSaver,出现在其他全屏 App 之上
//  - collectionBehavior 包含 .fullScreenAuxiliary,允许跨 Spaces
//  - hidesOnDeactivate = false,⌘-Tab 切走时不消失
//  - Esc 键可靠关闭(NSWindow.cancelOperation 覆写)
//  - SwiftUI 视图通过 NSHostingView 嵌入
//
//  协议抽象见 RestReminderPresenting.swift。
//

import AppKit
import SwiftUI
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "RestReminderWindowController")

/// 自定义 NSWindow,override cancelOperation(_:) 以确保不论焦点在哪 Escape 都能关闭。
/// 使用 [.borderless, .nonactivatingPanel] 避免影响 NSApp.isActive。
final class RestReminderNSWindow: NSWindow {
    let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false   // ⌘-Tab 切走时不消失
        self.canHide = false
        self.level = .screenSaver         // 覆盖其他全屏 App
        self.collectionBehavior = [
            .fullScreenAuxiliary,         // 可出现在其他全屏 App 之上
            .moveToActiveSpace,
            .stationary,                  // 不在 Mission Control 里 tile
            .ignoresCycle                 // 不参与 ⌘` 窗口循环
        ]
        self.backgroundColor = .black
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}

@MainActor
final class RestReminderWindowController {

    private var windows: [RestReminderNSWindow] = []

    func show() {
        // 重复调用时先清理旧的(防御性)
        dismiss()

        let screens = NSScreen.screens
        log.info("展示休息提醒窗口,screens=\(screens.count, privacy: .public)")

        for screen in screens {
            let win = RestReminderNSWindow { [weak self] in
                self?.dismiss()
            }
            let host = NSHostingView(rootView: RestReminderView(onDismiss: { [weak self] in
                self?.dismiss()
            }))
            host.frame = screen.frame
            host.autoresizingMask = [.width, .height]
            win.contentView = host
            win.setFrame(screen.frame, display: true)
            win.orderFrontRegardless()

            windows.append(win)
        }

        // 提升 App 到前台(因为是 .accessory,默认不会主动激活)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        guard !windows.isEmpty else { return }
        log.info("关闭休息提醒窗口")
        for w in windows {
            w.orderOut(nil)
            w.contentView = nil
        }
        windows.removeAll()
    }
}
