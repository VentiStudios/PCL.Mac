//
//  InstallingView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/29.
//

import SwiftUI

struct InstallingView: View {
    private struct LeftTabView: View {
        @ObservedObject private var dataManager: DataManager = .shared
        @ObservedObject private(set) var tasks: InstallTasks
        @ObservedObject private var speedMeter: SpeedMeter = .shared
        
        var body: some View {
            VStack {
                Spacer()
                PanelView(
                    title: "总进度",
                    value: String(format: "%.1f %%", tasks.getProgress() * 100)
                )
                PanelView(
                    title: "下载速度",
                    value: "\(formatSpeed(speedMeter.downloadSpeed))"
                )
                PanelView(
                    title: "剩余文件",
                    value: tasks.remainingFiles < 0 ? "-" : String(describing: tasks.remainingFiles)
                )
                Spacer()
            }
            .padding()
            .padding(.top, 10)
        }
        
        func formatSpeed(_ speed: Int64) -> String {
            let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
            var value: Double = Double(speed)
            var unitIndex = 0

            while value >= 1024 && unitIndex < units.count - 1 {
                value /= 1024
                unitIndex += 1
            }

            let formatted = String(format: value < 10 && unitIndex > 0 ? "%.1f" : "%.0f", value)
            return "\(formatted) \(units[unitIndex])"
        }
    }
    
    @ObservedObject private var dataManager: DataManager = DataManager.shared
    @ObservedObject var tasks: InstallTasks
    
    var body: some View {
        HStack {
            VStack {
                ForEach(tasks.getTasks()) { task in
                    StaticMyCard(title: task.getTitle()) {
                        getEntries(task)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            dataManager.leftTab(220) {
                LeftTabView(tasks: tasks)
            }
        }
    }
    
    private func getEntries(_ task: InstallTask) -> some View {
        return VStack {
            ForEach(Array(task.getInstallStates()).sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { stage, state in
                HStack {
                    if state == .inprogress {
                        Text(String(format: "%.0f%%", task.currentStageProgress * 100))
                            .font(.custom("PCL English", size: 14))
                            .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                            .padding(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 10))
                    } else {
                        Image(state.getImageName())
                            .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                            .padding(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 10))
                    }
                    Text(stage.getDisplayName())
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                    Spacer()
                }
                .frame(height: 20)
            }
        }
    }
}

private struct PanelView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.custom("PCL English", size: 16))
                .foregroundStyle(AppSettings.shared.theme.getTextStyle())
            Rectangle()
                .fill(AppSettings.shared.theme.getTextStyle())
                .frame(width: 180, height: 2)
            Text(value)
                .font(.custom("PCL English", size: 20))
                .foregroundStyle(Color("TextColor"))
        }
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
}
