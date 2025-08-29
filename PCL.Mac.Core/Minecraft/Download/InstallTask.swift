//
//  InstallTask.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/7.
//

import Foundation
import Combine

public class InstallTask: ObservableObject, Identifiable, Hashable, Equatable {
    @Published public var stage: InstallStage = .before
    @Published public var remainingFiles: Int = -1
    @Published public var totalFiles: Int = -1
    @Published public var currentStagePercentage: Double = 0
    @Published var currentState: InstallState = .inprogress
    
    public let id: UUID = UUID()
    public var callback: (() -> Void)? = nil
    
    public static func == (lhs: InstallTask, rhs: InstallTask) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public func start() { }
    public func getTitle() -> String { "" }
    public func onComplete(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    public func updateStage(_ stage: InstallStage) {
        debug("切换阶段: \(stage.getDisplayName())")
        DispatchQueue.main.async {
            self.stage = stage
            self.currentStagePercentage = 0
        }
    }
    
    public func getProgress() -> Double {
        Double(totalFiles - remainingFiles) / Double(totalFiles)
    }
    
    func getInstallStages() -> [InstallStage] { [] }
    
    public func getInstallStates() -> [InstallStage : InstallState] {
        let allStages: [InstallStage] = [.before] + getInstallStages()
        var result: [InstallStage: InstallState] = [:]
        var foundCurrent = false
        for stage in allStages {
            if foundCurrent {
                result[stage] = .waiting
            } else if self.stage == stage {
                result[stage] = currentState
                foundCurrent = true
            } else {
                result[stage] = .finished
            }
        }
        result.removeValue(forKey: .before)
        return result
    }
    
    public func complete() {
        log("下载任务结束")
        self.updateStage(.end)
        DispatchQueue.main.async {
            self.callback?()
        }
    }
    
    public func completeOneFile() {
        DispatchQueue.main.async {
            self.remainingFiles -= 1
        }
    }
}

public class InstallTasks: ObservableObject, Identifiable, Hashable, Equatable {
    @Published public var tasks: [String : InstallTask]
    private var remainingTasks: Int
    
    public let id: UUID = .init()
    public static func == (lhs: InstallTasks, rhs: InstallTasks) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tasks)
    }
    
    public var totalFiles: Int {
        var totalFiles = 0
        tasks.values.forEach { totalFiles += $0.totalFiles }
        return totalFiles
    }
    
    public var remainingFiles: Int {
        var remainingFiles = 0
        tasks.values.forEach { remainingFiles += $0.remainingFiles }
        return remainingFiles
    }
    
    public func getProgress() -> Double {
        var progress: Double = 0
        for task in tasks.values {
            progress += task.getProgress()
        }
        return progress / Double(tasks.count)
    }
    
    public func getTasks() -> [InstallTask] {
        let order = ["minecraft", "fabric", "forge", "neoforge", "customFile", "modpack"]
        return order.compactMap { tasks[$0] }
    }
    
    public func addTask(key: String, task: InstallTask) {
        tasks[key] = task
        self.remainingTasks += 1
        subscribeToTask(task)
    }
    
    init(_ tasks: [String : InstallTask]) {
        self.tasks = tasks
        self.remainingTasks = tasks.count
        subscribeToTasks()
    }
    
    private var cancellables: [AnyCancellable] = []
    
    private func subscribeToTasks() {
        cancellables.forEach { $0.cancel() }
        cancellables = []
        for task in tasks.values {
            subscribeToTask(task)
        }
    }

    private func subscribeToTask(_ task: InstallTask) {
        let cancellable = task.objectWillChange.sink { [weak self] _ in
            if task.stage == .end {
                self?.remainingTasks -= 1
                if self?.remainingTasks == 0 {
                    DataManager.shared.inprogressInstallTasks = nil
                    if case .installing(_) = DataManager.shared.router.getLast() {
                        DataManager.shared.router.removeLast()
                    }
                }
            }
            self?.objectWillChange.send()
        }
        cancellables.append(cancellable)
    }
    
    public static func single(_ task: InstallTask, key: String = "minecraft") -> InstallTasks { .init([key : task]) }
    
    public static func empty() -> InstallTasks { .init([:]) }
}

