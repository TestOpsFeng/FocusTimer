//
//  TimerEngine.swift
//  FocusTimer
//
//  1Hz 滴答驱动。基于 Task.sleep 而非 Timer.scheduledTimer:
//  - 干净的取消语义(Task.cancel())
//  - 与 Swift 并发模型天然集成
//  - 无需 @objc 桥接、RunLoop 配置
//

import Foundation
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "TimerEngine")

final class TimerEngine {

    /// 启动一个 1Hz 滴答任务,持续调用 onTick,直到 task 被 cancel。
    /// 返回的 Task 由调用方持有。
    func start(_ onTick: @escaping @Sendable () -> Void) -> Task<Void, Never> {
        log.debug("TimerEngine 启动滴答")
        return Task.detached(priority: .utility) {
            // 立即触发一次,避免菜单栏初始化时延一秒
            onTick()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    // sleep 抛出 CancellationError,正常退出
                    log.debug("TimerEngine 滴答被取消")
                    return
                }
                onTick()
            }
        }
    }
}
