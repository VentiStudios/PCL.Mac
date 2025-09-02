//
//  JavaDownloadView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/1.
//

import SwiftUI

struct JavaInstallView: View {
    @ObservedObject private var dataManager: DataManager = .shared
    @State private var version: String = ""
    @State private var onlyLTS: Bool = true
    @State private var packages: [JavaPackage]? = nil
    @State private var searchTask: Task<Void, Error>?
    
    var body: some View {
        ScrollView {
            MyTip(text: "搜索结果均为 Azul Zulu Java，包含 JDK 和 JRE 版本。", color: .blue)
                .padding()
                .padding(.bottom, -28)
            TitlelessMyCard(index: 1) {
                HStack {
                    MyTextField(text: $version, placeholder: "搜索版本")
                        .onSubmit {
                            search()
                        }
                    Toggle("仅 LTS 版本", isOn: $onlyLTS)
                        .font(.custom("PCL English", size: 14))
                        .foregroundStyle(Color("TextColor"))
                        .onChange(of: onlyLTS) {
                            search()
                        }
                }
            }
            .padding()
            if let packages = packages {
                TitlelessMyCard(index: 2) {
                    VStack(spacing: 0) {
                        if packages.isEmpty {
                            Text("无匹配结果")
                                .font(.custom("PCL English", size: 14))
                                .foregroundStyle(Color("TextColor"))
                        } else {
                            ForEach(packages) { package in
                                JavaPackageView(package: package)
                            }
                        }
                    }
                    .padding(4)
                }
                .padding()
                .padding(.bottom, 25)
            }
        }
        .scrollIndicators(.never)
        .onAppear {
            dataManager.leftTab(0) { EmptyView() }
            search()
        }
    }
    
    private func search() {
        self.searchTask?.cancel()
        searchTask = Task {
            let packages = try await JavaDownloader.search(version: version.isEmpty ? nil : version, onlyLTS: onlyLTS)
            await MainActor.run {
                self.packages = packages
                self.searchTask = nil
            }
        }
    }
}

struct JavaPackageView: View {
    @State private var isHovered: Bool = false
    
    private let package: JavaPackage
    
    init(package: JavaPackage) {
        self.package = package
    }
    
    var body: some View {
        MyListItem {
            HStack(alignment: .center) {
                VStack(alignment: .leading) {
                    Text("\(package.type.rawValue.uppercased()) \(package.version[0])")
                        .foregroundStyle(isHovered ? AppSettings.shared.theme.getTextStyle() : .init(Color("TextColor")))
                    HStack {
                        Text("\(package.versionString)，\(package.arch) 架构")
                    }
                    .foregroundStyle(Color(hex: 0x8C8C8C))
                }
                Spacer()
                if isHovered {
                    Image("DownloadIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16)
                        .padding(.trailing, 4)
                        .foregroundStyle(AppSettings.shared.theme.getTextStyle())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let tasks: InstallTasks = .single(JavaInstallTask(package: package))
                            DataManager.shared.inprogressInstallTasks = tasks
                            tasks.startAll { result in
                                switch result {
                                case .success(_): hint("\(package.type.rawValue.uppercased()) \(package.versionString) 安装成功！", .finish)
                                case .failure(let failure): hint("无法安装 Java：\(failure.localizedDescription)", .critical)
                                }
                            }
                        }
                }
            }
            .font(.custom("PCL English", size: 14))
            .padding(4)
        }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { isHovered in
            self.isHovered = isHovered
        }
    }
}
