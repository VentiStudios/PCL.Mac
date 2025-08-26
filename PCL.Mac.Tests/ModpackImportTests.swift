//
//  ModpackImportTests.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/8/26.
//

import Foundation
import Testing
import PCL_Mac

struct ModpackImportTests {
    @Test func testImportModpack() async throws {
        let importer = ModrinthModpackImporter(minecraftDirectory: .init(rootURL: URL(fileURLWithUserPath: "~/PCL-Mac-minecraft"), name: ""), modpackURL: URL(fileURLWithUserPath: "~/minecraft/Fabulously.Optimized-v9.0.0.mrpack.zip"))
        try importer.createInstallTasks().tasks["minecraft"]!.start()
        try await Task.sleep(for: .seconds(30))
    }
}
