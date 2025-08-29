//
//  NewInstallTask.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/28.
//

import Foundation

public class NewInstallTask: ObservableObject, Hashable, Equatable {
    @Published public var currentStageProgress: Double = 0
    @Published var stage: InstallStage = .before
    @Published var currentState: InstallState = .inprogress
    @Published var remainingFiles: Int = 0 {
        willSet { previousRemainingFiles = remainingFiles }
        didSet { self.parent?.changeRemainingFileCount(diff: remainingFiles - previousRemainingFiles) }
    }
    fileprivate var parent: NewInstallTasks?
    private var previousRemainingFiles: Int = 0
    private var subTasks: [NewInstallTask] = []
    private let id: UUID = .init()
    
    // 需要子类重写的方法
    func startTask() async throws { }
    public func getTitle() -> String { "" }
    public func getStages() -> [InstallStage] { [] }
    
    public final func start() async throws {
        defer { Task { @MainActor in complete() } }
        try await startTask()
        for subTask in subTasks {
            try await subTask.start()
        }
    }
    
    public final func complete() {
        log("任务结束: \(getTitle())")
        updateStage(.end)
        parent?.onTaskFinished(self)
    }
    
    public final func completeOneFile() {
        DispatchQueue.main.async {
            self.remainingFiles -= 1
        }
    }
    
    public final func addSubTask(task: NewInstallTask) {
        subTasks.append(task)
    }
    
    final func updateStage(_ stage: InstallStage) {
        debug("切换阶段: \(stage.getDisplayName())")
        setProgress(1)
        DispatchQueue.main.async {
            self.stage = stage
            self.currentStageProgress = 0
        }
    }
    
    final func increaseProgress(_ value: Double) { setProgress(currentStageProgress + value) }
    
    final func setProgress(_ progress: Double) {
        DispatchQueue.main.async {
            let difference = progress - self.currentStageProgress
            self.currentStageProgress = progress
            self.parent?.increaseProgress(difference)
        }
    }
    
    public static func == (lhs: NewInstallTask, rhs: NewInstallTask) -> Bool { lhs.id == rhs.id }
    
    public final func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public class NewInstallTasks: ObservableObject {
    @Published private var totalProgress: Double = 0
    public var progress: Double { totalProgress / Double(stageCount) }
    public private(set) var remainingFiles: Int = 0
    private var tasks: [String: NewInstallTask] = [:]
    private var stageCount: Int
    
    init(_ tasks: [String : NewInstallTask]) {
        self.tasks = tasks
        self.stageCount = tasks.map { $0.value.getStages().count }.reduce(0, +)
        self.tasks.forEach { $0.value.parent = self }
    }
    
    public func addTask(key: String, task: NewInstallTask) {
        task.parent = self
        tasks[key] = task
        stageCount += task.getStages().count
    }
    
    fileprivate func onTaskFinished(_ task: NewInstallTask) {
        tasks = tasks.filter { $0.value != task }
    }
    
    fileprivate func increaseProgress(_ value: Double) {
        totalProgress += value
    }
    
    fileprivate func changeRemainingFileCount(diff: Int) {
        remainingFiles += diff
    }
}
