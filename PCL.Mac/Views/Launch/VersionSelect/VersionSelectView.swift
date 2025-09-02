//
//  VersionSelectView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/12.
//

import SwiftUI
import UniformTypeIdentifiers

struct VersionSelectView: View, SubRouteContainer {
    @ObservedObject private var dataManager: DataManager = .shared
    @ObservedObject private var settings: AppSettings = .shared
    
    @State private var directoryRoutes: [AppRoute] = AppSettings.shared.minecraftDirectories.map { .versionList(directory: $0) }
    
    var body: some View {
        Group {
            switch dataManager.router.getLast() {
            case .versionList(let directory):
                VersionListView(minecraftDirectory: directory)
            default:
                Spacer()
                    .onAppear {
                        if let directory = settings.currentMinecraftDirectory {
                            dataManager.router.append(.versionList(directory: directory))
                        }
                    }
            }
        }
        .onAppear {
            dataManager.leftTab(300) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("文件夹列表")
                        .font(.custom("PCL English", size: 12))
                        .foregroundStyle(Color(hex: 0x8C8C8C))
                        .padding(.leading, 12)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                    MyList(
                        cases: $directoryRoutes,
                        height: 42,
                        content: { type, isSelected in
                            createListItemView(type)
                                .foregroundStyle(isSelected ? AnyShapeStyle(settings.theme.getTextStyle()) : AnyShapeStyle(Color("TextColor")))
                        }
                    )
                    Text("添加或导入")
                        .font(.custom("PCL English", size: 12))
                        .foregroundStyle(Color(hex: 0x8C8C8C))
                        .padding(.leading, 12)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                    LeftTabItem(imageName: "PlusIcon", text: "添加已有文件夹")
                        .onTapGesture {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowedContentTypes = [.folder]
                            
                            if panel.runModal() == .OK {
                                guard !settings.minecraftDirectories.contains(where: { $0.rootURL == panel.url! }) else {
                                    hint("该目录已存在！", .critical)
                                    return
                                }
                                settings.minecraftDirectories.append(.init(rootURL: panel.url!, name: "自定义目录"))
                                settings.currentMinecraftDirectory = .init(rootURL: panel.url!, name: "自定义目录")
                                hint("添加成功", .finish)
                            }
                        }
                    LeftTabItem(imageName: "ImportModpackIcon", text: "导入整合包")
                        .onTapGesture {
                            let panel = NSOpenPanel()
                            panel.allowsMultipleSelection = false
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            
                            if panel.runModal() == .OK {
                                if case .failure(let error) = ModrinthModpackImporter.checkModpack(panel.url!) {
                                    switch error {
                                    case .zipFormatError:
                                        PopupManager.shared.show(.init(.error, "无法导入整合包", "该整合包不是一个有效的压缩包！", [.ok]))
                                    case .unsupported:
                                        PopupManager.shared.show(.init(.error, "无法导入整合包", "很抱歉，PCL.Mac 暂时只支持导入 Modrinth 整合包……\n你可以使用其它启动器导入，然后把实例文件夹拖入本页面的右侧。", [.ok]))
                                    }
                                    return
                                }
                                
                                do {
                                    let importer = try ModrinthModpackImporter(minecraftDirectory: settings.currentMinecraftDirectory.unwrap(), modpackURL: panel.url!)
                                    let tasks = try importer.createInstallTasks()
                                    dataManager.inprogressInstallTasks = tasks
                                    tasks.startAll { result in
                                        switch result {
                                        case .success(_):
                                            hint("整合包 {placeholder} 导入成功！")
                                        case .failure(let failure):
                                            PopupManager.shared.show(.init(.error, "导入整合包失败", "\(failure.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送此页面的照片或截图。", [.ok]))
                                        }
                                    }
                                } catch {
                                    err("创建导入任务失败: \(error.localizedDescription)")
                                    PopupManager.shared.show(.init(.error, "无法创建导入任务", "\(error.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送本页面的照片或截图。", [.ok]))
                                }
                            }
                        }
                    Spacer()
                }
            }
        }
        .onDrop(of: [.folder], delegate: VersionDropDelegate())
        .onChange(of: settings.minecraftDirectories) {
            directoryRoutes = settings.minecraftDirectories.map { .versionList(directory: $0) }
        }
    }
    
    private func createListItemView(_ type: AppRoute) -> some View {
        if case .versionList(let directory) = type {
            return AnyView(
                HStack {
                    VStack(alignment: .leading) {
                        Text(directory.name ?? "")
                            .font(.custom("PCL English", size: 14))
                            .foregroundStyle(.primary)
                        Text(directory.rootURL.path)
                            .font(.custom("PCL English", size: 12))
                            .foregroundStyle(Color(hex: 0x8C8C8C))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16)
                        .foregroundStyle(Color("TextColor"))
                        .onTapGesture {
                            settings.removeDirectory(url: directory.rootURL)
                            hint("移除成功", .finish)
                        }
                        .padding(4)
                }
            )
        }
        return AnyView(EmptyView())
    }
}

fileprivate struct LeftTabItem: View {
    let imageName: String
    let text: String
    
    var body: some View {
        MyListItem {
            HStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22)
                    .foregroundStyle(Color("TextColor"))
                    .padding(.leading)
                    .padding(.top, 6)
                    .padding(.bottom, 6)
                Text(text)
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(Color("TextColor"))
                Spacer()
            }
        }
        
    }
}

#Preview {
    VersionSelectView()
}
