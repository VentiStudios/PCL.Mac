//
//  LaunchPrecheck.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/20.
//

import Foundation
import AppKit

public enum LaunchPrecheckError: Error {
    case invalidMemoryConfiguration
    case missingAccount
    case javaNotFound
    case noUsableJava(minVersion: Int)
    case noMicrosoftAccount
    case cancelled
}

public class LaunchPrecheck {
    public static func check(_ instance: MinecraftInstance, _ options: LaunchOptions) -> Result<Void, LaunchPrecheckError> {
        if instance.process != nil {
            warn("[launchPrecheck] 有进程正在运行，终止启动")
            return .failure(.cancelled)
        }
        
        log("[launchPrecheck] 正在进行 Java 检查")
        let suitableJava = MinecraftInstance.findSuitableJava(instance.version)
        if DataManager.shared.javaVirtualMachines
            .filter({ $0.executableUrl.path != "/usr/bin/java" })
            .count == 0 {
            err("[launchPrecheck] 用户未安装 Java")
            
            return .failure(.javaNotFound)
        } else if suitableJava == nil {
            let minVersion = MinecraftInstance.getMinJavaVersion(instance.version)
            err("[launchPrecheck] 无可用 Java。最低版本: \(minVersion)")
            
            return .failure(.noUsableJava(minVersion: minVersion))
        }
        if instance.config.javaPath == nil { instance.config.javaPath = suitableJava!.executableUrl.path }
        
        if instance.config.maxMemory == 0 {
            return .failure(.invalidMemoryConfiguration)
        }
        
        if !AppSettings.shared.hasMicrosoftAccount {
            debug("[launchPrecheck] 未登录过正版账号")
            
            return .failure(.noMicrosoftAccount)
        }
        
        guard let account = AccountManager.shared.getAccount() else {
            err("无法启动 Minecraft: 未设置账号")
            
            return .failure(.missingAccount)
        }
        options.account = account
        
        return .success(())
    }
}
