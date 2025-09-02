//
//  MinecraftInstallerNew.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/5/31.
//

/**
 *                             _ooOoo_
 *                            o8888888o
 *                            88" . "88
 *                            (| -_- |)
 *                            O\  =  /O
 *                         ____/`---'\____
 *                       .'  \\|     |//  `.
 *                      /  \\|||  :  |||//  \
 *                     /  _||||| -:- |||||-  \
 *                     |   | \\\  -  /// |   |
 *                     | \_|  ''\---/''  |   |
 *                     \  .-\__  `-`  ___/-. /
 *                   ___`. .'  /--.--\  `. . __
 *                ."" '<  `.___\_<|>_/___.'  >'"".
 *               | | :  `- \`.;`\ _ /`;.`/ - ` : | |
 *               \  \ `-.   \_ __\ /__ _/   .-` /  /
 *          ======`-.____`-.___\_____/___.-`____.-'======
 *                             `=---='
 *          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
*/

import Foundation
import SwiftyJSON

public class MinecraftInstaller {
    private init() {}
    
    // MARK: 下载客户端清单
    private static func downloadClientManifest(_ task: MinecraftInstallTask) async throws {
        task.setStage(.clientJson)
        let url = try DownloadSourceManager.shared.getClientManifestURL(task.version).unwrap("无法获取 \(task.version.displayName) 的 JSON 下载 URL。")
        let destination = task.instanceURL.appending(path: "\(task.name).json")
        
        try await SingleFileDownloader.download(task: task, url: url, destination: destination, replaceMethod: .replace)
        task.completeOneFile()
        
        if let manifest: ClientManifest = try .parse(url: destination, minecraftDirectory: nil) {
            task.manifest = manifest
        } else {
            let content = try String(data: FileHandle(forReadingFrom: destination).readToEnd().unwrap(), encoding: .utf8).unwrap()
            err("无法解析客户端清单: \(content)")
            throw MyLocalizedError(reason: "无法解析客户端清单：\(content)")
        }
    }
    
    // MARK: 下载客户端本体
    private static func downloadClientJar(_ task: MinecraftInstallTask) async throws {
        task.setStage(.clientJar)
        let url = try DownloadSourceManager.shared.getClientJARURL(task.version, task.manifest!).unwrap("无法获取 \(task.version.displayName) 的客户端下载 URL。")
        
        try await SingleFileDownloader.download(
            task: task,
            url: url,
            destination: task.instanceURL.appending(path: "\(task.name).jar")
        )
    }
    
    // MARK: 下载资源索引
    private static func downloadAssetIndex(_ task: MinecraftInstallTask) async throws {
        guard let manifest = task.manifest else {
            err("任务客户端清单为空值，停止下载资源索引")
            task.assetIndex = .init(objects: [])
            return
        }
        
        task.setStage(.clientIndex)
        
        let url: URL = try DownloadSourceManager.shared.getAssetIndexURL(task.version, manifest).unwrap("无法获取 \(task.version.displayName) 的 assetIndex 下载 URL。")
        let destination: URL = task.minecraftDirectory.assetsURL.appending(component: "indexes").appending(component: "\(manifest.assetIndex!.id).json")
        try await SingleFileDownloader.download(task: task, url: url, destination: destination)
        do {
            let data = try Data(contentsOf: destination)
            task.assetIndex = try .parse(data)
        } catch {
            err("在解析 JSON 时发生错误: \(error.localizedDescription)")
        }
    }
    
    // MARK: 下载散列资源文件
    private static func downloadHashResourcesFiles(_ task: MinecraftInstallTask) async throws {
        task.setStage(.clientResources)
        let objects = task.assetIndex!.objects
        
        var urls: [URL] = []
        var destinations: [URL] = []
        
        for object in objects {
            urls.append(object.appendTo(URL(string: "https://resources.download.minecraft.net")!))
            destinations.append(object.appendTo(task.minecraftDirectory.assetsURL.appending(path: "objects")))
        }
        
        try await MultiFileDownloader(task: task, urls: urls, destinations: destinations, concurrentLimit: 256).start()
    }
    
