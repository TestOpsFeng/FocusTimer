//
//  FocusTimerModel.swift
//  FocusTimer
//
//  核心视图模型 (@Observable @MainActor),协调 TimerEngine、FocusModeController、NotificationManager。
//
//  状态机: idle <-> running <-> paused
//  - start  : 触发 Shortcut 启用 Focus -> 进入 running -> 调度通知
//  - pause  : 冻结 remaining(取消通知,Focus 保持开启)
//  - resume : 重新计算 endDate = now + remaining(重调度通知,Focus 保持开启)
//  - reset  : 触发 Shortcut 关闭 Focus,回到 idle(取消通知,保留 totalDuration)
//  - 完成  : 触发 Shortcut 关闭 Focus,通知由系统触发
//
//  Focus 控制策略:macOS 无公开 API 编程启用/禁用 Focus,故通过 /usr/bin/shortcuts
//  CLI(Process 调用)触发用户在 Shortcuts App 中预配置的快捷指令。该 CLI 直接与
//  com.apple.shortcuts 后台服务通信,不依赖 Shortcuts GUI 应用是否运行。名称在 UI 中可改。
//

import Foundation
import Observation
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "FocusTimerModel")

@Observable
@MainActor
final class FocusTimerModel {

    // MARK: - 对外暴露的可观察状态

    private(set) var state: TimerState
    private(set) var nowTick: Date = .init()

    /// App 是否认为自己已启用 Focus 模式(由 start/reset/complete 维护,与系统真实状态解耦)
    /// UI 徽章读此值,避免依赖 `INFocusStatusCenter` 授权。
    private(set) var appFocusOn: Bool = false

    /// Shortcut 安装状态(由 refreshInstallationStatus / installShortcuts 维护)
    private(set) var installationStatus: ShortcutInstallationStatus = .bothMissing

    /// 用户配置的开启 Focus 的 Shortcut 名称
    var enableShortcut: String {
        didSet { defaults.set(enableShortcut, forKey: DefaultsKey.enableShortcut) }
    }

    /// 用户配置的关闭 Focus 的 Shortcut 名称
    var disableShortcut: String {
        didSet { defaults.set(disableShortcut, forKey: DefaultsKey.disableShortcut) }
    }

    // MARK: - 依赖

    private let timer: TimerEngine
    private let focus: FocusModeControlling
    private let notifications: NotificationManaging
    private let installer: ShortcutInstalling
    private let defaults: UserDefaults

    // MARK: - 内部状态

    private var tickTask: Task<Void, Never>?
    private var notificationID: String?

