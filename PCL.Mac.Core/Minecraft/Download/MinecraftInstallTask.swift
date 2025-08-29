//
//  MinecraftInstallTask.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation

public class NewMinecraftInstallTask: NewInstallTask {
    public var manifest: ClientManifest?
    public var assetIndex: AssetIndex?
    public var name: String
    public var versionURL: URL { minecraftDirectory.versionsURL.appending(path: name) }
    public let minecraftVersion: MinecraftVersion
    public let minecraftDirectory: MinecraftDirectory
    public let startInstall: (NewMinecraftInstallTask) async throws -> Void
    public let architecture: Architecture
    
    public init(
        minecraftVersion: MinecraftVersion,
        minecraftDirectory: MinecraftDirectory,
        name: String,
        architecture: Architecture = .system,
        startInstall: @escaping (NewMinecraftInstallTask) async throws -> Void
    ) {
        self.minecraftVersion = minecraftVersion
        self.minecraftDirectory = minecraftDirectory
        self.name = name
        self.startInstall = startInstall
        self.architecture = architecture
    }
    
    override func startTask() async throws {
        try await startInstall(self)
    }
    
    public override func getStages() -> [InstallStage] {
        [.clientJson, .clientIndex, .clientJar, .clientResources, .clientLibraries, .natives]
    }
    
    public override func getTitle() -> String {
        "\(minecraftVersion.displayName) 安装"
    }
}
