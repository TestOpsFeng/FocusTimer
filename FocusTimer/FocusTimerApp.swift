//
//  FocusTimerApp.swift
//  FocusTimer
//
//  App 入口:MenuBarExtra 场景,无主窗口(LSUIElement 由 MenuBarExtra 自动处理)。
//  启动时静默检查通知权限(不阻塞 UI,若未授权则在首次 start() 时由系统弹窗)。
//

import SwiftUI
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "App")

@main
struct FocusTimerApp: App {

    @State private var model = FocusTimerModel()

    init() {
        log.info("FocusTimer 启动")
        // 静默预热通知权限,避免首次倒计时完成时突兀弹窗
        Task.detached(priority: .background) {
            _ = await NotificationManager.live().requestAuthorization()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            MenuBarLabel(model: model)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}
