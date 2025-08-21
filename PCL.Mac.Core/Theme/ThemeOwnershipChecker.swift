//
//  ThemeOwnershipChecker.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 8/5/25.
//

import Foundation
import CryptoKit
import SwiftyJSON

public class ThemeOwnershipChecker {
    public static let shared: ThemeOwnershipChecker = .init()
    public var unlockedThemes: [String] = []
    
    private func getDeviceSerial() -> String? {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }
        
        if let serialCf = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0) {
            let serial = serialCf.takeUnretainedValue() as? String
            return serial
        }
        return nil
    }
    
    public func getDeviceHash() -> String {
        let string = NSUserName() + (getDeviceSerial() ?? "Serial")
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16))
    }
    
    private func decrypt(code: String, key: String) -> String? {
        guard let keyData = key.data(using: .utf8),
              let combinedData = Data(base64Encoded: code),
              combinedData.count > (12 + 16) else { return nil }
        
        let nonce = combinedData.prefix(12)
        let tag = combinedData.suffix(16)
        let cipherText = combinedData[12..<(combinedData.count - 16)]
        let symmetricKey = SymmetricKey(data: keyData)
        
        do {
            let sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: cipherText,
                tag: tag
            )
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            return nil
        }
    }
    
    public func tryUnlockOld(code: String) -> String? {
        if let jsonString = decrypt(code: code, key: getDeviceHash()),
           let data = jsonString.data(using: .utf8),
           let json = try? JSON(data: data),
           json["verify"].intValue == 20250517 {
            return json["theme"].stringValue
        }
        
        return nil
    }
    
    public func tryUnlock(code: String) -> String? {
        if let code = decrypt(code: code, key: THEME_KEY) {
            return tryUnlockOld(code: code)
        }
        return nil
    }
    
    public func isUnlocked(_ theme: ThemeInfo) -> Bool {
        if theme.id == "pcl" {
            return true
        }
        return unlockedThemes.contains(theme.id)
    }
    
    private init() {
        for code in AppSettings.shared.usedThemeCodes {
            if let theme = tryUnlockOld(code: code) ?? tryUnlock(code: code) {
                self.unlockedThemes.append(theme)
            }
        }
    }
}
