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
            let installTasks = InstallTasks.empty()
            
            // 添加 Minecraft 安装任务
            let minecraftInstallTask = MinecraftInstaller.createTask(
                index.dependencies.minecraftVerison,
                index.name,
                minecraftDirectory
            )
            installTasks.addTask(key: "minecraft", task: minecraftInstallTask)
            
            // 添加整合包依赖的 Mod 加载器安装任务
            if index.dependencies.requiresFabric {
                try installTasks.addTask(key: "fabric", task: FabricInstallTask(instanceURL: instanceURL, loaderVersion: index.dependencies.fabricLoader.unwrap()))
            } else if index.dependencies.requiresQuilt {
                throw MyLocalizedError(reason: "不受支持的加载器: Quilt")
            } else if index.dependencies.requiresForge {
                try installTasks.addTask(key: "forge", task: ForgeInstallTask(instanceURL: instanceURL, loaderVersion: index.dependencies.forge.unwrap()))
            } else if index.dependencies.requiresNeoforge {
                try installTasks.addTask(key: "neoforge", task: ForgeInstallTask(instanceURL: instanceURL, loaderVersion: index.dependencies.neoforge.unwrap(), isNeoforge: true))
            }
            
            let modpackInstallTask = ModpackInstallTask(instanceURL: instanceURL, index: index, temp: temp)
            installTasks.addTask(key: "modpack", task: modpackInstallTask)
            
            return installTasks
        } catch {
            temp.free()
            throw error
        }
    }
    
    public static func checkModpack(_ url: URL) -> Result<Void, ModpackCheckError> {
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            return .failure(.zipFormatError)
        }
        if (!ArchiveUtil.hasEntry(archive: archive, name: "modrinth.index.json")) {
            return .failure(.unsupported)
        }
        
        return .success(())
    }
    
    public enum ModpackCheckError: Error {
        case zipFormatError, unsupported
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
    
    override func startTask() async throws {
        defer { temp.free() }
        setRemainingFiles(index.files.count)
        setStage(.modpackFilesDownload)
        try await MultiFileDownloader(
            task: self,
            urls: index.files.map { $0.downloadURL },
            destinations: index.files.map { instanceURL.appending(path: $0.path) },
            cacheStorage: CacheStorage.default
        ).start()
        
        setStage(.applyOverrides)
        let overridesURL = temp.getURL(path: "overrides")
        let files = try Util.getAllFiles(in: overridesURL)
        let step = 1.0 / Double(files.count)
        for url in files {
            let relative = url.pathComponents.dropFirst(overridesURL.pathComponents.count).joined(separator: "/")
            let dest = instanceURL.appending(path: relative)
            try? FileManager.default.createDirectory(at: dest.parent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: dest)
            log("\(relative) 拷贝完成")
            increaseProgress(step)
        }
        await MainActor.run {
            AppSettings.shared.defaultInstance = instanceURL.lastPathComponent
        }
    }
    
    override func getStages() -> [InstallStage] {
        [.modpackFilesDownload, .applyOverrides]
    }
    
    override func wrapError(error: any Error) -> any Error {
        InstallingError.modpackInstallFailed(name: index.name, error: error)
    }
}
