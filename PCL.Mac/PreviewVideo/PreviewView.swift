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
    @State private var showText6: Bool = false // LauncherX 不习惯？
    @State private var showText7: Bool = false // PCL 不支持？
    @State private var showText8: Bool = false // 吗？
    
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
                .font(.system(size: 100))
                HStack {
                    Text("一款")
                        .opacity(showText3 ? 1 : 0)
                    Text("macOS 启动器")
                        .opacity(showText4 ? 1 : 0)
                        .foregroundStyle(Theme.colorful.getStyle())
                }
                .font(.system(size: 100))
            }
            if showText5 {
                HStack(spacing: 20) {
                    Text("HMCL 太卡？")
                        .opacity(showText5 ? 1 : 0)
                    Text("LauncherX 不习惯？")
                        .opacity(showText6 ? 1 : 0)
                }
                .font(.system(size: 60))
                HStack {
                    Text("PCL 不支持？")
                        .opacity(showText7 ? 1 : 0)
                    Text("吗？")
                        .opacity(showText8 ? 1 : 0)
                        .foregroundStyle(.red)
                }
                .font(.system(size: 60))
            }
            
            Text("\(secondsSinceStart)")
                .onChange(of: secondsSinceStart) { new in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if new <= 5 {
                            if new >= 0.2 { showText1 = true }
                            if new >= 0.5 { showText2 = true }
                            if new >= 1.2 { showText3 = true }
                            if new >= 1.9 { showText4 = true }
                        } else {
                            showText1 = false; showText2 = false; showText3 = false; showText4 = false
                            if new >= 5.6 { showText5 = true }
                            if new >= 6.5 { showText6 = true }
                            if new >= 7.0 { showText7 = true }
                            if new >= 9.0 {  showText8 = true }
                        }
                        
                        if new >= 11 && new <= 11.1 {
                            withAnimation(.linear(duration: 0.8)) {
                                DataManager.shared.brightness = -1
                            }
                        }
                    }
                }
        }
    }
}

struct PreviewView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @StateObject private var playerVM = AudioPlayerViewModel()
    @State var secondsSinceStart: Double = 30
    @State var showContentView: Bool = false
    
    var body: some View {
        ZStack {
            Spacer()
            if secondsSinceStart >= 28 {
                ContentView()
                    .cornerRadius(10)
                    .frame(width: 815, height: 465)
                    .opacity(showContentView ? 1 : 0)
            }
            
            if secondsSinceStart <= 12 {
                PreviewOverlay(secondsSinceStart: $secondsSinceStart)
            } else if secondsSinceStart <= 30 {
                GitHubScene(secondsSinceStart: $secondsSinceStart)
            } else {
                DemoScene(secondsSinceStart: $secondsSinceStart)
            }
            
            if secondsSinceStart == 30 {
                Button("开始") {
                    playerVM.play(url: URL(fileURLWithUserPath: "~/资源/creator.ogg"))
                    Task {
                        for _ in 1...300 {
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
        )
        .brightness(dataManager.brightness)
        .onChange(of: secondsSinceStart) { new in
            if new >= 2 {
                withAnimation(.spring(duration: 0.5)) {
                    self.showContentView = true
                }
            }
        }
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
