//
//  AppDelegate.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/19.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: 注册字体
    private func registerCustomFonts() {
        guard let fontURL = Bundle.main.url(forResource: "PCL", withExtension: "ttf") else {
            err("Bundle 内未找到字体")
            return
        }

        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) == false {
            if let error = error?.takeUnretainedValue() {
                err("无法注册字体: \(error.localizedDescription)")
            } else {
                err("在注册字体时发生未知错误")
            }
        } else {
            log("成功注册字体")
        }
    }
    
    // MARK: 初始化 Java 列表
    private func initJavaList() {
        do {
            try JavaSearch.searchAndSet()
        } catch {
            err("无法初始化 Java 列表: \(error.localizedDescription)")
        }
    }
    
    private func checkOldPreferences() {
        let oldPreferencesURL = URL(fileURLWithUserPath: "~/Library/Preferences/io.github.pcl-communtiy.PCL-Mac.plist") // 原来这里的拼写一直是错的吗
        let newPreferencesURL = URL(fileURLWithUserPath: "~/Library/Preferences/org.ceciliastudio.PCL.Mac.plist")
        if FileManager.default.fileExists(atPath: oldPreferencesURL.path) {
            do {
                // 移动 Preferences
                try FileManager.default.removeItem(at: newPreferencesURL)
                try FileManager.default.moveItem(at: oldPreferencesURL, to: newPreferencesURL)
                
                // 重启 App
                let process = Process()
                process.executableURL = Bundle.main.bundleURL.appending(path: "Contents").appending(path: "MacOS").appending(path: "PCL.Mac")
                try? process.run()
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                err("无法导入旧设置")
            }
        }
    }
    
    // MARK: 初始化 App
    func applicationWillFinishLaunching(_ notification: Notification) {
        if !FileManager.default.fileExists(atPath: SharedConstants.shared.temperatureURL.path) {
            try? FileManager.default.createDirectory(at: SharedConstants.shared.temperatureURL, withIntermediateDirectories: true)
        }
        LogStore.shared.clear()
        let start = Date().timeIntervalSince1970
        log("App 已启动")
        checkOldPreferences()
        _ = AppSettings.shared
        registerCustomFonts()
        DataManager.shared.refreshVersionManifest()
        
        log("正在初始化 Java 列表")
        initJavaList()
        log("App 初始化完成, 耗时 \(Int((Date().timeIntervalSince1970 - start) * 1000))ms")
        
        let daemonProcess = Process()
        daemonProcess.executableURL = SharedConstants.shared.applicationResourcesURL.appending(path: "daemon")
        do {
            try daemonProcess.run()
            log("守护进程已启动")
        } catch {
            err("无法开启守护进程: \(error.localizedDescription)")
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppSettings.shared.showPclMacPopup {
            Task {
                if await PopupManager.shared.showAsync(
                    .init(.normal, "欢迎使用 PCL.Mac！", "本启动器是 Plain Craft Launcher（作者：龙腾猫跃）的非官方衍生版。\n若要反馈问题，请在 GitHub 上开 Issue。", [.init(label: "永久关闭", style: .normal), .close])
                ) == 0 {
                    AppSettings.shared.showPclMacPopup = false
                }
            }
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        LogStore.shared.save()
        Task {
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
