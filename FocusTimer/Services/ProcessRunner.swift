//
//  ProcessRunner.swift
//  FocusTimer
//
//  抽象子进程调用。提供 ProcessRunning 协议 + LiveProcessRunner 真实实现,
//  以及可在测试中注入的 MockProcessRunner 桩。
//
//  用例:
//  - FocusModeController.setEnabled 触发 Shortcut(走 /usr/bin/shortcuts run)
//  - ShortcutInstaller.listInstalledNames 列出已安装的 Shortcut(走 shortcuts list)
//
//  设计要点:
//  - 阻塞 IO 全部包在 Task.detached 中,异步返回
//  - 永远不抛错 —— 失败信息全部进入 ProcessResult,让调用方决定如何呈现
//  - stdout / stderr 用 UTF-8 解码,失败时回退到空字符串
//

import Foundation
import os.log

private let log = Logger(subsystem: "com.example.FocusTimer", category: "ProcessRunner")

struct ProcessResult: Equatable, Sendable {
    let success: Bool
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol ProcessRunning: Sendable {
    /// 在后台线程同步执行 `executable arguments...`,返回捕获到的 stdout/stderr/exitCode。
    /// 不会抛错 —— 启动失败 / 子进程非 0 退出 / 任何 IO 异常都封装到 ProcessResult。
    func run(
        executable: String,
        arguments: [String]
    ) async throws -> ProcessResult
}

struct LiveProcessRunner: ProcessRunning {

    func run(executable: String, arguments: [String]) async throws -> ProcessResult {
        await Task.detached(priority: .userInitiated) { () -> ProcessResult in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                log.error("启动子进程失败: \(executable, privacy: .public) args=\(arguments, privacy: .public) err=\(error.localizedDescription, privacy: .public)")
                return ProcessResult(
                    success: false,
                    exitCode: -1,
                    stdout: "",
                    stderr: "无法启动 \(executable): \(error.localizedDescription)"
                )
            }

            // readToEnd 是阻塞 IO —— Task.detached 已经把整个调用挪到后台线程
            let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
            let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
            process.waitUntilExit()

            let result = ProcessResult(
                success: process.terminationStatus == 0,
                exitCode: process.terminationStatus,
                stdout: String(data: outData, encoding: .utf8) ?? "",
                stderr: String(data: errData, encoding: .utf8) ?? ""
            )
            log.debug("子进程退出: \(executable, privacy: .public) exit=\(result.exitCode) stdout_bytes=\(outData.count) stderr_bytes=\(errData.count)")
            return result
        }.value
    }
}
