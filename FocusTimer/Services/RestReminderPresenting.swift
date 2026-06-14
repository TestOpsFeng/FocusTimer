//
//  RestReminderPresenting.swift
//  FocusTimer
//
//  休息提醒窗口的展示抽象。FocusTimerModel 通过协议持有,
//  便于测试时注入 mock,与 NotificationManaging / ShortcutInstalling 同型。
//
//  真实实现见 LiveRestReminderPresenter,NSWindow 实际托管在
//  RestReminderWindowController 里。
//

import Foundation

/// 休息提醒窗口的展示抽象。方法本身是 @MainActor(因为要操作 NSWindow/NSApp),
/// 但协议本身不需要 @MainActor,以便工厂方法可以从非隔离上下文调用。
protocol RestReminderPresenting: AnyObject {
    /// 显示休息提醒窗口(按当前 NSScreen 数量全屏铺开)
    @MainActor func showRestReminder()

    /// 主动关闭并销毁已显示的窗口
    @MainActor func dismissRestReminder()
}

/// 真实实现工厂(同 NotificationManager.live() 风格)
enum RestReminderPresenter {
    static func live() -> RestReminderPresenting {
        LiveRestReminderPresenter()
    }
}

/// 真实 controller(NSWindow 实际托管在 RestReminderWindowController 里)
final class LiveRestReminderPresenter: RestReminderPresenting {
    private var controller: RestReminderWindowController?

    func showRestReminder() {
        let c = RestReminderWindowController()
        c.show()
        controller = c
    }

    func dismissRestReminder() {
        controller?.dismiss()
        controller = nil
    }
}
