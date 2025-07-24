//
//  ChunkedDownloader.swift
//  PCL.Mac
//
//  Created by Claude on 2025/6/1.
//

import Foundation

/// 用于大文件分块下载的类
public class ChunkedDownloader {
    private let url: URL
    private let destination: URL
    private let chunkCount: Int
    private var chunkTasks: [URLSessionDataTask] = []
    private var chunkResults: [Int: Data] = [:]
    private var chunkErrors: [Int: Error] = [:]
    private let queue = DispatchQueue(label: "ChunkedDownloader.queue", attributes: .concurrent)
    private let group = DispatchGroup()
    private var totalSize: Int64 = 0
    private var finished: Bool = false
    
    public init(url: URL, destination: URL, chunkCount: Int) {
        self.url = url
        self.destination = destination
        self.chunkCount = chunkCount
    }
    
    public func start() async {
        do {
            guard let size = await fetchContentLength() else {
                throw NSError(domain: "", code: -1)
            }
            self.totalSize = size
            try await self.downloadChunks(size: size)
        } catch {
            debug("正在使用单线程下载 \(url.lastPathComponent)")
            try? await Requests.get(url).data?.write(to: destination)
        }
    }

    private func fetchContentLength() async -> Int64? {
        return await withCheckedContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            let task = URLSession.shared.dataTask(with: request) { (_, response, error) in
                if let error = error {
                    err("HEAD 请求失败: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse,
                      let contentLengthStr = httpResponse.allHeaderFields["Content-Length"] as? String,
                      let contentLength = Int64(contentLengthStr) else {
                    err("响应头中没有 Content-Length")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: contentLength)
            }
            task.resume()
        }
    }

    private func downloadChunks(size: Int64) async throws {
        guard chunkCount > 0, size > 0 else {
            throw NSError(domain: "", code: -1)
        }

        let baseChunkSize = size / Int64(chunkCount)
        let remainder = size % Int64(chunkCount)
        var offset: Int64 = 0

        for i in 0..<chunkCount {
            let extra = i < remainder ? 1 : 0
            let thisChunkSize = baseChunkSize + Int64(extra)
            let start = offset
            let end = start + thisChunkSize - 1
            if start > end { continue }
            group.enter()
            downloadChunk(index: i, range: start...end)
            offset += thisChunkSize
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            group.notify(queue: queue) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: NSError(domain: "", code: -1))
                    return
                }
                do {
                    try self.writeChunksToFile()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume()
            }
        }
    }

    private func downloadChunk(index: Int, range: ClosedRange<Int64>) {
        var request = URLRequest(url: url)
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer { self?.group.leave() }
            guard let self = self else { return }
            if let error = error {
                err("分片 \(index) 下载失败: \(error.localizedDescription)")
                self.queue.async(flags: .barrier) {
                    self.chunkErrors[index] = error
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            
            guard httpResponse.statusCode == 206 else {
                if httpResponse.statusCode == 429 { return }
                err("分片 \(index) 没有返回 206 Partial Content (\(httpResponse.statusCode))")
                self.queue.async(flags: .barrier) {
                    self.chunkErrors[index] = NSError(domain: "ChunkedDownloader", code: -1, userInfo: nil)
                }
                return
            }
            if let data = data {
                self.queue.async(flags: .barrier) {
                    self.chunkResults[index] = data
                }
            }
        }
        task.resume()
        queue.async(flags: .barrier) {
            self.chunkTasks.append(task)
        }
    }

    private func writeChunksToFile() throws {
        guard chunkErrors.isEmpty else {
            throw NSError(domain: "", code: -1)
        }
        
        let sortedChunks = (0..<chunkCount).compactMap { chunkResults[$0] }
        guard sortedChunks.count == chunkCount else {
            err("区块缺失 (\(sortedChunks.count)/\(chunkCount))")
            throw NSError(domain: "", code: -1)
        }
        
        let fileHandle: FileHandle
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try? FileManager.default.createDirectory(at: destination.parent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: nil)
        fileHandle = try FileHandle(forWritingTo: destination)
        for data in sortedChunks {
            fileHandle.write(data)
        }
        try fileHandle.close()
    }
}
