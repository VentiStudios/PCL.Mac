//
//  DownloadPage.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/8.
//

import SwiftUI

struct DownloadPage: View {
    let version: MinecraftVersion
    let back: () -> Void
    
    @State private var name: String
    @State private var tasks: InstallTasks = .empty()
    @State private var errorMessage: String = ""
    @State private var loader: LoaderVersion? = nil
    
    init(_ version: MinecraftVersion, _ back: @escaping () -> Void) {
        self.version = version
        self.name = version.displayName
        self.back = back
        self.tasks.addTask(key: "minecraft", task: MinecraftInstaller.createTask(version, version.displayName, AppSettings.shared.currentMinecraftDirectory!))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                TitlelessMyCard {
                    HStack(alignment: .center) {
                        Image("Back")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15)
                            .foregroundStyle(Color(hex: 0x96989A))
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            .onTapGesture {
                                back()
                            }
                        Image(loader != nil ? "\(loader!.loader.rawValue.capitalized)Icon" : version.getIconName())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 35)
                        VStack {
                            MyTextField(text: $name)
                                .foregroundStyle(Color("TextColor"))
                                .onChange(of: name) {
                                    checkName()
                                }
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundStyle(Color(hex: 0xFF4C4C))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: errorMessage)
                    }
                }
                .noAnimation()
                .padding()
                
                VStack {
                    LoaderCard(loader: .fabric, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                        .padding(.top, 20)
                    
                    LoaderCard(loader: .forge, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                    
                    LoaderCard(loader: .neoforge, selectedLoader: $loader, name: $name, version: version)
                        .padding()
                }
                .onChange(of: loader) { old, new in
                    // 移除 Mod 加载器
                    if let old, new == nil {
                        if name == version.displayName + "-" + old.loader.getName() {
                            name = version.displayName
                        }
                        checkName()
                    }
                    // 添加 Mod 加载器
                    else if let new, old == nil {
                        if name == version.displayName { name.append("-\(new.loader.getName())") }
                    }
                }
                
                Spacer()
            }
            .scrollIndicators(.never)
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedButton {
                        HStack {
                            Image("DownloadIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20)
                            Text("开始下载")
                                .font(.custom("PCL English", size: 16))
                        }
                    } onClick: {
                        // 若实例名无效则直接返回
                        guard errorMessage.isEmpty else {
                            hint(errorMessage, .critical)
                            return
                        }
                        
                        if DataManager.shared.inprogressInstallTasks != nil { return }
                        
                        // 如果选择了加载器，添加加载器安装任务
                        if let loader {
                            let instanceURL = AppSettings.shared.currentMinecraftDirectory!.versionsURL.appending(path: name)
                            let task: InstallTask? =
                            switch loader.loader {
                            case .fabric: FabricInstallTask(instanceURL: instanceURL, loaderVersion: loader.version)
                            case .forge, .neoforge: ForgeInstallTask(instanceURL: instanceURL, loaderVersion: loader.version, isNeoforge: loader.loader == .neoforge)
                            default: nil
                            }
                            tasks.addTask(key: loader.loader.rawValue, task: task!)
                        }
                        
                        // 设置 MinecraftInstallTask 的实例名
                        if let task = tasks.tasks["minecraft"] as? MinecraftInstallTask {
                            task.name = self.name
                        }
                        
                        // 切换到安装任务页面
                        DataManager.shared.inprogressInstallTasks = self.tasks
                        DataManager.shared.router.append(.installing(tasks: tasks))
                        // 开始安装
                        tasks.startAll { result in
                            switch result {
                            case .success(_):
                                hint("\(name) 安装完成！", .finish)
                                AppSettings.shared.defaultInstance = name
                            case .failure(let failure):
                                PopupManager.shared.show(.init(.error, "Minecraft 安装失败", "\(failure.localizedDescription)\n若要寻求帮助，请进入设置 > 其它 > 打开日志，将选中的文件发给别人，而不是发送此页面的照片或截图。", [.ok]))
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    Spacer()
                }
            }
        }
    }
    
    private func checkName() {
        if name == version.displayName && loader != nil {
            errorMessage = "带 Mod 加载器的实例名不能与版本号一致！"
        } else if name.isEmpty {
            errorMessage = "实例名不能为空！"
        } else {
            errorMessage = ""
        }
    }
}

private struct LoaderVersion: Identifiable, Equatable {
    let id: UUID = .init()
    let loader: ClientBrand
    let version: String
    let stable: Bool
    var displayName: String
    
    init(loader: ClientBrand, version: String, stable: Bool) {
        self.init(loader: loader, version: version, stable: stable, displayName: version)
    }
    
    init(loader: ClientBrand, version: String, stable: Bool, displayName: String) {
        self.loader = loader
        self.version = version
        self.stable = stable
        self.displayName = displayName
    }
    
    static func == (lhs: LoaderVersion, rhs: LoaderVersion) -> Bool {
        lhs.version == rhs.version && lhs.loader == rhs.loader
    }
}

