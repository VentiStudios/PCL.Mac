//
//  ModLoaderInstallTasks.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation

// MARK: - Fabric 安装任务定义
public class FabricInstallTask: NewInstallTask {
    @Published private var state: InstallState
    private let loaderVersion: String
    
    init(loaderVersion: String) {
        self.state = .waiting
        self.loaderVersion = loaderVersion
    }
    
    public func install(_ task: NewMinecraftInstallTask) async {
        await MainActor.run {
            state = .inprogress
        }
        do {
            let manifestURL = task.versionURL.appending(path: "\(task.name).json")
            try await FabricInstaller.installFabric(version: task.minecraftVersion, minecraftDirectory: task.minecraftDirectory, runningDirectory: task.versionURL, self.loaderVersion)
            task.manifest = try ClientManifest.parse(url: manifestURL, minecraftDirectory: task.minecraftDirectory)
        } catch {
            await PopupManager.shared.show(.init(.error, "无法安装 Fabric", "\(error.localizedDescription)\n若要反馈此问题，你可以进入设置 > 其它 > 打开日志，将选中的文件发给别人。", [.ok]))
            err("无法安装 Fabric: \(error.localizedDescription)")
        }
        await MainActor.run {
            state = .finished
        }
    }
    
    public override func getStages() -> [InstallStage] {
        [.installFabric]
    }
    
    public override func getTitle() -> String {
        "Fabric \(loaderVersion) 安装"
    }
}

public class ForgeInstallTask: NewInstallTask {
    @Published private var state: InstallState
    private let minecraftVersion: MinecraftVersion
    private let forgeVersion: String
    private let minecraftDirectory: MinecraftDirectory
    private let instanceURL: URL
    private let manifest: ClientManifest
    
    public init(
        minecraftVersion: MinecraftVersion,
        forgeVersion: String,
        minecraftDirectory: MinecraftDirectory,
        instanceURL: URL,
        manifest: ClientManifest
    ) {
        self.state = .waiting
        self.minecraftVersion = minecraftVersion
        self.forgeVersion = forgeVersion
        self.minecraftDirectory = minecraftDirectory
        self.instanceURL = instanceURL
        self.manifest = manifest
    }
    
    public convenience init(task: MinecraftInstallTask, forgeVersion: String) {
        self.init(
            minecraftVersion: task.minecraftVersion,
            forgeVersion: forgeVersion,
            minecraftDirectory: task.minecraftDirectory,
            instanceURL: task.versionURL,
            manifest: task.manifest!
        )
    }
    
    public override func startTask() async throws {
        updateStage(.installForge)
        do {
            let installer = ForgeInstaller(minecraftDirectory, instanceURL, manifest) { progress in
                self.setProgress(progress)
            }
            try await installer.install(minecraftVersion: minecraftVersion, forgeVersion: forgeVersion)
            log("Forge 安装完成")
        } catch {
            throw MyLocalizedError(reason: "无法安装 Forge：\(error.localizedDescription)")
        }
        complete()
    }
    
    public override func getStages() -> [InstallStage] {
        [.installForge]
    }
    
    public override func getTitle() -> String { "Forge \(forgeVersion) 安装" }
}

public class NeoforgeInstallTask: InstallTask {
    @Published private var state: InstallState
    private let neoforgeVersion: String
    
    init(neoforgeVersion: String) {
        self.state = .waiting
        self.neoforgeVersion = neoforgeVersion
    }
    
    public func install(_ task: NewMinecraftInstallTask) async {
        await MainActor.run {
            state = .inprogress
        }
        do {
            let installer = NeoforgeInstaller(task.minecraftDirectory, task.versionURL, task.manifest!) { progress in
                self.currentStagePercentage = progress
            }
            try await installer.install(minecraftVersion: task.minecraftVersion, forgeVersion: neoforgeVersion)
            log("NeoForge 安装完成")
        } catch {
            await PopupManager.shared.show(.init(.error, "无法安装 NeoForge", "\(error.localizedDescription)\n若要反馈此问题，你可以进入设置 > 其它 > 打开日志，将选中的文件发给别人。", [.ok]))
            err("无法安装 NeoForge: \(error.localizedDescription)")
        }
        await MainActor.run {
            state = .finished
        }
    }
    
    public override func getInstallStates() -> [InstallStage : InstallState] { [.installNeoforge : state] }
    public override func getTitle() -> String { "NeoForge \(neoforgeVersion) 安装" }
}
