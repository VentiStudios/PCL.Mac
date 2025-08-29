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
    @Published public var currentStageProgress: Double = 0
    @Published var currentStageState: InstallState = .inprogress
    @Published var completedStages: Int = 0
    
    public let id: UUID = UUID()
    public var callback: (() -> Void)? = nil
    
    public static func == (lhs: InstallTask, rhs: InstallTask) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// 任务开始函数
    /// 不应在其中调用 complete()
    public func startTask() async throws { }
    public func getTitle() -> String { "" }
    func getStages() -> [InstallStage] { [] }
    func wrapError(error: Error) -> Error { error }
    
    public final func start() async throws {
        defer { complete() }
        do {
            try await startTask()
        } catch {
            setState(.failed)
            throw error
        }
    }
    
    public final func onComplete(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    public final func setStage(_ stage: InstallStage) {
        debug("切换阶段: \(stage.getDisplayName())")
        DispatchQueue.main.async {
            self.stage = stage
            self.currentStageProgress = 0
            self.completedStages += 1
        }
    }
    
    public final func getInstallStates() -> [InstallStage : InstallState] {
        let allStages: [InstallStage] = [.before] + getStages()
        var result: [InstallStage: InstallState] = [:]
        var foundCurrent = false
        for stage in allStages {
            if foundCurrent {
                result[stage] = .waiting
            } else if self.stage == stage {
                result[stage] = currentStageState
                foundCurrent = true
            } else {
                result[stage] = .finished
            }
        }
        result.removeValue(forKey: .before)
        return result
    }
    
    public final func completeOneFile() {
        DispatchQueue.main.async {
            self.remainingFiles -= 1
        }
    }
    
    final func setState(_ newState: InstallState) { DispatchQueue.main.async { self.currentStageState = newState } }
    
    final func setRemainingFiles(_ value: Int) { DispatchQueue.main.async { self.remainingFiles = value } }
    
    final func setProgress(_ value: Double) { DispatchQueue.main.async { self.currentStageProgress = value} }
    
    final func increaseProgress(_ value: Double) { setProgress(currentStageProgress + value) }
    
    private final func complete() {
        log("任务 \(getTitle()) 结束")
        self.setStage(.end)
        DispatchQueue.main.async {
            self.callback?()
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
    
    public var remainingFiles: Int {
        var remainingFiles = 0
        tasks.values.forEach { remainingFiles += $0.remainingFiles }
        return remainingFiles
    }
    
    public func getProgress() -> Double {
        var progress: Double = 0
        
        for task in tasks.values {
            progress += Double(task.completedStages) + task.currentStageProgress
        }
        return progress / Double(tasks.values.map { $0.getStages().count }.reduce(0, +) + 1)
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
    
    public func startAll(callback: @escaping (Result<Void, Error>) -> Void) {
        Task {
            for task in getTasks() {
                do {
                    try await task.start()
                } catch {
                    err("任务 \(task.getTitle()) 执行失败: \(error.localizedDescription)")
                    await MainActor.run {
                        callback(.failure(error))
                    }
                    return
                }
            }
            await MainActor.run {
                callback(.success(()))
            }
        }
    }
    
    public static func single(_ task: InstallTask, key: String = "minecraft") -> InstallTasks { .init([key : task]) }
    
    public static func empty() -> InstallTasks { .init([:]) }
}

public class CustomFileDownloadTask: InstallTask {
    private let url: URL
    private let destination: URL
    @Published private var progress: Double = 0
    
    init(url: URL, destination: URL) {
        self.url = url
        self.destination = destination
        super.init()
        self.remainingFiles = 1
    }
    
    public override func getTitle() -> String {
        "自定义下载：\(destination.lastPathComponent)"
    }
    
    public override func startTask() async throws {
        do {
            try await SingleFileDownloader.download(task: self, url: url, destination: destination)
        } catch {
            throw InstallingError.customFileDownloadFailed(name: destination.lastPathComponent, error: error)
        }
    }
    
    override func getStages() -> [InstallStage] {
        [.customFile]
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
