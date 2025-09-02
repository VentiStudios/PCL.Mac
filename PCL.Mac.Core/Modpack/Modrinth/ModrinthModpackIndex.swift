//
//  ModrinthModpackIndex.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/26.
//

import Foundation
import SwiftyJSON

public struct ModpackFile {
    public let path: String
    public let downloadURL: URL
    public let isSupportedOnClient: Bool
    
    public init?(json: JSON) {
        do {
            if json["path"].stringValue.contains("..") { throw MyLocalizedError(reason: "路径不安全: \(json["path"].stringValue)") }
            self.path = json["path"].stringValue
            self.downloadURL = try json["downloads"].arrayValue.first.unwrap("下载项不存在。").url.unwrap("下载 URL 格式错误。")
            self.isSupportedOnClient = json["env"]["client"].stringValue != "unsupported"
        } catch {
            err("无法解析整合包文件: \(error.localizedDescription)")
            return nil
        }
    }
}

public struct ModpackDependencies {
    public let minecraft: String
    public let fabricLoader: String?
    public let quiltLoader: String?
    public let forge: String?
    public let neoforge: String?
    
    public init(json: JSON) {
        self.minecraft = json["minecraft"].stringValue
        self.fabricLoader = json["fabric-loader"].string
        self.quiltLoader = json["quilt-loader"].string
        self.forge = json["forge"].string
        self.neoforge = json["neoforge"].string
    }
    
    public var requiresFabric: Bool { self.fabricLoader != nil }
    public var requiresQuilt: Bool { self.quiltLoader != nil }
    public var requiresForge: Bool { self.forge != nil }
    public var requiresNeoforge: Bool { self.neoforge != nil }
    
    public var minecraftVerison: MinecraftVersion { .init(displayName: minecraft) }
}

public class ModrinthModpackIndex {
    public let name: String
    public let summary: String?
    public let version: String
    public let files: [ModpackFile]
    public let dependencies: ModpackDependencies
    
    public init(json: JSON) {
        self.name = json["name"].stringValue
        self.summary = json["summary"].string
        self.version = json["versionId"].stringValue
        self.files = json["files"].arrayValue.compactMap(ModpackFile.init(json:)).filter { $0.isSupportedOnClient }
        self.dependencies = .init(json: json["dependencies"])
    }
}
