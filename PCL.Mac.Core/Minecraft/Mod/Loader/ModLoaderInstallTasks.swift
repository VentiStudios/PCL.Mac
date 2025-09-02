//
//  ModLoaderInstallTasks.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation

// MARK: - Fabric 安装任务定义
public class FabricInstallTask: InstallTask {
    private let instanceURL: URL
    private let loaderVersion: String
    
    public init(instanceURL: URL, loaderVersion: String) {
        self.instanceURL = instanceURL
        self.loaderVersion = loaderVersion
    }
    
    public override func startTask() async throws {
        let instance = try MinecraftInstance.create(instanceURL).unwrap("加载实例失败")
        try await FabricInstaller.installFabric(
            version: instance.version.unwrap(),
            minecraftDirectory: instance.minecraftDirectory,
            runningDirectory: instance.runningDirectory, self.loaderVersion
        )
        instance.loadManifest()
    }
    
    public override func getStages() -> [InstallStage] {
        [.installFabric]
    }
    
    public override func getTitle() -> String {
        "Fabric \(loaderVersion) 安装"
    }
    
    override func wrapError(error: any Error) -> any Error {
        InstallingError.modLoaderInstallFailed(loader: .fabric, error: error)
    }
}

public class ForgeInstallTask: InstallTask {
    private let instanceURL: URL
    private let loaderVersion: String
    private let isNeoforge: Bool
    
    public init(
        instanceURL: URL,
        loaderVersion: String,
        isNeoforge: Bool = false
    ) {
        self.instanceURL = instanceURL
        self.loaderVersion = loaderVersion
        self.isNeoforge = isNeoforge
    }
    
    public override func startTask() async throws {
        let instance = try MinecraftInstance.create(instanceURL).unwrap("加载实例失败")
        setStage(.installForge)
        let constructor: (MinecraftDirectory, URL, ClientManifest, ((Double) -> Void)?) -> ForgeInstaller = isNeoforge ? NeoforgeInstaller.init : ForgeInstaller.init
        let installer = constructor(instance.minecraftDirectory, instance.runningDirectory, instance.manifest, setProgress(_:))
        try await installer.install(minecraftVersion: instance.version, forgeVersion: loaderVersion)
    }
    
    public override func getStages() -> [InstallStage] {
        [isNeoforge ? .installNeoforge : .installForge]
    }
    
    public override func getTitle() -> String { "\(isNeoforge ? "Neo" : "")Forge \(loaderVersion) 安装" }
    
    override func wrapError(error: any Error) -> any Error {
        InstallingError.modLoaderInstallFailed(loader: isNeoforge ? .neoforge : .forge, error: error)
    }
}
