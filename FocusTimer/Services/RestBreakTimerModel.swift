//
//  RestBreakTimerModel.swift
//  FocusTimer
//
//  Shared countdown model for the full-screen rest reminder.
//

import AppKit
import Foundation
import Observation
import os.log

private let restBreakLog = Logger(subsystem: "com.example.FocusTimer", category: "RestBreakTimerModel")

enum RestBreakPhase: Equatable {
    case choosing
    case running(endDate: Date)
    case finished
}

struct RestBreakPreset: Equatable, Identifiable {
    let minutes: Int

    var id: Int { minutes }
    var duration: TimeInterval { TimeInterval(minutes * 60) }
    var label: String { "\(minutes):00" }
}

protocol RestAlarmPlaying: AnyObject {
    @MainActor func playRestBreakAlarm()
}

final class SystemRestAlarmPlayer: RestAlarmPlaying {
    @MainActor
    func playRestBreakAlarm() {
        NSSound.beep()
    }
}

@Observable
@MainActor
final class RestBreakTimerModel {

    private(set) var phase: RestBreakPhase = .choosing
    private(set) var now: Date

    let presets: [RestBreakPreset] = [
        RestBreakPreset(minutes: 5),
        RestBreakPreset(minutes: 15),
        RestBreakPreset(minutes: 30)
    ]

    private let alarm: RestAlarmPlaying
    private let nowProvider: () -> Date
    private let automaticallyTicks: Bool
    private var tickTask: Task<Void, Never>?
    private var alarmPlayed = false

    init(
        alarm: RestAlarmPlaying = SystemRestAlarmPlayer(),
        nowProvider: @escaping () -> Date = Date.init,
        automaticallyTicks: Bool = true
    ) {
        self.alarm = alarm
        self.nowProvider = nowProvider
        self.automaticallyTicks = automaticallyTicks
        self.now = nowProvider()
    }

    var remaining: TimeInterval {
        switch phase {
        case .choosing, .finished:
            return 0
        case .running(let endDate):
            return max(0, endDate.timeIntervalSince(now))
        }
    }

    var formattedRemaining: String {
        let totalSeconds = max(0, Int(remaining.rounded(.up)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start(duration: TimeInterval) {
        guard duration > 0 else { return }
        now = nowProvider()
        phase = .running(endDate: now.addingTimeInterval(duration))
        alarmPlayed = false
        restBreakLog.info("开始休息倒计时,duration=\(duration, privacy: .public)s")
        if automaticallyTicks {
            startTicking()
        }
    }

    func refresh() {
        now = nowProvider()
        finishIfNeeded()
    }

    func cancel() {
        stopTicking()
        if case .running = phase {
            phase = .choosing
        }
        restBreakLog.debug("休息倒计时已取消")
    }

    private func startTicking() {
        stopTicking()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                if Task.isCancelled { return }
                self?.refresh()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func finishIfNeeded() {
        guard case .running(let endDate) = phase, now >= endDate else { return }
        stopTicking()
        phase = .finished
        restBreakLog.info("休息倒计时完成")
        guard !alarmPlayed else { return }
        alarmPlayed = true
        alarm.playRestBreakAlarm()
    }
}
