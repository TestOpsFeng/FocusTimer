//
//  ShortcutInstallerTests.swift
//  FocusTimerTests
//
//  ShortcutInstaller 单元测试 — 使用 MockProcessRunner / MockWorkspaceOpener
//  隔离所有 IO,纯函数 computeStatus 也直接覆盖。
//

import Testing
import Foundation
@testable import FocusTimer

@Suite("ShortcutInstaller")
struct ShortcutInstallerTests {

    // MARK: - Mock 桩

    final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
        var result: ProcessResult
        var calls: [(executable: String, arguments: [String])] = []

        init(result: ProcessResult) { self.result = result }

        func run(executable: String, arguments: [String]) async throws -> ProcessResult {
            calls.append((executable, arguments))
            return result
        }
    }

    final class MockWorkspaceOpener: WorkspaceOpening, @unchecked Sendable {
        var openedURLs: [URL] = []
        var shouldSucceed: Bool = true
        @MainActor func open(_ url: URL) -> Bool {
            openedURLs.append(url)
            return shouldSucceed
        }
    }

    private func makeInstaller(
        runner: MockProcessRunner = MockProcessRunner(result: .empty),
        opener: MockWorkspaceOpener = MockWorkspaceOpener()
    ) -> LiveShortcutInstaller {
        LiveShortcutInstaller(processRunner: runner, workspaceOpener: opener)
    }

    // MARK: - listInstalledNames

    @Test("listInstalledNames: parses single shortcut")
    func testListSingle() async throws {
        let runner = MockProcessRunner(result: ProcessResult(
            success: true, exitCode: 0,
            stdout: "开启专注\n", stderr: ""
        ))
        let installer = makeInstaller(runner: runner)
        let names = try await installer.listInstalledNames()
        #expect(names == ["开启专注"])
    }

    @Test("listInstalledNames: parses multiple shortcuts and trims whitespace")
    func testListMultiple() async throws {
        let runner = MockProcessRunner(result: ProcessResult(
            success: true, exitCode: 0,
            stdout: "  开启专注  \n关闭专注\n\nFoo Bar\n", stderr: ""
        ))
        let installer = makeInstaller(runner: runner)
        let names = try await installer.listInstalledNames()
        #expect(names == ["开启专注", "关闭专注", "Foo Bar"])
    }

    @Test("listInstalledNames: throws on non-zero exit")
    func testListFailureThrows() async throws {
        let runner = MockProcessRunner(result: ProcessResult(
            success: false, exitCode: 1, stdout: "", stderr: "boom"
        ))
        let installer = makeInstaller(runner: runner)
        await #expect(throws: NSError.self) {
            _ = try await installer.listInstalledNames()
        }
    }

    @Test("listInstalledNames: invokes /usr/bin/shortcuts list with correct args")
    func testListInvokesCorrectCommand() async throws {
        let runner = MockProcessRunner(result: .empty)
        let installer = makeInstaller(runner: runner)
        _ = try? await installer.listInstalledNames()
        #expect(runner.calls.count == 1)
        #expect(runner.calls[0].executable == "/usr/bin/shortcuts")
        #expect(runner.calls[0].arguments == ["list"])
    }

    @Test("listInstalledNames: empty stdout returns empty array")
    func testListEmptyOutput() async throws {
        let runner = MockProcessRunner(result: .empty)
        let installer = makeInstaller(runner: runner)
        let names = try await installer.listInstalledNames()
        #expect(names.isEmpty)
    }

    // MARK: - computeStatus(纯函数)

    @Test("computeStatus: both present")
    func testStatusBothPresent() {
        let installer = makeInstaller()
        let s = installer.computeStatus(
            installed: ["开启专注", "关闭专注", "Other"],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .bothPresent)
    }

    @Test("computeStatus: enable missing only")
    func testStatusEnableMissing() {
        let installer = makeInstaller()
        let s = installer.computeStatus(
            installed: ["关闭专注"],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .enableMissing)
    }

    @Test("computeStatus: disable missing only")
    func testStatusDisableMissing() {
        let installer = makeInstaller()
        let s = installer.computeStatus(
            installed: ["开启专注"],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .disableMissing)
    }

    @Test("computeStatus: both missing")
    func testStatusBothMissing() {
        let installer = makeInstaller()
        let s = installer.computeStatus(
            installed: ["Other"],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .bothMissing)
    }

    @Test("computeStatus: exact match only, no fuzzy whitespace match")
    func testStatusExactMatchNoFuzzy() {
        let installer = makeInstaller()
        // " 开启专注 " 中含空格,不应与 "开启专注" 匹配
        let s = installer.computeStatus(
            installed: [" 开启专注 ", "关闭专注"],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .enableMissing)
    }

    @Test("computeStatus: empty installed → bothMissing")
    func testStatusEmptyInstalled() {
        let installer = makeInstaller()
        let s = installer.computeStatus(
            installed: [],
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .bothMissing)
    }

    // MARK: - installationStatus(端到端 IO + 计算)

    @Test("installationStatus: combines list + compute correctly")
    func testInstallationStatusEndToEnd() async throws {
        let runner = MockProcessRunner(result: ProcessResult(
            success: true, exitCode: 0,
            stdout: "开启专注\n关闭专注\n", stderr: ""
        ))
        let installer = makeInstaller(runner: runner)
        let s = try await installer.installationStatus(
            enableName: "开启专注", disableName: "关闭专注"
        )
        #expect(s == .bothPresent)
        #expect(s.isReady)
    }

    // MARK: - ShortcutRole.resourceName 拼装

    @Test("ShortcutRole: 资源名拼装")
    func testShortcutRoleResourceNames() {
        #expect(ShortcutRole.enable.bundledResourceName == "开始专注")
        #expect(ShortcutRole.disable.bundledResourceName == "关闭专注")
    }

    // MARK: - openImportDialog

    @MainActor
    @Test("openImportDialog: forwards to workspaceOpener and records URL")
    func testOpenImportDialog() {
        let opener = MockWorkspaceOpener()
        let installer = makeInstaller(opener: opener)
        let url = URL(fileURLWithPath: "/tmp/Foo.shortcut")
        let ok = installer.openImportDialog(for: url)
        #expect(ok == true)
        #expect(opener.openedURLs == [url])
    }

    @MainActor
    @Test("openImportDialog: returns false when workspaceOpener fails")
    func testOpenImportDialogFails() {
        let opener = MockWorkspaceOpener()
        opener.shouldSucceed = false
        let installer = makeInstaller(opener: opener)
        let url = URL(fileURLWithPath: "/tmp/Foo.shortcut")
        let ok = installer.openImportDialog(for: url)
        #expect(ok == false)
        #expect(opener.openedURLs == [url])
    }

    // MARK: - bundledShortcutURL

    @Test("bundledShortcutURL: nil when resource missing in bundle")
    func testBundledURLMissing() {
        let installer = makeInstaller()
        // /tmp 几乎肯定不含 EnableFocus.shortcut
        let emptyBundle = Bundle(path: "/tmp") ?? .main
        let url = installer.bundledShortcutURL(for: .enable, bundle: emptyBundle)
        #expect(url == nil)
    }

    // MARK: - importBoth

    @MainActor
    @Test("importBoth: throws when bundle lacks .shortcut resources")
    func testImportBothMissingResources() async throws {
        let installer = makeInstaller()
        let emptyBundle = Bundle(path: "/tmp") ?? .main
        await #expect(throws: NSError.self) {
            _ = try await installer.importBoth(bundle: emptyBundle)
        }
    }
}

private extension ProcessResult {
    static let empty = ProcessResult(success: true, exitCode: 0, stdout: "", stderr: "")
}
