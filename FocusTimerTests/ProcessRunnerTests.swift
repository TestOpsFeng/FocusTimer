//
//  ProcessRunnerTests.swift
//  FocusTimerTests
//
//  LiveProcessRunner 的集成测试(真实子进程调用)。不 mock,验证:
//  - /usr/bin/shortcuts --help 能跑通,stdout 含 "OVERVIEW"
//  - 不存在的命令返回 failure 而非崩溃
//

import Testing
import Foundation
@testable import FocusTimer

@Suite("ProcessRunner (集成,真实子进程)")
struct ProcessRunnerTests {

    @Test("LiveProcessRunner 能跑 shortcuts --help 并捕获 stdout")
    func testLiveShortcutsHelp() async throws {
        let runner = LiveProcessRunner()
        let result = try await runner.run(
            executable: "/usr/bin/shortcuts",
            arguments: ["--help"]
        )
        #expect(result.success)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("OVERVIEW"))
    }

    @Test("LiveProcessRunner 对不存在命令返回 failure 而非崩溃")
    func testLiveMissingCommand() async throws {
        let runner = LiveProcessRunner()
        let result = try await runner.run(
            executable: "/usr/bin/__definitely_does_not_exist__",
            arguments: []
        )
        #expect(result.success == false)
        #expect(result.exitCode != 0)
    }

    @Test("LiveProcessRunner 中文参数不丢失(UTF-8 正确)")
    func testLiveChineseArguments() async throws {
        // /bin/echo 把 arguments 串起来,验证中文原样透传
        let runner = LiveProcessRunner()
        let result = try await runner.run(
            executable: "/bin/echo",
            arguments: ["开启专注", "关闭专注"]
        )
        #expect(result.success)
        #expect(result.stdout.contains("开启专注"))
        #expect(result.stdout.contains("关闭专注"))
    }
}
