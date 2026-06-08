//
//  NotificationManager.swift
//  FocusTimer
//
//  UNUserNotificationCenter 的封装,用于在倒计时结束时发送系统通知。
//  - requestAuthorization: 首次启动时请求通知权限
//  - schedule(at:): 在指定时间触发本地通知
//  - cancel(id:): 取消已调度的通知(暂停/重置时使用)
//

import Foundation
import UserNotifications
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "NotificationManager")

protocol NotificationManaging {
    /// 请求通知权限,返回是否授权成功
    func requestAuthorization() async -> Bool

    /// 调度一个本地通知,返回通知 id(用于后续取消)
    func schedule(at fireDate: Date, title: String, body: String) async throws -> String

    /// 取消指定 id 的通知
    func cancel(id: String) async throws

    /// 立即发送一条本地通知(无 trigger),用于运行时错误提示
    func sendNow(title: String, body: String) async
}

enum NotificationManager {

    static func live() -> NotificationManaging { LiveNotificationManager() }

    private final class LiveNotificationManager: NotificationManaging {
        private var center: UNUserNotificationCenter { .current() }

        func requestAuthorization() async -> Bool {
            log.info("请求通知权限...")
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                log.info("通知权限结果: granted=\(granted)")
                return granted
            } catch {
                log.error("请求通知权限失败: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }

        func schedule(at fireDate: Date, title: String, body: String) async throws -> String {
            let id = UUID().uuidString

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            // 抽取日期分量(本地时区)
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            log.info("调度通知 id=\(id, privacy: .public) at \(comps, privacy: .public)")
            try await center.add(request)
            return id
        }

        func cancel(id: String) async throws {
            log.debug("取消通知 id=\(id, privacy: .public)")
            center.removePendingNotificationRequests(withIdentifiers: [id])
        }

        func sendNow(title: String, body: String) async {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil   // nil = 立即投递
            )
            do {
                try await center.add(request)
            } catch {
                log.error("发送即时通知失败: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
