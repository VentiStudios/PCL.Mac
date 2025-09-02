//
//  TemperatureManager.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/1.
//

import Foundation

public class TemperatureDirectory {
    public var root: URL { SharedConstants.shared.temperatureURL.appending(path: name) }
    private let name: String
    
    public init(name: String) {
        self.name = name
        if FileManager.default.fileExists(atPath: root.path) {
            warn("\(name) 对应的 URL 已被占用")
            free()
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    
    @discardableResult
    public func createFile(path: String, data: Data? = nil) -> URL? {
        let path = root.appending(path: path)
        try? FileManager.default.createDirectory(at: path.parent(), withIntermediateDirectories: true)
        if FileManager.default.createFile(atPath: path.path, contents: data) {
            return path
        } else {
            return nil
        }
    }
    
    public func getURL(path: String) -> URL { root.appending(path: path) }
    
    public func free() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: []
            )
            for itemURL in contents {
                try FileManager.default.removeItem(at: itemURL)
            }
            try? FileManager.default.removeItem(at: root)
        } catch {
            err("在释放 \(name) 时发生错误: \(error)")
        }
    }
}
