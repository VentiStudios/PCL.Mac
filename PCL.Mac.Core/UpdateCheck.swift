//
//  UpdateCheck.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/13.
//

import Foundation
import SwiftyJSON
import SwiftUI

class NoRedirectSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        debug("检测到重定向: \(request.url.map { $0.absoluteString } ?? "(无 URL)")")
        completionHandler(nil)
    }
}

public struct Update {
    public let time: Date
    public let url: URL
}

public class UpdateCheck {
    public static func getLastUpdate() async -> Update? {
        if let json = await Requests.get(
            "https://api.github.com/repos/PCL-Community/PCL.Mac/actions/artifacts",
            headers: [
                "Accept": "application/vnd.github+json",
                "Authorization": "Bearer \(ARTIFACT_PAT)"
            ]
        ).json {
            let artifact = json["artifacts"].arrayValue[0]
            let formatter = ISO8601DateFormatter()
            let date = formatter.date(from: artifact["created_at"].stringValue)!
            log("最新工件构建时间: \(SharedConstants.shared.dateFormatter.string(from: date))")
            let url = URL(string: artifact["archive_download_url"].stringValue)!
            return .init(time: date, url: url)
        }
        return nil
    }
    
    public static func downloadUpdate(_ update: Update) async {
        var request = URLRequest(url: update.url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(ARTIFACT_PAT)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: NoRedirectSessionDelegate(), delegateQueue: nil)

        return await withCheckedContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                do {
                    try data?.write(to: SharedConstants.shared.temperatureURL.appending(path: "LauncherUpdate.zip"))
                } catch {
                    err("无法写入文件: \(error.localizedDescription)")
                }
                continuation.resume()
            }
            task.resume()
        }
    }
    
    public static func applyUpdate() {
        let zipURL = SharedConstants.shared.temperatureURL.appending(path: "LauncherUpdate.zip")
        let appURL = Bundle.main.bundleURL
        Util.unzip(archiveURL: zipURL, destination: appURL.parent(), replace: true)
        Util.unzip(archiveURL: appURL.parent().appending(path: "PCL.Mac.zip"), destination: appURL.parent(), replace: true)
        let executableURL = appURL.appending(path: "Contents").appending(path: "MacOS").appending(path: "PCL.Mac")
        let process = Process()
        process.executableURL = executableURL
        try? process.run()
        DispatchQueue.main.async {
            NSApplication.shared.terminate(nil)
        }
    }
}