// MARK: - Minecraft 安装任务定义
public class MinecraftInstallTask: InstallTask {
    public var manifest: ClientManifest?
    public var assetIndex: AssetIndex?
    public var name: String
    public var versionURL: URL { minecraftDirectory.versionsURL.appending(path: name) }
    public let minecraftVersion: MinecraftVersion
    public let minecraftDirectory: MinecraftDirectory
    public let startTask: (MinecraftInstallTask) async throws -> Void
    public let architecture: Architecture
    
    public init(minecraftVersion: MinecraftVersion, minecraftDirectory: MinecraftDirectory, name: String, architecture: Architecture = .system, startTask: @escaping (MinecraftInstallTask) async throws -> Void) {
        self.minecraftVersion = minecraftVersion
        self.minecraftDirectory = minecraftDirectory
        self.name = name
        self.startTask = startTask
        self.architecture = architecture
    }
    
    public override func start() {
        Task {
            do {
                try await startTask(self)
                complete()
            } catch {
                err("无法安装 Minecraft: \(error.localizedDescription)")
                await PopupManager.shared.show(.init(.error, "无法安装 Minecraft", "\(error.localizedDescription)\n若要反馈此问题，你可以进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送本页面的照片或截图。", [.ok]))
                await MainActor.run {
                    currentState = .failed
                    DataManager.shared.inprogressInstallTasks = nil
                    try? FileManager.default.removeItem(at: versionURL)
                }
            }
        }
    }
    
    override func getInstallStages() -> [InstallStage] {
        [.clientJson, .clientIndex, .clientJar, .clientResources, .clientLibraries, .natives]
    }
    
    public override func getTitle() -> String {
        "\(minecraftVersion.displayName) 安装"
    }
}

public class CustomFileDownloadTask: InstallTask {
    private let url: URL
    private let destination: URL
    @Published private var progress: Double = 0
    
    init(url: URL, destination: URL) {
        self.url = url
        self.destination = destination
        super.init()
        self.totalFiles = 1
        self.remainingFiles = 1
    }
    
    public override func getTitle() -> String {
        "自定义下载：\(destination.lastPathComponent)"
    }
    
    public override func getProgress() -> Double {
        currentStagePercentage
    }
    
    public override func start() {
        Task {
            do {
                try await SingleFileDownloader.download(url: url, destination: destination) { progress in
                    self.currentStagePercentage = progress
                }
            } catch {
                hint("\(destination.lastPathComponent) 下载失败: \(error.localizedDescription.replacingOccurrences(of: "\n", with: ""))", .critical)
                complete()
                return
            }
            hint("\(destination.lastPathComponent) 下载完成！", .finish)
            complete()
        }
    }
    
    public override func getInstallStates() -> [InstallStage : InstallState] {
        [.customFile: .inprogress]
    }
}

// MARK: - 安装进度定义
public enum InstallStage: Int {
    // Minecraft 安装
    case before = 0
    case clientJson = 1
    case clientIndex = 2
    case clientJar = 3
    case clientResources = 4
    case clientLibraries = 5
    case natives = 6
    case end = 7
    
    // Mod 加载器安装
    case installFabric = 1000
    case installForge = 1001
    case installNeoforge = 1002
    
    // 自定义文件下载
    case customFile = 2000
    
    // Modrinth 资源下载
    case resources = 3000
    
    // 整合包安装
    case modpackFilesDownload = 3050
    case applyOverrides = 3051
    
    // Java 安装
    case javaDownload = 4000
    case javaInstall = 4001
    
    public func getDisplayName() -> String {
        switch self {
        case .before: "未启动"
        case .clientJson: "下载原版 json 文件"
        case .clientJar: "下载原版 jar 文件"
        case .installFabric: "安装 Fabric"
        case .installForge: "安装 Forge"
        case .installNeoforge: "安装 NeoForge"
        case .clientIndex: "下载资源索引文件"
        case .clientResources: "下载散列资源文件"
        case .clientLibraries: "下载依赖项文件"
        case .natives: "下载本地库文件"
        case .customFile: "下载自定义文件"
        case .resources: "下载资源"
        case .modpackFilesDownload: "下载整合包文件"
        case .applyOverrides: "应用整合包更改"
        case .end: "结束"
        case .javaDownload: "下载 Java"
        case .javaInstall: "安装 Java"
        }
    }
}

// MARK: - 安装进度状态定义
public enum InstallState {
    case waiting, inprogress, finished, failed
    public func getImageName() -> String {
        switch self {
        case .waiting:
            "InstallWaiting"
        case .finished:
            "InstallFinished"
        default:
            "Missingno"
        }
    }
}
