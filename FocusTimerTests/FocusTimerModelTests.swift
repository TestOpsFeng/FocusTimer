//
//  FocusTimerModelTests.swift
//  FocusTimerTests
//
//  单元测试覆盖:
//  1) showRestReminder 的默认值/持久化/migration/setter 幂等性
//  2) handleCompletion 在开关开启/关闭时对 RestReminderPresenting 的调用分支
//
//  使用协议 stub 隔离所有 IO(focus / notifications / installer 全部 stub 掉),
//  配合 #if DEBUG 暴露的 _testHandleCompletion() 直接驱动完成流程。
//

import Testing
import Foundation
import Intents
@testable import FocusTimer

// MARK: - Mocks & Stubs

@MainActor
final class MockRestReminderPresenter: RestReminderPresenting {
    private(set) var showCallCount = 0
    private(set) var dismissCallCount = 0

    func showRestReminder()    { showCallCount += 1 }
    func dismissRestReminder() { dismissCallCount += 1 }
}

struct StubFocus: FocusModeControlling {
    func authorizationStatus() async -> INFocusStatusAuthorizationStatus { .authorized }
    func requestAuthorization() async throws {}
    func isCurrentlyFocused() async -> Bool { false }
    func setEnabled(_ enabled: Bool, enableShortcut: String, disableShortcut: String) async throws {}
}

struct StubNotifications: NotificationManaging {
    func requestAuthorization() async -> Bool { true }
    func schedule(at fireDate: Date, title: String, body: String) async throws -> String { "stub" }
    func cancel(id: String) async throws {}
    func sendNow(title: String, body: String) async {}
}

struct StubInstaller: ShortcutInstalling {
    func listInstalledNames() async throws -> [String] { [] }
    func installationStatus(enableName: String, disableName: String) async throws -> ShortcutInstallationStatus { .bothMissing }
    func bundledShortcutURL(for role: ShortcutRole, bundle: Bundle) -> URL? { nil }
    @MainActor func openImportDialog(for url: URL) -> Bool { false }
    @MainActor func importBoth(bundle: Bundle) async throws -> ShortcutInstallationStatus { .bothMissing }
}

// MARK: - 配置持久化

@Suite("FocusTimerModel - 全屏休息提醒配置")
@MainActor
struct FocusTimerModelConfigTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "FocusTimerModelTests.\(UUID().uuidString)")!
    }

    @Test("默认值:showRestReminder 为 true(用户已确认默认开启)")
    func defaultIsOn() {
        let d = makeDefaults()
        let model = FocusTimerModel(defaults: d)
        #expect(model.showRestReminder == true)
    }

    @Test("构造时一次性 migration:首次构造后 defaults 已写入默认值")
    func firstInitWritesDefault() {
        let d = makeDefaults()
        #expect(d.object(forKey: "FocusTimer.showRestReminder") == nil)
        _ = FocusTimerModel(defaults: d)
        #expect(d.bool(forKey: "FocusTimer.showRestReminder") == true)
    }

    @Test("setShowRestReminder(false) 写入 defaults 并可被新实例读出")
    func setOffPersistsAndReloads() {
        let d = makeDefaults()
        let model = FocusTimerModel(defaults: d)
        model.setShowRestReminder(false)
        #expect(model.showRestReminder == false)
        let model2 = FocusTimerModel(defaults: d)
        #expect(model2.showRestReminder == false)
    }

    @Test("构造时读已存在的 defaults 值(以 false 为例)")
    func loadsExistingDefaults() {
        let d = makeDefaults()
        d.set(false, forKey: "FocusTimer.showRestReminder")
        let model = FocusTimerModel(defaults: d)
        #expect(model.showRestReminder == false)
    }

    @Test("setShowRestReminder 幂等:同值不抛错、不重复写 defaults")
    func idempotentSetter() {
        let d = makeDefaults()
        let model = FocusTimerModel(defaults: d)
        model.setShowRestReminder(false)
        model.setShowRestReminder(false)
        #expect(model.showRestReminder == false)
        #expect(d.bool(forKey: "FocusTimer.showRestReminder") == false)
    }
}

// MARK: - handleCompletion 集成

@Suite("FocusTimerModel - handleCompletion 集成")
@MainActor
struct FocusTimerModelCompletionTests {

    private func makeModel(
        presenter: MockRestReminderPresenter,
        defaults: UserDefaults
    ) -> FocusTimerModel {
        FocusTimerModel(
            focus: StubFocus(),
            notifications: StubNotifications(),
            installer: StubInstaller(),
            restReminder: presenter,
            defaults: defaults
        )
    }

    @Test("handleCompletion:开关开启时调用 presenter 一次(默认)")
    func completionOnShowsOnce() async {
        let presenter = MockRestReminderPresenter()
        let d = UserDefaults(suiteName: "tests.\(UUID())")!
        let model = makeModel(presenter: presenter, defaults: d)
        // 默认就是开启
        await model._testHandleCompletion()
        #expect(presenter.showCallCount == 1)
        #expect(presenter.dismissCallCount == 0)
    }

    @Test("handleCompletion:开关关闭时不调用 presenter")
    func completionOffDoesNotShow() async {
        let presenter = MockRestReminderPresenter()
        let d = UserDefaults(suiteName: "tests.\(UUID())")!
        let model = makeModel(presenter: presenter, defaults: d)
        model.setShowRestReminder(false)
        await model._testHandleCompletion()
        #expect(presenter.showCallCount == 0)
    }
}
