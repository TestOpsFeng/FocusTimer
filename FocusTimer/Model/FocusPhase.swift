//
//  FocusPhase.swift
//  FocusTimer
//
//  倒计时状态机:三态(idle / running / paused)
//  - idle: 等待开始,没有进行中的计时
//  - running: 倒计时进行中,以墙钟锚点 endDate 驱动,不受暂停影响
//  - paused: 用户主动暂停,剩余时间被冻结;恢复时基于 now + remaining 计算新 endDate
//

import Foundation

enum FocusPhase: Equatable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
}
