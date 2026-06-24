//
//  RestBreakTimerModelTests.swift
//  FocusTimerTests
//
//  Tests for the full-screen rest countdown shown after a focus session completes.
//

import Testing
import Foundation
@testable import FocusTimer

@MainActor
final class FakeRestAlarmPlayer: RestAlarmPlaying {
    private(set) var playCount = 0

    func playRestBreakAlarm() {
        playCount += 1
    }
}

@Suite("RestBreakTimerModel")
@MainActor
struct RestBreakTimerModelTests {

    private func makeModel(
        now: @escaping () -> Date,
        alarm: FakeRestAlarmPlayer? = nil
    ) -> (RestBreakTimerModel, FakeRestAlarmPlayer) {
        let alarm = alarm ?? FakeRestAlarmPlayer()
        let model = RestBreakTimerModel(
            alarm: alarm,
            nowProvider: now,
            automaticallyTicks: false
        )
        return (model, alarm)
    }

    @Test("初始状态:等待选择并暴露 5/15/30 分钟选项")
    func startsInChoosingWithPresetDurations() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        let (model, _) = makeModel(now: { start })

        #expect(model.phase == .choosing)
        #expect(model.presets.map(\.label) == ["5:00", "15:00", "30:00"])
        #expect(model.presets.map(\.duration) == [300, 900, 1_800])
        #expect(model.formattedRemaining == "00:00")
    }

    @Test("开始 5 分钟休息后进入 running 并显示 05:00")
    func startsFiveMinuteBreak() {
        var now = Date(timeIntervalSinceReferenceDate: 2_000)
        let (model, _) = makeModel(now: { now })

        model.start(duration: 300)

        guard case .running(let endDate) = model.phase else {
            Issue.record("Expected running phase")
            return
        }
        #expect(endDate == now.addingTimeInterval(300))
        #expect(model.formattedRemaining == "05:00")

        now = now.addingTimeInterval(299.2)
        model.refresh()
        #expect(model.formattedRemaining == "00:01")

        model.cancel()
    }

    @Test("倒计时完成后进入 finished 并且铃声只响一次")
    func finishesAndPlaysAlarmOnce() {
        var now = Date(timeIntervalSinceReferenceDate: 3_000)
        let (model, alarm) = makeModel(now: { now })

        model.start(duration: 300)
        now = now.addingTimeInterval(300)

        model.refresh()
        model.refresh()

        #expect(model.phase == .finished)
        #expect(model.formattedRemaining == "00:00")
        #expect(alarm.playCount == 1)
    }

    @Test("提前取消休息倒计时不会触发铃声")
    func cancelBeforeFinishPreventsAlarm() {
        var now = Date(timeIntervalSinceReferenceDate: 4_000)
        let (model, alarm) = makeModel(now: { now })

        model.start(duration: 300)
        model.cancel()
        now = now.addingTimeInterval(301)
        model.refresh()

        #expect(model.phase == .choosing)
        #expect(alarm.playCount == 0)
    }
}
