//
//  OverlayManager.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/26.
//

import SwiftUI

class OverlayItem: Identifiable, Equatable {
    let id = UUID()
    let view: AnyView
    let position: CGPoint
    var viewSize: CGSize?
    
    static func == (lhs: OverlayItem, rhs: OverlayItem) -> Bool { lhs.id == rhs.id }
    
    init(view: AnyView, position: CGPoint, viewSize: CGSize? = nil) {
        self.view = view
        self.position = position
        self.viewSize = viewSize
    }
}

class OverlayManager: ObservableObject {
    public static let shared: OverlayManager = .init()
    
    private init() {}
    
    @Published var overlays: [OverlayItem] = []
    
    func addOverlay(view: some View, at position: CGPoint) -> UUID {
        let item = OverlayItem(view: AnyView(view), position: position)
        overlays.append(item)
        return item.id
    }
    
    func removeOverlay(with id: UUID) {
        overlays.removeAll { $0.id == id }
    }
}
