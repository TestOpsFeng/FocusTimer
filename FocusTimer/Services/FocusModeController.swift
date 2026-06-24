//
//  FocusModeController.swift
//  FocusTimer
//
//  macOS 没有公开的 setFocus 编程 API。INFocusStatusCenter 仅提供只读访问。
//  本实现采用以下方案:
//  - 读: 通过 INFocusStatusCenter 读取当前 Focus 状态(保留给未来状态探针)
//  - 写: 通过 /usr/bin/shortcuts CLI (Process) 调用用户在 Shortcuts App 中
//        预配置的"开始专注"和"关闭专注"快捷指令。该 CLI 直接与
//        com.apple.shortcuts 后台服务通信,无需 Shortcuts GUI 应用先运行。
//
//  用户需提前在 Shortcuts App 中创建两个 Shortcut:
//  - "开始专注" : 包含 "Set Focus" 动作,启用其默认专注模式
//  - "关闭专注" : 包含 "Set Focus" 动作,关闭当前专注
//
//  Shortcut 名称固定,由一键导入流程和 bundled .shortcut 文件名共同约束。
//

import Foundation
import Intents
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
    ///   - enabled: true=开始专注, false=关闭专注
    ///   - enableShortcut: 开启时触发的 Shortcut 名称
    ///   - disableShortcut: 关闭时触发的 Shortcut 名称
    func setEnabled(
        _ enabled: Bool,
        enableShortcut: String,
        disableShortcut: String
    ) async throws
}

enum FocusModeController {

    static func live(
        processRunner: ProcessRunning = LiveProcessRunner()
    ) -> FocusModeControlling {
        LiveFocusController(processRunner: processRunner)
    }

    private final class LiveFocusController: FocusModeControlling {

        private let processRunner: ProcessRunning
        private var center: INFocusStatusCenter { .default }

        init(processRunner: ProcessRunning) {
            self.processRunner = processRunner
        }

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

            log.info("通过 CLI 触发 Shortcut: \(trimmed, privacy: .public)")
            let result = try await processRunner.run(
                executable: "/usr/bin/shortcuts",
                arguments: ["run", trimmed]
            )
            if !result.success {
                log.error("CLI 触发失败 (exit=\(result.exitCode)): \(result.stderr, privacy: .public)")
                let body = """
                无法触发 Shortcut '\(trimmed)'。
                请确认 Shortcuts App 中存在名为 '\(trimmed)' 的快捷指令,\
                且包含"设置专注模式"动作(\(enabled ? "启用" : "关闭")默认专注模式)。\
                原始错误:\(result.stderr.isEmpty ? "无 stderr 输出" : result.stderr)
                """
                throw NSError(
                    domain: "FocusModeController",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: body]
                )
            }
        }
    }
}