fileprivate struct LoaderCard: View {
    @State private var showFoldController: Bool = false
    @State private var showCancelButton: Bool = false
    @State private var versions: [LoaderVersion]? = nil
    @State private var isUnfolded: Bool = false
    @State private var text: String = "加载中……"
    @Binding private var selectedLoader: LoaderVersion?
    @Binding private var name: String
    
    private let loader: ClientBrand
    private let version: MinecraftVersion
    
    init(loader: ClientBrand, selectedLoader: Binding<LoaderVersion?>, name: Binding<String>, version: MinecraftVersion) {
        self.loader = loader
        self.version = version
        self._selectedLoader = selectedLoader
        self._name = name.wrappedValue == version.displayName ? name : .constant(name.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            if showFoldController, let versions = versions {
                MyCard(title: loader.getName(), unfoldBinding: $isUnfolded) {
                    LazyVStack(spacing: 0) {
                        ForEach(versions) { version in
                            ListItem(iconName: "\(loader.rawValue.capitalized)Icon", title: version.displayName, description: version.stable ? "稳定版" : "测试版", isSelected: selectedLoader == version)
                                .animation(.easeInOut(duration: 0.2), value: selectedLoader?.id)
                                .onTapGesture {
                                    selectedLoader = version
                                    isUnfolded = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        showFoldController = false
                                        showCancelButton = true
                                    }
                                }
                        }
                    }
                }
                .noAnimation()
            } else {
                TitlelessMyCard {
                    HStack {
                        MaskedTextRectangle(text: loader.getName())
                        Spacer()
                        if showCancelButton {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .bold()
                                .frame(width: 16)
                                .foregroundStyle(Color("TextColor"))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showCancelButton = false
                                    showFoldController = true
                                    selectedLoader = nil
                                }
                        }
                    }
                    .frame(height: 9)
                }
                .noAnimation()
            }
            
            if !isUnfolded {
                HStack {
                    overlayContent
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(Color(hex: 0x8C8C8C))
                    .offset(x: 150, y: 14)
                    
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .task {
            await loadVersions()
        }
        .onChange(of: versions) {
            guard let versions else {
                text = "加载中……"
                return
            }
            
            if versions.isEmpty {
                text = "无可用版本"
            } else {
                text = "可以添加"
                DispatchQueue.main.async {
                    showFoldController = true
                }
            }
        }
        .onChange(of: selectedLoader) {
            if let selectedLoader, selectedLoader.loader != loader {
                text = "与 \(selectedLoader.loader.getName()) 不兼容"
                showFoldController = false
                isUnfolded = false
            } else if selectedLoader == nil {
                text = "可以添加"
                showFoldController = true
            }
        }
    }
    
    private var overlayContent: some View {
        HStack {
            if let selected = selectedLoader, selected.loader == loader {
                Image("\(loader.rawValue.capitalized)Icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16)
                Text(selected.displayName)
            } else {
                Text(text)
            }
        }
    }
    
    private func loadVersions() async {
        var versions: [LoaderVersion] = []
        switch loader {
        case .fabric:
            if let json = await Requests.get("https://meta.fabricmc.net/v2/versions/loader/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .fabric, version: $0["loader"]["version"].stringValue, stable: $0["loader"]["stable"].boolValue) }
            }
        case .forge:
            if let json = await Requests.get("https://bmclapi2.bangbang93.com/forge/minecraft/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .forge, version: $0["version"].stringValue, stable: true) }
            }
        case .neoforge:
            if let json = await Requests.get("https://bmclapi2.bangbang93.com/neoforge/list/\(version.displayName)").json {
                versions = json.arrayValue.map { LoaderVersion(loader: .neoforge, version: $0["version"].stringValue, stable: true) }
            }
        default:
            break
        }
        
        for i in 0..<versions.count {
            if versions[i].version.starts(with: "1.20.1") {
                versions[i] = LoaderVersion(
                    loader: versions[i].loader,
                    version: versions[i].version,
                    stable: versions[i].stable,
                    displayName: String(versions[i].version.dropFirst(7))
                )
            }
        }
        
        versions.sort { version1, version2 in
            return version1.displayName.compare(version2.displayName, options: .numeric) == .orderedDescending
        }
        self.versions = versions
    }
    
    private struct ListItem: View {
        let iconName: String
        let title: String
        let description: String
        let isSelected: Bool
        
        init(iconName: String, title: String, description: String, isSelected: Bool) {
            self.iconName = iconName
            self.title = title
            self.description = description
            self.isSelected = isSelected
        }
        
        var body: some View {
            MyListItem(isSelected: isSelected) {
                HStack {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 35)
                        .padding(.leading, 5)
                    VStack(alignment: .leading) {
                        Text(title)
                            .foregroundStyle(Color("TextColor"))
                        Text(description)
                            .foregroundStyle(Color(hex: 0x8C8C8C))
                    }
                    .font(.custom("PCL English", size: 14))
                    Spacer()
                }
                .padding(4)
            }
        }
    }
}
