//
//  RestReminderView.swift
//  FocusTimer
//
//  倒计时结束后的全屏休息提醒视图。
//  黑底 + 咖啡杯 SF Symbol + 大字号中文 + 单「我知道了」按钮。
//  由 RestReminderWindowController 托管在 borderless NSWindow 中。
//

import SwiftUI

struct RestReminderView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 120, weight: .regular))
                    .foregroundStyle(.white.opacity(0.95))

                Text("该休息了")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("专注时段已完成,起身活动一下吧。")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: onDismiss) {
                    Text("我知道了")
                        .font(.title3.weight(.semibold))
                        .frame(minWidth: 160, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)   // 显式 Escape 绑定
                .padding(.top, 16)
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RestReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
        .background(Color.black)
}
