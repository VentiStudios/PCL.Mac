//
//  MinecraftInstallTask.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation

public class MinecraftInstallTask: InstallTask {
    public var manifest: ClientManifest?
    public var assetIndex: AssetIndex?
    public var name: String
    public var instanceURL: URL { minecraftDirectory.versionsURL.appending(path: name) }
    public let version: MinecraftVersion
    public let minecraftDirectory: MinecraftDirectory
    public let startInstall: (MinecraftInstallTask) async throws -> Void
    public let architecture: Architecture
    
    public init(
        version: MinecraftVersion,
        minecraftDirectory: MinecraftDirectory,
        name: String,
        architecture: Architecture = .system,
        startInstall: @escaping (MinecraftInstallTask) async throws -> Void
    ) {
        self.version = version
        self.minecraftDirectory = minecraftDirectory
        self.name = name
        self.startInstall = startInstall
        self.architecture = architecture
    }
    
    public override func startTask() async throws {
        do {
            try await startInstall(self)
        } catch {
            try? FileManager.default.removeItem(at: instanceURL)
            throw InstallingError.minecraftInstallFailed(error: error)
            //            await PopupManager.shared.show(.init(.error, "无法安装 Minecraft", "\(error.localizedDescription)\n若要反馈此问题，你可以进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送本页面的照片或截图。", [.ok]))
            //            await MainActor.run {
            //                currentStageState = .failed
            //                DataManager.shared.inprogressInstallTasks = nil
            //            }
        }
    }
    
    override func getStages() -> [InstallStage] {
        [.clientJson, .clientIndex, .clientJar, .clientResources, .clientLibraries, .natives]
    }
    
    public override func getTitle() -> String {
        "\(version.displayName) 安装"
    }
}
