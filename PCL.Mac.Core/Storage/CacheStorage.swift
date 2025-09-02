//
//  CacheStorage.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/10.
//

import Foundation
import SwiftyJSON

/// 用于缓存下载项
public class CacheStorage {
    public static let `default`: CacheStorage = .init(rootURL: .applicationSupportDirectory.appending(path: "minecraft").appending(path: "cache"))
    
    private let rootURL: URL
    private var libraries: [Library]
    private var eTag: [ETag]
    
    // MARK: - 加载与保存
    public init(rootURL: URL) {
        self.rootURL = rootURL
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        
        self.libraries = Self.parseElements(from: rootURL.appending(path: "index.json"), field: "libraries", using: Library.init(_:))
        self.eTag = Self.parseElements(from: rootURL.appending(path: "etag.json"), field: "eTag", using: ETag.init(_:))
    }
    
    public func save() {
        Self.saveElements(libraries, field: "libraries", to: rootURL.appending(path: "index.json"))
        Self.saveElements(eTag, field: "eTag", to: rootURL.appending(path: "etag.json"))
    }
    
    /// 获取缓存文件存储位置
    /// - Parameter hash: 文件的 SHA-1 哈希值
    /// - Returns: 缓存文件存储位置
    public func getCachePath(_ hash: String) -> URL {
        rootURL
            .appending(path: "SHA-1")
            .appending(path: String(hash.prefix(2)))
            .appending(path: hash)
    }
    
    // MARK: - 依赖项缓存
    
    /// 添加一个依赖项到缓存
    /// - Parameters:
    ///   - name: 依赖项的 Maven 坐标（如 "com.example:library:1.2.3"）
    ///   - path: 依赖项文件在本地的 URL 路径
    public func addLibrary(name: String, path: URL) {
        if libraries.contains(where: { $0.name == name }) {
            return
        }
        
        let hash: String
        do {
            hash = try Util.sha1OfFile(url: path)
        } catch {
            err("无法获取 SHA-1: \(error.localizedDescription)")
            return
        }
        let dest = getCachePath(hash)
        if FileManager.default.fileExists(atPath: dest.path) { return }
        
        do {
            try? FileManager.default.createDirectory(at: dest.parent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: path, to: dest)
            save()
        } catch {
            err("无法复制文件: \(error.localizedDescription)")
            return
        }
        
        libraries.append(.init(name: name, hash: hash, type: "jar"))
    }
    
    /// 尝试使用缓存中的依赖项
    /// - Parameters:
    ///   - name: 依赖项的 Maven 坐标（如 "com.example:library:1.2.3"）
    ///   - dest: 目标文件的 URL，拷贝依赖项到此位置
    /// - Returns: 如果缓存中存在并成功拷贝，返回 true；否则返回 false
    public func copyLibrary(name: String, to destination: URL) -> Bool {
        if FileManager.default.fileExists(atPath: destination.path) {
            return true
        }
        if let library = libraries.first(where: { $0.name == name }) {
            let path = getCachePath(library.hash)
            
            guard FileManager.default.fileExists(atPath: path.path) else {
                return false
            }
            
            do {
                try? FileManager.default.createDirectory(at: destination.parent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: path, to: destination)
                debug("成功拷贝文件: \(name)")
                return true
            } catch {
                err("无法拷贝文件: \(error.localizedDescription)")
            }
        }
        return false
    }
    
    // MARK: - 下载项缓存
    
    /// 将一个普通文件添加到缓存
    /// - Parameters:
    ///   - url: 文件的下载 URL
    ///   - localURL: 文件在本地的存储位置（URL 类型）
    ///   - eTag: 响应头中的 ETag 字段（通过 HTTPURLResponse.value(forHTTPHeaderField: "ETag") 获取）
    ///   - lastModified: 响应头中的 Last-Modified 字段
    public func addFile(from url: URL, localURL: URL, eTag: String, lastModified: String) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: localURL.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else {
                err("无法获取文件上次修改时间")
                return
            }
            
            let hash = try Util.sha1OfFile(url: localURL)
            try FileManager.default.copyItem(at: localURL, to: getCachePath(hash))
            self.eTag.append(
                ETag(
                    url: url.absoluteString,
                    eTag: eTag,
                    hash: hash,
                    local: Int64(modificationDate.timeIntervalSince1970 * 1000),
                    remote: lastModified
                )
            )
        } catch {
            err("无法将 \(localURL.lastPathComponent) 添加至 CacheStorage: \(error.localizedDescription)")
        }
    }
    
    public func copyFile(url: URL, to destination: URL) -> Bool {
        if FileManager.default.fileExists(atPath: destination.path) {
            return true
        }
        if let file = eTag.find({ $0.url == url.absoluteString }) {
            let path = getCachePath(file.hash)
            
            guard FileManager.default.fileExists(atPath: path.path) else {
                return false
            }
            
            do {
                try? FileManager.default.createDirectory(at: destination.parent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: path, to: destination)
                return true
            } catch {
                err("无法拷贝文件: \(error.localizedDescription)")
            }
        }
        return false
    }
    
    private struct Library: Codable {
        public let name: String
        public let hash: String
        public let type: String
        
        init(name: String, hash: String, type: String) {
            self.name = name
            self.hash = hash
            self.type = type
        }
        
        init(_ json: JSON) {
            self.name = json["name"].stringValue
            self.hash = json["hash"].stringValue
            self.type = json["type"].stringValue
        }
    }
    
    private struct ETag: Codable {
        public let url: String
        public let eTag: String
        public let hash: String
        public let local: Int64
        public let remote: String
        
        init(url: String, eTag: String, hash: String, local: Int64, remote: String) {
            self.url = url
            self.eTag = eTag
            self.hash = hash
            self.local = local
            self.remote = remote
        }
        
        init(_ json: JSON) {
            self.url = json["url"].stringValue
            self.eTag = json["eTag"].stringValue
            self.hash = json["hash"].stringValue
            self.local = json["local"].int64Value
            self.remote = json["remote"].stringValue
        }
    }
    
    private static func parseElements<T>(from url: URL, field: String, using parser: (JSON) -> T) -> [T] {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let json = try JSON(data: data)
                return json[field].arrayValue.map(parser)
            } catch {
                err("无法读取 \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return []
    }
    
    private static func saveElements<T: Codable>(_ elements: [T], field: String, to destination: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            try encoder.encode([field: elements]).write(to: destination)
        } catch {
            err("无法保存 \(field): \(error.localizedDescription)")
        }
    }
}