    /// 复用的时间格式化器
    private let timeFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute, .second]
        f.unitsStyle = .positional
        f.zeroFormattingBehavior = [.pad]
        return f
    }()

    private enum DefaultsKey {
        static let totalDuration = "FocusTimer.totalDuration"
        static let enableShortcut = "FocusTimer.enableShortcut"
        static let disableShortcut = "FocusTimer.disableShortcut"
    }

    static let defaultDuration: TimeInterval = 60 * 60
    static let defaultEnableShortcut = "EnableFocus"
    static let defaultDisableShortcut = "DisableFocus"

    // MARK: - 初始化

    init(
        timer: TimerEngine = TimerEngine(),
        focus: FocusModeControlling = FocusModeController.live(),
        notifications: NotificationManaging = NotificationManager.live(),
        installer: ShortcutInstalling = LiveShortcutInstaller(),
        defaults: UserDefaults = .standard
    ) {
        self.timer = timer
        self.focus = focus
        self.notifications = notifications
        self.installer = installer
        self.defaults = defaults

        let stored = defaults.double(forKey: DefaultsKey.totalDuration)
        let initialDuration: TimeInterval = stored > 0 ? stored : Self.defaultDuration

        let enableName = defaults.string(forKey: DefaultsKey.enableShortcut) ?? Self.defaultEnableShortcut
        let disableName = defaults.string(forKey: DefaultsKey.disableShortcut) ?? Self.defaultDisableShortcut

        self.enableShortcut = enableName
        self.disableShortcut = disableName

        self.state = TimerState(
            phase: .idle,
            totalDuration: initialDuration
        )

        log.info("FocusTimerModel 初始化完成,totalDuration=\(initialDuration)s,enable=\(enableName, privacy: .public),disable=\(disableName, privacy: .public)")
    }

    // MARK: - 公开 API

    /// 修改总时长(仅 idle 生效)
    func setDuration(_ seconds: TimeInterval) {
        guard case .idle = state.phase else {
            log.warning("setDuration 拒绝:非 idle 状态不允许修改时长")
            return
        }
        let clamped = max(60, min(seconds, 24 * 60 * 60))
        state.totalDuration = clamped
        defaults.set(clamped, forKey: DefaultsKey.totalDuration)
        log.info("设置时长: \(clamped)s (\(Int(clamped / 60)) 分钟)")
    }

    /// 开始倒计时
    func start() async {
        log.info(">>> start() 被调用,当前 phase=\(String(describing: self.state.phase))")
        guard case .idle = state.phase else {
            log.error("start() 失败:非 idle 状态无法启动")
            return
        }

        // 1) 触发 Shortcut 启用 Focus
        do {
            try await focus.setEnabled(
                true,
                enableShortcut: enableShortcut,
                disableShortcut: disableShortcut
            )
            log.info("已请求启用 Focus(通过 Shortcut '\(self.enableShortcut, privacy: .public)')")
        } catch {
            let message = (error as NSError).localizedDescription
            log.error("启用 Focus 失败: \(message, privacy: .public)")
            await notifications.sendNow(title: "Focus 切换失败", body: message)
            // 不阻塞计时
        }

        // 1.5) 更新 appFocusOn 徽章(无论 Shortcut 是否成功,意图已下达)
        let prev = appFocusOn
        appFocusOn = true
        log.info("appFocusOn: \(prev ? "true" : "false") -> true")

        // 2) 切换到 running 状态
        let endDate = Date().addingTimeInterval(state.totalDuration)
        state.phase = .running(endDate: endDate)
        log.info("进入 running 状态,endDate=\(endDate, privacy: .public)")

        // 3) 调度完成通知
        await scheduleCompletionNotification(at: endDate)

        // 4) 启动滴答
        startTicking()
    }

    /// 暂停
    func pause() async {
        log.info(">>> pause() 被调用,当前 phase=\(String(describing: self.state.phase))")
        guard case .running(let endDate) = state.phase else {
            log.warning("pause() 跳过:当前非 running 状态")
            return
        }

        let remaining = max(0, endDate.timeIntervalSinceNow)
        state.phase = .paused(remaining: remaining)
        log.info("进入 paused 状态,remaining=\(remaining)s,Focus 保持开启(Shortcut 未触发关闭)")

        await cancelNotification()
        stopTicking()
    }

    /// 恢复
    func resume() async {
        log.info(">>> resume() 被调用,当前 phase=\(String(describing: self.state.phase))")
        guard case .paused(let remaining) = state.phase else {
            log.warning("resume() 跳过:当前非 paused 状态")
            return
        }

        let endDate = Date().addingTimeInterval(remaining)
        state.phase = .running(endDate: endDate)
        log.info("恢复 running 状态,endDate=\(endDate, privacy: .public),remaining=\(remaining)s")

        await scheduleCompletionNotification(at: endDate)
        startTicking()
    }

    /// 重置
    func reset() async {
        log.info(">>> reset() 被调用,当前 phase=\(String(describing: self.state.phase))")

        stopTicking()
        await cancelNotification()

        // 触发 Shortcut 关闭 Focus
        do {
            try await focus.setEnabled(
                false,
                enableShortcut: enableShortcut,
                disableShortcut: disableShortcut
            )
            log.info("已请求关闭 Focus(通过 Shortcut '\(self.disableShortcut, privacy: .public)')")
        } catch {
            let message = (error as NSError).localizedDescription
            log.error("关闭 Focus 失败: \(message, privacy: .public)")
            await notifications.sendNow(title: "Focus 切换失败", body: message)
        }

        // 更新 appFocusOn 徽章
        let prev = appFocusOn
        appFocusOn = false
        log.info("appFocusOn: \(prev ? "true" : "false") -> false")

        state.phase = .idle
        log.info("回到 idle 状态,totalDuration=\(self.state.totalDuration)s")
    }

    /// 读取当前系统是否处于 Focus 状态(需要授权)。UI 用于展示。
    /// [已废弃] 徽章改读 appFocusOn,本方法保留以备未来需要
    func refreshFocusStatus() async {
        log.debug("refreshFocusStatus() 已废弃,无操作")
    }

    /// 检查当前 Shortcut 安装状态(异步,失败时保持上次状态)
    func refreshInstallationStatus() async {
        do {
            installationStatus = try await installer.installationStatus(
                enableName: enableShortcut,
                disableName: disableShortcut
            )
            log.info("Shortcut 安装状态: \(String(describing: self.installationStatus), privacy: .public)")
        } catch {
            log.error("检查 Shortcut 安装状态失败: \(error.localizedDescription, privacy: .public)")
            // 失败时保持上一次的 status,不弹通知(静默)
        }
    }

    /// 用户点击「一键创建 Shortcut」时调用
    /// - 流程:打开 Bundle 中两个 .shortcut 文件 → Shortcuts App 弹导入对话框 → 用户点 Add
    /// - 等 ~2.5s 后重新查询状态
    /// - 失败时通过系统通知告知用户
    @discardableResult
    func installShortcuts() async -> ShortcutInstallationStatus {
        log.info(">>> 用户点击「一键创建 Shortcut」")
        do {
            let newStatus = try await installer.importBoth(bundle: .main)
            installationStatus = newStatus
            if newStatus.isReady {
                log.info("一键创建完成,两个 Shortcut 均已就位")
            } else {
                log.warning("一键创建未完成,可能用户取消了导入对话框: \(String(describing: newStatus), privacy: .public)")
            }
            return newStatus
        } catch {
            let message = (error as NSError).localizedDescription
            log.error("一键创建失败: \(message, privacy: .public)")
            await notifications.sendNow(title: "一键创建 Shortcut 失败", body: message)
            return installationStatus
        }
    }

    // MARK: - 内部

    private func startTicking() {
        tickTask?.cancel()
        tickTask = timer.start { [weak self] in
            Task { @MainActor [weak self] in
                self?.onTick()
            }
        }
        log.debug("滴答任务已启动")
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        log.debug("滴答任务已停止")
    }

    private func onTick() {
        nowTick = Date()
        if case .running(let endDate) = state.phase, endDate.timeIntervalSinceNow <= 0 {
            log.info(">>> 倒计时自然完成")
            Task { await self.handleCompletion() }
        }
    }

    private func handleCompletion() async {
        log.info("处理完成事件")
        stopTicking()

        do {
            try await focus.setEnabled(
                false,
                enableShortcut: enableShortcut,
                disableShortcut: disableShortcut
            )
            log.info("完成:已请求关闭 Focus")
        } catch {
            let message = (error as NSError).localizedDescription
            log.error("完成:关闭 Focus 失败: \(message, privacy: .public)")
            await notifications.sendNow(title: "Focus 切换失败", body: message)
        }

        // 更新 appFocusOn 徽章
        let prev = appFocusOn
        appFocusOn = false
        log.info("appFocusOn: \(prev ? "true" : "false") -> false (完成)")

        state.phase = .idle
        log.info("完成:回到 idle 状态")
    }

    private func scheduleCompletionNotification(at fireDate: Date) async {
        await cancelNotification()
        do {
            let id = try await notifications.schedule(
                at: fireDate,
                title: "FocusTimer",
                body: "专注时段已完成 🎉"
            )
            notificationID = id
            log.info("已调度完成通知,fireDate=\(fireDate, privacy: .public),id=\(id, privacy: .public)")
        } catch {
            log.error("调度完成通知失败: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cancelNotification() async {
        guard let id = notificationID else { return }
        do {
            try await notifications.cancel(id: id)
            log.debug("已取消通知 id=\(id, privacy: .public)")
        } catch {
            log.error("取消通知失败: \(error.localizedDescription, privacy: .public)")
        }
        notificationID = nil
    }

    // MARK: - 格式化

    func menuBarText() -> String {
        let seconds = TimeInterval(Int(state.remaining.rounded(.up)))
        let formatted = timeFormatter.string(from: seconds) ?? "00:00:00"
        switch state.phase {
        case .idle:
            return "Focus \(formatted)"
        case .running, .paused:
            return formatted
        }
    }
}
