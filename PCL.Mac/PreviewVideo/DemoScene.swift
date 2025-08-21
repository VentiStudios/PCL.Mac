//
//  DemoScene.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/11.
//

import SwiftUI

struct DemoScene: View {
    @Binding var secondsSinceStart: Double
    
    @State private var text: String = ""
    @State private var textOpacity: Double = 0
    @State private var showShortcutImage: Bool = false
    @State private var showContentView: Bool = true
    @State private var showLogo: Bool = false
    
    init(secondsSinceStart: Binding<Double>) {
        self._secondsSinceStart = secondsSinceStart
    }
    
    var body: some View {
        ZStack {
            if showContentView {
                ContentView()
                    .cornerRadius(10)
                    .frame(width: 815, height: 465)
                    .onAppear {
                        NSApp.appearance = .init(named: .aqua)
                        AppSettings.shared.theme = .pcl
                        DataManager.shared.objectWillChange.send()
                    }
            }
            if showLogo {
                Image("PCLCommunity")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .brightness(-2)
            }
            HStack {
                VStack {
                    Text(text)
                        .foregroundStyle(.white)
                        .font(.system(size: 20))
                        .frame(width: showContentView ? 300 : 800)
                        .padding()
                        .opacity(textOpacity)
                    
                    if showShortcutImage {
                        Image("Shortcut")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 300)
                            .cornerRadius(10)
                    }
                }
                if showContentView {
                    Spacer()
                }
            }
        }
        .onChange(of: secondsSinceStart) {
            let new = secondsSinceStart
            if new >= 33 && new <= 33.1 {
                changeText("如你所见，这就是 PCL.Mac 的主页面")
            }
            
            if new >= 35 && new <= 35.1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task {
                        for i in 1...3 {
                            if i % 2 == 0 { NSApp.appearance = NSAppearance(named: .aqua) }
                            else { NSApp.appearance = NSAppearance(named: .darkAqua) }
                            try await Task.sleep(for: .seconds(0.8))
                        }
                    }
                }
                changeText("还有深色模式适配")
            }
            
            if new >= 38 && new <= 38.1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task {
                        for route in [AppRoute.download, AppRoute.settings, AppRoute.others, AppRoute.launch] {
                            DispatchQueue.main.async {
                                DataManager.shared.router.setRoot(route)
                            }
                            try await Task.sleep(for: .seconds(0.8))
                        }
                    }
                }
                changeText("几乎与原版一致的动画与体验")
            }
            
            if new >= 41 && new <= 41.1 {
                changeText("由于使用 Swift 编写，可以访问系统的大部分 API，所以甚至还可以用快捷指令启动 Minecraft！")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.spring(duration: 0.8)) {
                        showShortcutImage = true
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) {
                    withAnimation(.spring(duration: 0.8)) {
                        showShortcutImage = false
                    }
                }
            }
            
            if new >= 44 && new <= 44.1 {
                changeText("同时 App 大小仅 22 MB，启动器启动耗时 < 200 ms，且支持主题功能！")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation(.spring(duration: 1)) {
                        DataManager.shared.objectWillChange.send()
                    }
                }
            }
            
            if new >= 47 && new <= 47.1 {
                changeText("目前仅支持 Fabric 安装……")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(duration: 0.5)) {
                        DataManager.shared.router.setRoot(.download)
                        DataManager.shared.router.append(.minecraftDownload(showDownloadPage: true))
                    }
                }
            }
            
            if new >= 50 && new <= 50.1 {
                changeText("更多内容尽请期待……")
                withAnimation(.spring(duration: 1)) {
                    showContentView = false
                }
            }
            
            if new >= 52 && new <= 52.1 {
                changeText("10 月 1 日发布第一个正式版\n仓库地址: https://github.com/PCL-Community/PCL.Mac")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    changeText("")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    DataManager.shared.brightness = 1
                    DataManager.shared.blurRadius = 0
                    showLogo = true
                }
            }
        }
        .onAppear {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
    
    private func changeText(_ text: String) {
        withAnimation(.spring(duration: 0.5)) {
            self.textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.text = text
            withAnimation(.spring(duration: 0.5)) {
                textOpacity = 1
            }
        }
    }
}
