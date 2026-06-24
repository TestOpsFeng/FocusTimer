//
//  ShortcutInstaller.swift
//  FocusTimer
//
//  在 App 内一键创建 / 检测用户在 Shortcuts App 中的「开始专注 / 关闭专注」Shortcut。
//
//  - 检测:走 `shortcuts list` CLI 列出已安装的 Shortcut 名称,与 App 配置的
//    enableShortcut / disableShortcut 对比,得到 InstallationStatus。
//  - 恢复:Bundle 内预置两个 .shortcut 文件(开发者一次性创建 + 提交),
//    点击「一键创建 Shortcut」时通过 NSWorkspace.open(url) 让 Shortcuts App
//    弹"Add Shortcut"对话框,用户点 Add 即可完成导入。
//
//  协议设计:ProcessRunning / WorkspaceOpening 都可注入,便于单测。
//

import Foundation
import AppKit
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "ShortcutInstaller")

// MARK: - 公共类型

enum ShortcutRole: String, Sendable {
    case enable
    case disable

    /// Bundle 中 .shortcut 文件的资源名(不含扩展名)
    var bundledResourceName: String {
        switch self {
        case .enable:  return "开始专注"
        case .disable: return "关闭专注"
        }
    }
}

enum ShortcutInstallationStatus: Equatable, Sendable {
    case bothPresent
    case enableMissing
    case disableMissing
    case bothMissing

    var isReady: Bool { self == .bothPresent }
}

// MARK: - 协议

protocol WorkspaceOpening: Sendable {
    @MainActor func open(_ url: URL) -> Bool
}

protocol ShortcutInstalling: Sendable {
    /// 列出当前 Shortcuts 库中所有 Shortcut 的名称(走 `shortcuts list` CLI)
    func listInstalledNames() async throws -> [String]

    /// 计算当前 app 配置的「开启/关闭」Shortcut 的安装状态
    func installationStatus(enableName: String, disableName: String) async throws -> ShortcutInstallationStatus

    /// Bundle 中预置的 .shortcut 文件 URL(可能为 nil,表示资源缺失)
    func bundledShortcutURL(for role: ShortcutRole, bundle: Bundle) -> URL?

    /// 触发 Shortcuts App 的导入对话框(用户需在弹窗中点 "Add Shortcut")
    @MainActor func openImportDialog(for url: URL) -> Bool

    /// 一次导入 enable + disable 两个 Shortcut,完成后返回最新状态
    @MainActor func importBoth(bundle: Bundle) async throws -> ShortcutInstallationStatus
}

// MARK: - 真实实现

struct LiveWorkspaceOpener: WorkspaceOpening {
    @MainActor func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

struct LiveShortcutInstaller: ShortcutInstalling {

    let processRunner: ProcessRunning
    let workspaceOpener: WorkspaceOpening

    init(
        processRunner: ProcessRunning = LiveProcessRunner(),
        workspaceOpener: WorkspaceOpening = LiveWorkspaceOpener()
    ) {
        self.processRunner = processRunner
        self.workspaceOpener = workspaceOpener
    }

    // 默认 Shortcut 名称(与 .shortcut 文件名必须一致)
    // 注意:macOS 26 导出的签名 .shortcut 文件,导入时使用**文件名**作为 Shortcut 名称,
    // 而非 .shortcut 文件中原本保存的 Shortcut 名称。
    // 因此这里必须与 Resources/Shortcuts/ 目录下的文件名(bundledResourceName)保持一致。
    static let defaultEnableName  = "开始专注"
    static let defaultDisableName = "关闭专注"

    func listInstalledNames() async throws -> [String] {
        let result = try await processRunner.run(
            executable: "/usr/bin/shortcuts",
            arguments: ["list"]
        )
        if !result.success {
            throw NSError(
                domain: "ShortcutInstaller",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: "无法列出已安装的 Shortcut: \(result.stderr)"]
            )
        }
        return result.stdout
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func installationStatus(enableName: String, disableName: String) async throws -> ShortcutInstallationStatus {
        let installed = try await listInstalledNames()
        return computeStatus(installed: installed, enableName: enableName, disableName: disableName)
    }

    /// 纯函数(无 IO) — 便于在测试中直接验证
    func computeStatus(
        installed: [String],
        enableName: String,
        disableName: String
    ) -> ShortcutInstallationStatus {
        let hasEnable  = installed.contains(enableName)
        let hasDisable = installed.contains(disableName)
        switch (hasEnable, hasDisable) {
        case (true, true):   return .bothPresent
        case (false, true):  return .enableMissing
        case (true, false):  return .disableMissing
        case (false, false): return .bothMissing
        }
    }

    func bundledShortcutURL(for role: ShortcutRole, bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: role.bundledResourceName, withExtension: "shortcut")
    }

    @MainActor
    func openImportDialog(for url: URL) -> Bool {
        let ok = workspaceOpener.open(url)
        log.info("打开导入对话框: \(url.lastPathComponent, privacy: .public) -> \(ok ? "成功" : "失败", privacy: .public)")
        return ok
    }

    @MainActor
    func importBoth(bundle: Bundle = .main) async throws -> ShortcutInstallationStatus {
        guard let enableURL = bundledShortcutURL(for: .enable, bundle: bundle) else {
            throw NSError(
                domain: "ShortcutInstaller",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Bundle 缺少 开始专注.shortcut"]
            )
        }
        guard let disableURL = bundledShortcutURL(for: .disable, bundle: bundle) else {
            throw NSError(
                domain: "ShortcutInstaller",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Bundle 缺少 关闭专注.shortcut"]
            )
        }

        // 串行触发两个对话框,避免 Shortcuts App 同时堆叠两个 sheet 时用户混淆
        _ = openImportDialog(for: enableURL)
        try? await Task.sleep(nanoseconds: 1_000_000_000)   // 1s
        _ = openImportDialog(for: disableURL)
        // 给 Shortcuts App 时间处理完两个 Add 操作
        try? await Task.sleep(nanoseconds: 1_500_000_000)   // 1.5s

        // 重新查询一次状态
        return try await installationStatus(
            enableName: Self.defaultEnableName,
            disableName: Self.defaultDisableName
        )
    }
}
