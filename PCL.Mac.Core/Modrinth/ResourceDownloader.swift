//
//  ResourceDownloader.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/6/19.
//

import SwiftUI
import SwiftyJSON

public class ResourceInstallTask: InstallTask {
    @Published public var state: InstallState = .waiting
    public let instance: MinecraftInstance
    private let versions: [ProjectVersion]
    private let totalFiles: Int
    
    init(instance: MinecraftInstance, versions: [ProjectVersion]) {
        self.instance = instance
        self.versions = versions
        self.totalFiles = versions.count
        super.init()
    }
    
    public override func startTask() async throws {
        setStage(.resources)
        self.remainingFiles = totalFiles
        let downloader = MultiFileDownloader(
            urls: versions.map { $0.downloadURL },
            destinations: versions.map { getDestinationDirectory($0).appending(path: $0.downloadURL.lastPathComponent) }
        ) { progress, finished in
            self.remainingFiles = self.totalFiles - finished
            self.currentStageProgress = progress
        }
        
        try await downloader.start()
    }
    
    private func getDestinationDirectory(_ version: ProjectVersion) -> URL {
        let base = instance.runningDirectory
        return switch version.projectType {
        case .mod: base.appending(path: "mods")
        case .resourcepack: base.appending(path: "resourcepacks")
        case .shader: base.appending(path: "shaderpacks")
        }
    }
    
    override func getStages() -> [InstallStage] {
        [.resources]
    }
    
    public override func getTitle() -> String { "资源下载" }
}

