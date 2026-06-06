//
//  TimerState.swift
//  FocusTimer
//
//  视图模型对外暴露的状态。包含:
//  - phase: 当前状态机相位(idle / running / paused)
//  - totalDuration: 用户配置的总时长(秒),空闲时显示在菜单栏
//  - focusAuthorized: 用户是否已授权控制专注模式(用于 UI 提示)
//

import Foundation

struct TimerState: Equatable {
    var phase: FocusPhase
    var totalDuration: TimeInterval

    /// 当前剩余时间(秒)。running 状态下由 endDate 推导,paused 直接返回冻结值。
    var remaining: TimeInterval {
        switch phase {
        case .idle:
            return totalDuration
        case .running(let endDate):
            return max(0, endDate.timeIntervalSinceNow)
        case .paused(let remaining):
            return remaining
        }
    }

    /// 是否处于"专注中"——running 或 paused 都算。用于 UI 状态判断。
    var isFocusing: Bool {
        switch phase {
        case .running, .paused: return true
        case .idle:             return false
        }
    }

    /// 是否处于"已暂停"状态。
    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }
}
