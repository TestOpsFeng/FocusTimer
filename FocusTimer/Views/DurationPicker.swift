//
//  DurationPicker.swift
//  FocusTimer
//
//  时长选择 UI:快捷按钮 15/30/45/60/90 分钟 + 自定义分钟数输入框。
//  仅在 idle 状态启用;运行/暂停中灰显。
//

import SwiftUI

struct DurationPicker: View {
    @Bindable var model: FocusTimerModel

    /// 预置的快捷时长(分钟)
    private let presets: [Int] = [15, 30, 45, 60, 90]

    /// 自定义输入框的本地状态(独立于 model,避免每个键入都触发 model 写入)
    @State private var customMinutesText: String = ""

    /// 当前是否可编辑(idle 才允许)
    private var isEditable: Bool {
        if case .idle = model.state.phase { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("时长")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 快捷时长按钮(网格布局)
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                spacing: 6
            ) {
                ForEach(presets, id: \.self) { minutes in
                    Button {
                        model.setDuration(TimeInterval(minutes * 60))
                    } label: {
                        Text("\(minutes)")
                            .font(.callout)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.bordered)
                    .tint(isSelected(minutes: minutes) ? .accentColor : .secondary)
                    .disabled(!isEditable)
                }
            }

            // 自定义分钟输入
            HStack(spacing: 6) {
                Text("自定义")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("分钟", text: $customMinutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(!isEditable)
                    .onSubmit(applyCustom)
                Button("应用", action: applyCustom)
                    .disabled(!isEditable || !isValidCustom)
            }
        }
        .onAppear {
            // 初始化输入框为当前时长的分钟数
            let currentMinutes = Int(model.state.totalDuration / 60)
            customMinutesText = "\(currentMinutes)"
        }
    }

    private func isSelected(minutes: Int) -> Bool {
        Int(model.state.totalDuration / 60) == minutes
    }

    private var isValidCustom: Bool {
        guard let n = Int(customMinutesText.trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        return n >= 1 && n <= 24 * 60
    }

    private func applyCustom() {
        guard let n = Int(customMinutesText.trimmingCharacters(in: .whitespaces)),
              n >= 1, n <= 24 * 60 else { return }
        model.setDuration(TimeInterval(n * 60))
    }
}