    // MARK: 下载依赖项
    private static func downloadLibraries(_ task: MinecraftInstallTask) async throws {
        task.setStage(.clientLibraries)
        
        var libraryNames: [String] = []
        var items: [DownloadItem] = []
        
        for library in try task.manifest.unwrap().getNeededLibraries() {
            if let artifact = library.artifact {
                let dest = task.minecraftDirectory.librariesURL.appending(path: artifact.path)
                if CacheStorage.default.copyLibrary(name: library.name, to: dest) {
                    continue
                }
                
                libraryNames.append(library.name)
                items.append(.init(DownloadSourceManager.shared.getDownloadSource(), { $0.getLibraryURL(library)! }, destination: dest))
            }
        }
        
        try await MultiFileDownloader(task: task, items: items).start()
        
        for library in task.manifest!.getNeededLibraries() {
            if libraryNames.contains(library.name) {
                CacheStorage.default.addLibrary(name: library.name, path: task.minecraftDirectory.librariesURL.appending(path: library.artifact!.path))
            }
        }
    }
    
    // MARK: 下载本地库
    private static func downloadNatives(_ task: MinecraftInstallTask) async throws {
        task.setStage(.natives)
        
        var libraryNames: [String] = []
        var items: [DownloadItem] = []
        
        for (library, artifact) in try task.manifest.unwrap().getNeededNatives() {
            let dest = task.minecraftDirectory.librariesURL.appending(path: artifact.path)
            if CacheStorage.default.copyLibrary(name: library.name, to: dest) {
                continue
            }
            
            libraryNames.append(library.name)
            items.append(.init(DownloadSourceManager.shared.getDownloadSource(), { $0.getLibraryURL(library)! }, destination: dest))
        }
        
        try? FileManager.default.createDirectory(at: task.instanceURL.appending(path: "natives"), withIntermediateDirectories: true)
        try await MultiFileDownloader(task: task, items: items).start()
        
        for (library, artifact) in task.manifest!.getNeededNatives() {
            if libraryNames.contains(library.name) {
                CacheStorage.default.addLibrary(name: library.name, path: task.minecraftDirectory.librariesURL.appending(path: artifact.path))
            }
        }
    }
    
    // MARK: 解压本地库
    private static func unzipNatives(_ task: MinecraftInstallTask) throws {
        let nativesURL: URL = task.instanceURL.appending(path: "natives")
        for (_, native) in task.manifest!.getNeededNatives() {
            let jarURL: URL = task.minecraftDirectory.librariesURL.appending(path: native.path)
            Util.unzip(archiveURL: jarURL, destination: nativesURL, replace: true)
            do {
                try processLibs(task, nativesURL)
            } catch {
                err("处理 natives 失败")
                throw error
            }
        }
    }
    
