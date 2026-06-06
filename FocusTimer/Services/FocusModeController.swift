//
//  FocusModeController.swift
//  FocusTimer
//
//  macOS 没有公开的 setFocus 编程 API。INFocusStatusCenter 仅提供只读访问。
//  本实现采用以下方案:
//  - 读: 通过 INFocusStatusCenter 读取当前 Focus 状态(用于 UI 展示)
//  - 写: 通过 Shortcuts URL scheme (shortcuts://run-shortcut?name=...) 触发用户
//        在 Shortcuts App 中预配置的"开启专注"和"关闭专注"快捷指令
//
//  用户需提前在 Shortcuts App 中创建两个 Shortcut:
//  - "开启专注" : 包含 "Set Focus" 动作,启用其默认专注模式
//  - "关闭专注" : 包含 "Set Focus" 动作,关闭当前专注
//
//  Shortcut 名称可在弹窗的"设置"区域修改并保存到 UserDefaults。
//

import Foundation
import Intents
import AppKit
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "FocusModeController")

protocol FocusModeControlling {
    /// 当前是否已获得读取 Focus 状态的授权
    func authorizationStatus() async -> INFocusStatusAuthorizationStatus

    /// 请求读取 Focus 状态的授权(系统会弹窗)
    func requestAuthorization() async throws

    /// 读取当前是否处于专注模式(用户系统层面的)
    func isCurrentlyFocused() async -> Bool

    /// 触发 Shortcut 来切换专注模式
    /// - Parameters:
    ///   - enabled: true=开启专注, false=关闭专注
    ///   - enableShortcut: 开启时触发的 Shortcut 名称
    ///   - disableShortcut: 关闭时触发的 Shortcut 名称
    func setEnabled(
        _ enabled: Bool,
        enableShortcut: String,
        disableShortcut: String
    ) async throws
}

enum FocusModeController {

    static func live() -> FocusModeControlling { LiveFocusController() }

    private final class LiveFocusController: FocusModeControlling {

        private var center: INFocusStatusCenter { .default }

        func authorizationStatus() async -> INFocusStatusAuthorizationStatus {
            // authorizationStatus 是只读属性,同步返回
            return center.authorizationStatus
        }

        func requestAuthorization() async throws {
            log.info("请求 Focus 状态读取授权...")
            let status: INFocusStatusAuthorizationStatus = await withCheckedContinuation { cont in
                center.requestAuthorization { status in
                    cont.resume(returning: status)
                }
            }
            log.info("Focus 授权结果: \(status.rawValue)")
            if status == .denied || status == .restricted {
                throw NSError(
                    domain: "FocusModeController",
                    code: Int(status.rawValue),
                    userInfo: [NSLocalizedDescriptionKey: "Focus 状态读取被拒绝"]
                )
            }
        }

        func isCurrentlyFocused() async -> Bool {
            // focusStatus 在 Swift 导入后为 INFocusStatus(非可选),
            // isFocused 为 Bool? —— 为 nil 时表示未配置任何 Focus,返回 false
            return center.focusStatus.isFocused ?? false
        }

        func setEnabled(
            _ enabled: Bool,
            enableShortcut: String,
            disableShortcut: String
        ) async throws {
            let name = enabled ? enableShortcut : disableShortcut
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                log.error("Shortcut 名称为空,无法触发")
                throw NSError(
                    domain: "FocusModeController",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "请先在弹窗中配置 Shortcut 名称"]
                )
            }

            // 构造 shortcuts://run-shortcut?name=<encoded>
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            let urlString = "shortcuts://run-shortcut?name=\(encoded)"
            guard let url = URL(string: urlString) else {
                log.error("无效的 URL: \(urlString, privacy: .public)")
                throw NSError(
                    domain: "FocusModeController",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "无效的 Shortcut URL"]
                )
            }

            log.info("触发 Shortcut: \(trimmed, privacy: .public) -> \(urlString, privacy: .public)")

            // NSWorkspace.open 必须在主线程调用
            let success: Bool = await MainActor.run {
                NSWorkspace.shared.open(url)
            }

            if !success {
                log.warning("Shortcut 触发失败,可能未配置或未安装 Shortcuts App: \(trimmed, privacy: .public)")
                throw NSError(
                    domain: "FocusModeController",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: """
                        无法触发 Shortcut '\(trimmed)'。
                        请打开 Shortcuts App 创建名为 '\(trimmed)' 的快捷指令,\
                        包含"设置专注模式"动作(\(enabled ? "启用" : "关闭")默认专注模式)。
                        """
                    ]
                )
            }
        }
    }
}
