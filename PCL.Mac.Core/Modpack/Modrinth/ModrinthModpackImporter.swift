//
//  ModrinthModpackImporter.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/26.
//

import Foundation
import ZIPFoundation
import SwiftyJSON

public class ModrinthModpackImporter {
    private let minecraftDirectory: MinecraftDirectory
    private let modpackURL: URL
    
    public init(minecraftDirectory: MinecraftDirectory, modpackURL: URL) {
        self.minecraftDirectory = minecraftDirectory
        self.modpackURL = modpackURL
    }
    
    public func createInstallTasks() throws -> InstallTasks {
        let temp = TemperatureDirectory(name: "ModpackImport")
        do {
            // 解压整合包
            try FileManager.default.unzipItem(at: modpackURL, to: temp.root)
            log("整合包解压完成")
            
            // 解析 Modrinth 整合包索引
            let data = try FileHandle(forReadingFrom: temp.getURL(path: "modrinth.index.json")).readToEnd().unwrap()
            let json = try JSON(data: data)
            let index = ModrinthModpackIndex(json: json)
            log("已解析 \(index.name) 的 modrinth.index.json")
            log("Minecraft 版本: \(index.dependencies.minecraft)")
            if let fabricLoaderVersion = index.dependencies.fabricLoader { log("Fabric 版本: \(fabricLoaderVersion)") }
            if let quiltLoaderVersion = index.dependencies.quiltLoader { log("Quilt 版本: \(quiltLoaderVersion)") }
            if let forgeVersion = index.dependencies.forge { log("Forge 版本: \(forgeVersion)") }
            if let neoforgeVersion = index.dependencies.neoforge { log("NeoForge 版本: \(neoforgeVersion)") }
            
            let instanceURL = minecraftDirectory.versionsURL.appending(path: index.name)
            if FileManager.default.fileExists(atPath: instanceURL.path) {
                log("实例已存在，停止安装")
                throw MyLocalizedError(reason: "已存在与整合包同名的实例！")
            } else {
                try? FileManager.default.createDirectory(at: instanceURL, withIntermediateDirectories: true)
            }
            let installTasks = InstallTasks([:])
            
            // 添加 Minecraft 安装任务
            let minecraftInstallTask = MinecraftInstaller.createTask(
                index.dependencies.minecraftVerison,
                index.name,
                minecraftDirectory
            )
            installTasks.addTask(key: "minecraft", task: minecraftInstallTask)
            
            // 添加整合包依赖的 Mod 加载器安装任务
            if index.dependencies.requiresFabric {
                try installTasks.addTask(key: "fabric", task: FabricInstallTask(loaderVersion: index.dependencies.fabricLoader.unwrap()))
            } else if index.dependencies.requiresQuilt {
                throw MyLocalizedError(reason: "不受支持的加载器: Quilt")
            } else if index.dependencies.requiresForge {
                try installTasks.addTask(key: "forge", task: ForgeInstallTask(forgeVersion: index.dependencies.forge.unwrap()))
            } else if index.dependencies.requiresNeoforge {
                try installTasks.addTask(key: "neoforge", task: NeoforgeInstallTask(neoforgeVersion: index.dependencies.neoforge.unwrap()))
            }
            
            let modpackInstallTask = ModpackInstallTask(instanceURL: instanceURL, index: index, temp: temp)
            installTasks.addTask(key: "modpack", task: modpackInstallTask)
            minecraftInstallTask.onComplete {
                modpackInstallTask.start()
            }
            
            DataManager.shared.inprogressInstallTasks = installTasks
            return installTasks
        } catch {
            temp.free()
            throw error
        }
    }
}

private class ModpackInstallTask: InstallTask {
    private let instanceURL: URL
    private let index: ModrinthModpackIndex
    private let temp: TemperatureDirectory
    
    fileprivate init(instanceURL: URL, index: ModrinthModpackIndex, temp: TemperatureDirectory) {
        self.instanceURL = instanceURL
        self.index = index
        self.temp = temp
    }
    
    override func getTitle() -> String { "Modrinth 整合包安装：\(index.name)" }
    
    override func start() {
        Task {
            do {
                updateStage(.modpackFilesDownload)
                try await MultiFileDownloader(
                    urls: index.files.map { $0.downloadURL },
                    destinations: index.files.map { instanceURL.appending(path: $0.path )}
                ).start()
                
                updateStage(.applyOverrides)
                let overridesURL = temp.getURL(path: "overrides")
                let files = try FileManager.default.contentsOfDirectory(at: temp.getURL(path: "overrides"), includingPropertiesForKeys: nil)
                
                for url in files {
                    let relative = url.pathComponents.dropFirst(overridesURL.pathComponents.count).joined(separator: "/")
                    let dest = overridesURL.appending(path: relative)
                    try? FileManager.default.createDirectory(at: dest.parent(), withIntermediateDirectories: true)
                    try? FileManager.default.copyItem(at: dest, to: instanceURL.appending(path: relative))
                    log("\(relative) 拷贝完成")
                }
                complete()
            } catch {
                err("无法安装整合包: \(error.localizedDescription)")
                await PopupManager.shared.show(.init(.error, "无法安装整合包", "\(error.localizedDescription)\n若要反馈此问题，你可以进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送本页面的照片或截图。", [.ok]))
                await MainActor.run {
                    currentState = .failed
                    DataManager.shared.inprogressInstallTasks = nil
                }
            }
            temp.free()
        }
    }
}
