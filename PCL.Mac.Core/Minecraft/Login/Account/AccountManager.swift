//
//  AccountManager.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/6/29.
//

import Foundation
import SwiftyJSON

public protocol Account: Codable, Identifiable {
    var id: UUID { get }
    var uuid: UUID { get }
    var name: String { get }
    func putAccessToken(options: LaunchOptions) async
}

public enum AnyAccount: Account, Identifiable, Equatable {
    case offline(OfflineAccount)
    case microsoft(MicrosoftAccount)
    case yggdrasil(YggdrasilAccount)
    
    private var account: any Account {
        switch self {
        case .offline(let account): return account
        case .microsoft(let account): return account
        case .yggdrasil(let account): return account
        }
    }
    
    public var id: UUID { account.id }
    public var uuid: UUID { account.uuid }
    public var name: String { account.name }
    
    public static func == (lhs: AnyAccount, rhs: AnyAccount) -> Bool {
        lhs.id == rhs.id
    }
    
    public func putAccessToken(options: LaunchOptions) async { await account.putAccessToken(options: options) }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum AccountType: String, Codable { case offline, microsoft, yggdrasil }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(AccountType.self, forKey: .type) {
        case .offline:    self = .offline(try container.decode(OfflineAccount.self, forKey: .payload))
        case .microsoft:  self = .microsoft(try container.decode(MicrosoftAccount.self, forKey: .payload))
        case .yggdrasil:  self = .yggdrasil(try container.decode(YggdrasilAccount.self, forKey: .payload))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .offline(let value):
            try container.encode(AccountType.offline, forKey: .type)
            try container.encode(value, forKey: .payload)
        case .microsoft(let value):
            try container.encode(AccountType.microsoft, forKey: .type)
            try container.encode(value, forKey: .payload)
        case .yggdrasil(let value):
            try container.encode(AccountType.yggdrasil, forKey: .type)
            try container.encode(value, forKey: .payload)
        }
    }
    
    public func getSkinData() async throws -> Data {
        let url: URL
        switch self {
        case .offline(_), .microsoft(_):
            url = URL(string: "https://crafatar.com/skins/\(uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased())")!
        case .yggdrasil(let yggdrasilAccount):
            let textures = try await yggdrasilAccount.client.getProfile(id: yggdrasilAccount.uuid).properties["textures"]!
            let json = try JSON(data: Data(base64Encoded: textures) ?? .init())
            url = URL(string: json["textures"]["SKIN"]["url"].stringValue)!
        }
        
        return try await Requests.get(url).getDataOrThrow()
    }
}

public class AccountManager: ObservableObject {
    public static let shared: AccountManager = .init()
    
    @CodableAppStorage("accounts") public var accounts: [AnyAccount] = []
    
    @CodableAppStorage("accountId") public var accountId: UUID? = nil
    
    public func getAccount() -> AnyAccount? {
        if accountId == nil {
            if let id = accounts.first?.id {
                accountId = id
            } else {
                return nil
            }
        }
        
        if let account = accounts.first(where: { $0.id == accountId }) {
            return account
        }
        
        warn("accountId 对应的账号不存在！")
        accountId = nil
        return nil
    }
}
