//
//  PCL_MacApp.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/17.
//

import SwiftUI

@main
struct PCL_MacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        _ = AppStartTracker.shared
    }
    
    var body: some Scene {
        WindowGroup {
            PreviewView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 PCL.Mac") {
                    DataManager.shared.router.setRoot(.others)
                    DataManager.shared.router.append(.about)
                }
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("设置") {
                    DataManager.shared.router.setRoot(.settings)
                    DataManager.shared.router.append(.personalization)
                }
            }
            
            CommandGroup(replacing: .newItem) { } // 修复 #21
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.toggleFullScreen(nil)
            }
        }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