    // MARK: 处理解压结果
    private static func processLibs(_ task: MinecraftInstallTask, _ nativesURL: URL) throws {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: nativesURL, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "dylib" || fileURL.pathExtension == "jnilib",
                  let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]),
                  !resourceValues.isDirectory! else { continue }
            
            // 验证架构
            if fileURL.pathExtension == "dylib" {
                let arch = Architecture.getArchOfFile(fileURL)
                guard arch.isCompatiable(with: task.architecture) else {
                    try? fileManager.removeItem(at: fileURL)
                    log("已清除架构不匹配的可执行文件: \(fileURL.lastPathComponent)")
                    continue
                }
            }
            
            // 拷贝到 natives 根目录
            let destinationURL = nativesURL.appendingPathComponent(fileURL.lastPathComponent)
            if destinationURL == fileURL { continue }
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: fileURL, to: destinationURL)
        }
        
        // 清理非 dylib 文件
        let contents = try fileManager.contentsOfDirectory(at: nativesURL, includingPropertiesForKeys: nil)
        for fileURL in contents {
            if !fileURL.pathExtension.lowercased().hasSuffix("dylib") && !fileURL.pathExtension.lowercased().hasSuffix("jnilib") {
                try fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: 收尾
    private static func finalWork(_ task: MinecraftInstallTask) {
        let _1_12_2 = MinecraftVersion(displayName: "1.12.2")
        // 拷贝 log4j2.xml
        let targetURL: URL = task.instanceURL.appending(path: "log4j2.xml")
        try? FileManager.default.copyItem(
            at: SharedConstants.shared.applicationResourcesURL.appending(path: task.version >= _1_12_2 ? "log4j2.xml" : "log4j2-1.12-.xml"),
            to: targetURL
        )
        
        // 初始化实例
        let instance = MinecraftInstance.create(task.instanceURL, config: MinecraftConfig(version: task.version))
        
        instance?.saveConfig()
        
        // 修改 GLFW
        if let glfw = task.manifest!.getNeededLibraries().find({ $0.name.contains("lwjgl-glfw") }) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/java")
            process.environment = ProcessInfo.processInfo.environment
            process.currentDirectoryURL = URL(fileURLWithPath: "/tmp")
            process.arguments = ["-jar", SharedConstants.shared.applicationResourcesURL.appending(path: "glfw-patcher.jar").path, task.minecraftDirectory.librariesURL.appending(path: glfw.artifact!.path).path]
            do {
                try process.run()
                process.waitUntilExit()
                log("已修改 lwjgl-glfw")
            } catch {
                err("无法修改 lwjgl-glfw: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: 修改客户端清单中的 id
    private static func modifyId(_ task: MinecraftInstallTask) {
        do {
            let manifestURL = task.instanceURL.appending(path: "\(task.instanceURL.lastPathComponent).json")
            guard FileManager.default.fileExists(atPath: manifestURL.path),
                  let data = try FileHandle(forReadingFrom: manifestURL).readToEnd(),
                  var dict = try JSON(data: data).dictionaryObject else {
                return
            }
            
            dict["id"] = task.instanceURL.lastPathComponent
            
            try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted).write(to: manifestURL)
            log("已修改客户端清单中的 id")
        } catch {
            err("无法修改 id: \(error.localizedDescription)")
        }
    }
    
    // MARK: 获取进度
    public static func updateProgress(_ task: MinecraftInstallTask) {
        DispatchQueue.main.async {
            let totalFiles = 3 + task.assetIndex!.objects.count + task.manifest!.getNeededLibraries().count + task.manifest!.getNeededNatives().count
            log("总文件数: \(totalFiles)")
            task.remainingFiles = totalFiles - 2
        }
    }
    
    // MARK: 创建任务
    public static func createTask(_ minecraftVersion: MinecraftVersion, _ name: String, _ minecraftDirectory: MinecraftDirectory, _ callback: (() -> Void)? = nil) -> InstallTask {
        let task = MinecraftInstallTask(version: minecraftVersion, minecraftDirectory: minecraftDirectory, name: name) { task in
            try await downloadClientManifest(task)
            try await downloadAssetIndex(task)
            updateProgress(task)
            try await downloadClientJar(task)
            modifyId(task)
            try await downloadHashResourcesFiles(task)
            try await downloadLibraries(task)
            try await downloadNatives(task)
            try unzipNatives(task)
            finalWork(task)
            callback?()
        }
        return task
    }
    
    // MARK: 创建补全资源任务
    public static func createCompleteTask(_ instance: MinecraftInstance) -> InstallTask {
        let arch: Architecture
        if Architecture.system == .x64 { arch = .x64 }
        else { arch = instance.isUsingRosetta ? .x64 : .arm64 }
        let task = MinecraftInstallTask(
            version: instance.version!,
            minecraftDirectory: instance.minecraftDirectory,
            name: instance.name,
            architecture: arch
        ) { task in
            task.manifest = instance.manifest
            try await downloadAssetIndex(task)
            try await downloadClientJar(task)
            try await downloadHashResourcesFiles(task)
            try await downloadLibraries(task)
            try await downloadNatives(task)
            try unzipNatives(task)
            finalWork(task)
        }
        return task
    }
}
