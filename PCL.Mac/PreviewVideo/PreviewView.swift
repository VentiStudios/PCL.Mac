//
//  PreviewView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/11.
//

import SwiftUI
import AVFoundation

struct PreviewOverlay: View {
    @Binding var secondsSinceStart: Double
    
    @State private var showText1: Bool = false // 你是否
    @State private var showText2: Bool = false // 在寻找
    @State private var showText3: Bool = false // 一款
    @State private var showText4: Bool = false // macOS 启动器
    @State private var showText5: Bool = false // HMCL 太卡？
    @State private var showText6: Bool = false // LauncherX 用不习惯？
    @State private var showText7: Bool = false // PCL 不支持？
    @State private var showText8: Bool = false // 吗？
    @State private var showText9: Bool = false // 官方版确实不支持，但 PCL-Community 社区制作了一些衍生版^
    
    init(secondsSinceStart: Binding<Double>) {
        self._secondsSinceStart = secondsSinceStart
    }
    
    var body: some View {
        VStack {
            if showText1 {
                HStack {
                    Text("你是否")
                        .opacity(showText1 ? 1 : 0)
                    Text("在寻找")
                        .opacity(showText2 ? 1 : 0)
                }
                .font(.system(size: 80))
                HStack {
                    Text("一款")
                        .opacity(showText3 ? 1 : 0)
                    Text("macOS Minecraft 启动器")
                        .opacity(showText4 ? 1 : 0)
                }
                .font(.system(size: 80))
            }
            if showText5 {
                HStack(spacing: 20) {
                    Text("HMCL 太卡？")
                        .opacity(showText5 ? 1 : 0)
                    Text("LauncherX 用不习惯？")
                        .opacity(showText6 ? 1 : 0)
                }
                .font(.system(size: 40))
                HStack {
                    Text("PCL 不支持……")
                        .opacity(showText7 ? 1 : 0)
                    Text("吗？")
                        .opacity(showText8 ? 1 : 0)
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                }
                .font(.system(size: 40))
            }
            if showText9 {
                Text("官方版确实不支持，但 PCL-Community 社区制作了一些衍生版……")
                    .opacity(showText9 ? 1 : 0)
                    .font(.system(size: 20))
            }
        }
        .onChange(of: secondsSinceStart) { new in
            withAnimation(.easeInOut(duration: 0.2)) {
                if new <= 5 {
                    if new >= 0.2 { showText1 = true }
                    if new >= 0.5 { showText2 = true }
                    if new >= 1.2 { showText3 = true }
                    if new >= 1.9 { showText4 = true }
                } else if new <= 11 {
                    showText1 = false;
                    if new >= 5.6 { showText5 = true }
                    if new >= 6.5 { showText6 = true }
                    if new >= 7.0 { showText7 = true }
                    if new >= 8.5 { showText8 = true }
                } else {
                    showText5 = false;
                    if new >= 10 { showText9 = true }
                }
                
                if new >= 13 && new <= 13.1 {
                    withAnimation(.linear(duration: 0.8)) {
                        DataManager.shared.brightness = -1
                    }
                }
            }
        }
    }
}

struct PreviewView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @StateObject private var playerVM = AudioPlayerViewModel()
    @State var secondsSinceStart: Double = -1
    
    var body: some View {
        ZStack {
            Spacer()
            if secondsSinceStart <= 14 {
                PreviewOverlay(secondsSinceStart: $secondsSinceStart)
                    .brightness(dataManager.brightness)
            } else if secondsSinceStart <= 32 {
                GitHubScene(secondsSinceStart: $secondsSinceStart)
                    .brightness(dataManager.brightness)
            } else {
                DemoScene(secondsSinceStart: $secondsSinceStart)
                    .brightness(dataManager.brightness)
            }
            
            if secondsSinceStart == -1 {
                Button("开始") {
                    secondsSinceStart = 0
                    Task {
                        try await Task.sleep(for: .seconds(2))
                        playerVM.play(url: URL(fileURLWithUserPath: "~/资源/creator.ogg"))
                        for _ in 1...550 {
                            try await Task.sleep(for: .seconds(0.1))
                            DispatchQueue.main.async {
                                self.secondsSinceStart += 0.1
                            }
                        }
                        playerVM.pause()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("Wallpaper")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .blur(radius: dataManager.blurRadius)
                .brightness(dataManager.brightness)
        )
        .onDisappear {
            playerVM.pause()
        }
        .background(WindowAccessor())
    }
}

class AudioPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    private var player: AVPlayer?

    func play(url: URL) {
        player = AVPlayer(url: url)
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }
}

#Preview {
    PreviewView()
        .frame(minWidth: 1000, minHeight: 1000)
}
