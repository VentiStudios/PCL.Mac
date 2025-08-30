//
//  InstallTaskButtonOverlay.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/30.
//

import SwiftUI

struct InstallTaskButtonOverlay: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @State private var isAppeared: Bool = false
    private let tasks: InstallTasks
    
    init(tasks: InstallTasks) {
        self.tasks = tasks
    }
    
    var body: some View {
        RoundedButton {
            Image("DownloadIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .foregroundStyle(.white)
        } onClick: {
            dataManager.router.append(.installing(tasks: tasks))
        }
        .scaleEffect(isAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isAppeared = true
            }
        }
    }
}
