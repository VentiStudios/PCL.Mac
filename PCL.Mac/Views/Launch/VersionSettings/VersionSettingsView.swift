//
//  VersionSettingsView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/16.
//

import SwiftUI
import ZIPFoundation
import SwiftyJSON

struct VersionSettingsView: View, SubRouteContainer {
    @ObservedObject private var dataManager: DataManager = .shared
    
    private let instance: MinecraftInstance!
    
    init() {
        if let directory = AppSettings.shared.currentMinecraftDirectory,
           let defaultInstance = AppSettings.shared.defaultInstance,
           let instance = MinecraftInstance.create(directory.versionsURL.appending(path: defaultInstance)) {
            self.instance = instance
        } else {
            self.instance = nil
        }
    }
    
    var body: some View {
        Group {
            switch dataManager.router.getLast() {
            case .instanceOverview:
                InstanceOverviewView(instance: instance)
            case .instanceSettings:
                InstanceSettingsView(instance: instance)
            case .instanceMods:
                InstanceModsView(instance: instance)
            default:
                Spacer()
            }
        }
        .onAppear {
            dataManager.leftTab(200) {
                VStack(alignment: .leading, spacing: 0) {
                    MyList(
                        root: .versionSettings(instance: instance),
                        cases: .constant(
                            [
                                .instanceOverview,
                                .instanceSettings,
                                .instanceMods
                            ]
                        )) { route, isSelected in
                            createListItemView(route)
                                .foregroundStyle(isSelected ? AnyShapeStyle(AppSettings.shared.theme.getTextStyle()) : AnyShapeStyle(Color("TextColor")))
                        }
                        .padding(.top, 10)
                    Spacer()
                }
            }
        }
    }
    
    private func createListItemView(_ route: AppRoute) -> some View {
        let imageName: String
        let text: String
        
        switch route {
        case .instanceOverview:
            imageName = "GameDownloadIcon"
            text = "概览"
        case .instanceSettings:
            imageName = "SettingsIcon"
            text = "设置"
        case .instanceMods:
            imageName = "ModDownloadIcon"
            text = "Mod"
        default:
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(text)
                    .font(.custom("PCL English", size: 14))
            }
        )
    }
}

struct InstanceOverviewView: View {
    let instance: MinecraftInstance
    
    var body: some View {
        ScrollView {
            TitlelessMyCard {
                HStack {
                    Image(instance.getIconName())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32)
                    VStack(alignment: .leading) {
                        Text(instance.name)
                        Text(getVersionString())
                            .foregroundStyle(Color(hex: 0x8C8C8C))
                    }
                    .font(.custom("PCL English", size: 14))
                    .foregroundStyle(Color("TextColor"))
                    Spacer()
                }
            }
            .padding()
            
            TitlelessMyCard(index: 1) {
                HStack(spacing: 16) {
                    MyButton(text: "打开文件夹", foregroundStyle: AppSettings.shared.theme.getTextStyle()) {
                        NSWorkspace.shared.open(instance.runningDirectory)
                    }
                    .frame(width: 120, height: 35)
                    Spacer()
                }
                .padding(2)
            }
            .padding()
        }
        .scrollIndicators(.never)
    }
    
    private func getVersionString() -> String {
        var str = instance.version.displayName
        if instance.clientBrand != .vanilla {
            str += ", \(instance.clientBrand.getName())"
        }
        
        return str
    }
}
