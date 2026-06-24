//
//  RestReminderView.swift
//  FocusTimer
//
//  倒计时结束后的全屏休息提醒视图。
//  黑底 + 大字号中文 + 可选 5/15/30 分钟休息倒计时。
//  由 RestReminderWindowController 托管在 borderless NSWindow 中。
//

import SwiftUI

struct RestReminderView: View {
    let timer: RestBreakTimerModel
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
                .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch timer.phase {
        case .choosing:
            choosingContent
        case .running:
            runningContent
        case .finished:
            finishedContent
        }
    }

    private var choosingContent: some View {
        VStack(spacing: 28) {
            symbol("cup.and.saucer.fill")

            Text("该休息了")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("专注时段已完成,选择一段休息倒计时。")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            HStack(spacing: 14) {
                ForEach(timer.presets) { preset in
                    Button {
                        timer.start(duration: preset.duration)
                    } label: {
                        Text(preset.label)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .frame(width: 108, height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.top, 4)

            dismissButton("我知道了")
        }
    }

    private var runningContent: some View {
        VStack(spacing: 26) {
            symbol("timer")

            Text(timer.formattedRemaining)
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)

            Text("正在休息,倒计时结束后会响铃。")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            dismissButton("结束休息")
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 26) {
            symbol("bell.fill")

            Text("休息结束")
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text(timer.formattedRemaining)
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.9))

            Text("准备回到专注吧。")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            dismissButton("我知道了")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 120, weight: .regular))
            .foregroundStyle(.white.opacity(0.95))
    }

    private func dismissButton(_ title: String) -> some View {
        Button(action: onDismiss) {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(minWidth: 160, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.cancelAction)
        .padding(.top, 16)
    }
}

#Preview {
    RestReminderView(timer: RestBreakTimerModel(), onDismiss: {})
        .frame(width: 800, height: 600)
        .background(Color.black)
}
