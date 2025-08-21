//
//  AnnouncementManager.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/5.
//

import Foundation
import SwiftyJSON

public class AnnouncementManager: ObservableObject {
    private static let root: URL = URL(string: "https://gitee.com/yizhimcqiu/pcl-mac-announcements/raw/main/announcements")!
    public static let shared: AnnouncementManager = .init()
    
    @Published var latest: Announcement? = nil
    @Published var history: [Announcement] = []
    
    public func loadHistory() {
        history.removeAll()
        Task {
            if let json = await Requests.get(AnnouncementManager.root.appending(path: "latest.json")).json {
                let latestNumber = json["number"].intValue
                for i in stride(from: latestNumber, through: max(latestNumber - 9, 0), by: -1) {
                    if let json = await Requests.get(AnnouncementManager.root.appending(path: "history").appending(path: "\(i).json")).json {
                        await MainActor.run {
                            self.history.append(.init(json))
                        }
                    }
                }
            }
        }
    }
    
    private init() {
        Task {
            if let json = await Requests.get(AnnouncementManager.root.appending(path: "latest.json")).json {
                if let json = await Requests.get(AnnouncementManager.root.appending(path: json["path"].stringValue)).json {
                    await MainActor.run {
                        self.latest = .init(json)
                    }
                }
            }
        }
    }
}
