//
//  PreviewView.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/11.
//

import SwiftUI

struct PreviewView: View {
    var body: some View {
        ZStack {
            Spacer()
            ContentView()
                .cornerRadius(10)
                .frame(width: 815, height: 465)
                .background(WindowAccessor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Image("Wallpaper")
                .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
        )
    }
}

#Preview {
    PreviewView()
        //.frame(width: 1000, height: 1000)
}
