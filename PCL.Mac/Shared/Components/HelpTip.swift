//
//  HelpTip.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/26.
//

import SwiftUI

struct HelpTip: View {
    @ObservedObject private var overlayManager: OverlayManager = .shared
    
    @State private var overlayId: UUID?
    
    let text: String
    
    var body: some View {
        MyGeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Color("TextColor"), style: .init(lineWidth: 1.5))
                Image(systemName: "questionmark")
                    .foregroundStyle(Color("TextColor"))
                    .bold()
            }
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .onHover { isHovered in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isHovered {
                        if let geo = geo {
                            let frame = geo.frame(in: .global)
                            overlayId = overlayManager.addOverlay(view: TextView(text: text), at: CGPoint(x: frame.midX, y: frame.maxY + frame.height))
                        }
                    } else if let overlayId = overlayId {
                        overlayManager.removeOverlay(with: overlayId)
                    }
                }
            }
        }
    }
}

fileprivate struct TextView: View {
    let text: String
    
    var body: some View {
        ZStack {
            
            Text(text)
                .font(.custom("PCL English", size: 14))
                .foregroundStyle(Color("TextColor"))
                .padding(4)
                .frame(maxWidth: 400)
                .lineLimit(nil)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("MyCardBackgroundColor"))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color("TextColor"), style: .init(lineWidth: 2))
                }
        }
        .shadow(color: Color("TextColor").opacity(0.2), radius: 4)
    }
}

#Preview {
    TextView(text: "awa!")
        .padding()
}
