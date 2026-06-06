//
//  MenuBarLabel.swift
//  FocusTimer
//
//  菜单栏图标:一个文本(因 MenuBarExtra label 不支持 SF Symbol 直接作为图标位)。
//  显示 "Focus 60:00"(空闲)或 "00:42:13"(运行/暂停)。
//  .monospacedDigit() 在外部调用方(FocusTimerApp)应用,避免秒数变化时菜单栏宽度抖动。
//

import SwiftUI

struct MenuBarLabel: View {
    let model: FocusTimerModel

    var body: some View {
        // 显式访问 nowTick,触发每秒重绘
        let _ = model.nowTick
        Text(model.menuBarText())
    }
}
