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
    
    init(secondsSinceStart: Binding<Double>) {
        self._secondsSinceStart = secondsSinceStart
    }
    
    var body: some View {
        HStack {
            Text(text)
                .foregroundStyle(.white)
                .font(.system(size: 20))
                .frame(width: 300)
                .padding()
                .opacity(textOpacity)
            Spacer()
        }
        .onChange(of: secondsSinceStart) { new in
            if new >= 31 && new <= 31.1 {
                changeText("如你所见，这就是 PCL.Mac 的主页面")
            }
            
            if new >= 33 && new <= 33.1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Task {
                        for i in 1...3 {
                            if i % 2 == 0 { NSApp.appearance = NSAppearance(named: .aqua) }
                            else { NSApp.appearance = NSAppearance(named: .darkAqua) }
                            try await Task.sleep(for: .seconds(0.5))
                        }
                    }
                }
                changeText("还有深色模式适配")
            }
            
            if new >= 36 && new <= 36.1 {
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
