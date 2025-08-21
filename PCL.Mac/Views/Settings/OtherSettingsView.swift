//
//  OtherSettingsView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/6/21.
//

import SwiftUI

struct OtherSettingsView: View {
    @ObservedObject private var dataManager = DataManager.shared
    
    var body: some View {
        HStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack {
                    MyButton(text: "打开日志") {
                        NSWorkspace.shared.activateFileViewerSelecting([SharedConstants.shared.logURL])
                    }
                    .frame(height: 40)
                    .padding()
                    .padding(.bottom, -23)
                    
                    MyButton(text: "更新启动器") {
                        Task {
                            guard !SharedConstants.shared.isDevelopment else {
                                hint("你本地测试更新啥啊……", .critical)
                                return
                            }
                            if let update = await UpdateCheck.getLastUpdate() {
                                hint("当前最新版构建时间: \(SharedConstants.shared.dateFormatter.string(from: update.time))", .finish)
                                hint("正在下载并应用更新，启动器会在下载完后自动重启……")
                                await UpdateCheck.downloadUpdate(update)
                                UpdateCheck.applyUpdate()
                            } else {
                                hint("无法检查更新，请确保本 App 来源正确，且可以正常访问 GitHub！", .critical)
                            }
                        }
                    }
                    .frame(height: 40)
                    .padding()
                    .padding(.bottom, -23)
                }
                .scrollIndicators(.never)
            }
        }
    }
}
