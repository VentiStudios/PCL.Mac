//
//  ErrorTypes.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/29.
//

import Foundation

public enum InstallingError: LocalizedError {
    case minecraftInstallFailed(error: Error)
    case modLoaderInstallFailed(loader: ClientBrand, error: Error)
    case modpackInstallFailed(name: String, error: Error)
    case customFileDownloadFailed(name: String, error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .minecraftInstallFailed(let error):
            "无法安装 Minecraft: \(error.localizedDescription)"
        case .modLoaderInstallFailed(let loader, let error):
            "无法安装 \(loader.getName()): \(error.localizedDescription)"
        case .modpackInstallFailed(let name, let error):
            "无法安装整合包 \(name): \(error.localizedDescription)"
        case .customFileDownloadFailed(let name, let error):
            "下载自定义文件 \(name) 失败: \(error.localizedDescription)"
        }
    }
}

struct MyLocalizedError: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
