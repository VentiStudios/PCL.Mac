//
//  MyTipComponent.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/20.
//

import SwiftUI

struct MyTipComponent: View {
    let text: String
    let color: TipColor
    
    var body: some View {
        HStack {
            Rectangle()
                .frame(width: 3)
                .foregroundStyle(color.borderColor)
            Text(text)
                .font(.custom("PCL English", size: 14))
                .foregroundStyle(color.textColor)
                .padding(EdgeInsets(top: 9, leading: 0, bottom: 9, trailing: 12))
        }
        .fixedSize()
        .background(color.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

enum TipColor {
    case blue, red, yellow
    
    fileprivate var backgroundColor: Color {
        switch self {
        case .blue: Color(hex: 0xD9ECFF, alpha: 0.7)
        case .red: Color(hex: 0xFFDDDF, alpha: 0.7)
        case .yellow: Color(hex: 0xFFEBD7, alpha: 0.4)
        }
    }
    
    fileprivate var borderColor: Color {
        switch self {
        case .blue: Color(hex: 0x1172D4)
        case .red: Color(hex: 0xD82929)
        case .yellow: Color(hex: 0xF57A00)
        }
    }
    
    fileprivate var textColor: Color {
        switch self {
        case .blue: Color(hex: 0x0F64B8)
        case .red: Color(hex: 0xBF0B0B)
        case .yellow: Color(hex: 0xD86C00)
        }
    }
}

#Preview {
    MyTipComponent(text: "这是一行测试文本\nawa", color: .blue)
        .padding()
        .background(Theme.pcl.getBackgroundStyle())
}
