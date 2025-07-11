//
//  GitHubScene.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/11.
//

import SwiftUI

struct GitHubScene: View {
    @Binding var secondsSinceStart: Double
    
    @State private var images: [String] = ["PCL2-CE", "PCL.Nova.App", "PCL.Neo", "PCL2-Newer-Project", "PCL2-Python", "PCL.KMP"]
    @State private var appeared: Set<String> = []
    @State private var text: String = "让我们来看看 PCL-Community 社区制作的 PCL 衍生版"
    @State private var textOffset: CGFloat = -200
    @State private var textOpacity: Double = 0
    @State private var showVStack: Bool = true
    @State private var blackBackground: Bool = true
    @State private var rainbowText: Bool = false
    
    init(secondsSinceStart: Binding<Double>) {
        self._secondsSinceStart = secondsSinceStart
    }
    
    var body: some View {
        HStack {
            Text(text)
                .foregroundStyle(rainbowText ? Theme.colorful.getTextStyle() : .init(.white))
                .font(.system(size: 20))
                .offset(x: textOffset)
                .opacity(textOpacity)
                .padding(.leading)
                .frame(width: 500)
            if showVStack {
                VStack(spacing: 0) {
                    Text("\(secondsSinceStart)")
                    ForEach(0..<images.count, id: \.self) { index in
                        let image = images[index]
                        Image(image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 800)
                            .opacity(appeared.contains(image) ? 1 : 0)
                            .onAppear {
                                if !appeared.contains(image) {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                                        let item1 = image
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                            _ = appeared.insert(item1)
                                        }
                                    }
                                }
                            }
                    }
                    HStack {
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(blackBackground ? Color(hex: 0x0D1117) : .clear)
        .onAppear {
            DataManager.shared.brightness = 0
            withAnimation(.spring(duration: 1)) {
                textOffset = 0
                textOpacity = 1
            }
        }
        .onChange(of: secondsSinceStart) { new in
            if new >= 15 && new <= 15.1 {
                changeText("其中 PCL2-CE 不支持 macOS")
                unlit("PCL2-CE")
            }
            
            if new >= 18 && new <= 18.1 {
                changeText("PCL.KMP 和 PCL2-Python 几乎已停更")
                unlit("PCL.KMP")
                unlit("PCL2-Python")
            }
            
            if new >= 21 && new <= 21.1 {
                changeText("剩下的 3 个都在早期开发阶段\nNova 甚至做了个扫雷 + 2048（")
                unlit("PCL.Nova.App")
                unlit("PCL.Neo")
                unlit("PCL2-Newer-Project")
            }
            
            if new >= 24 && new <= 24.1 {
                self.images.removeAll()
                withAnimation(.spring(duration: 1)) {
                    showVStack = false
                }
                changeText("于是……")
            }
            
            if new >= 26 && new <= 26.1 {
                self.images.append("PCL.Mac")
                withAnimation(.spring(duration: 1)) {
                    showVStack = true
                }
                changeText("PCL.Mac 诞生了！", rainbow: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(.spring(duration: 1)) {
                        showVStack = false
                        blackBackground = false
                    }
                    changeText("")
                }
            }
        }
    }
    
    private func changeText(_ text: String, rainbow: Bool = false) {
        withAnimation(.spring(duration: 0.5)) {
            self.textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.text = text
            if rainbow {
                rainbowText = true
            }
            withAnimation(.spring(duration: 0.5)) {
                textOpacity = 1
            }
        }
    }
    
    private func unlit(_ name: String) {
        withAnimation(.spring(duration: 1)) {
            _ = self.appeared.remove(name)
        }
    }
}

#Preview {
    GitHubScene(secondsSinceStart: .constant(0))
        .frame(minWidth: 1000, minHeight: 1000)
}
