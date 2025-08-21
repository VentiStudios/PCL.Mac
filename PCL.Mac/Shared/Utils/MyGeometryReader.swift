//
//  MyGeometryReader.swift
//  PCL.Mac
//
//  Created by YiZhiMCQiu on 2025/7/26.
//

import SwiftUI

struct MyGeometryReader<Content: View>: View {
    @State private var geometry: GeometryProxy?
    
    private let content: (GeometryProxy?) -> Content
    
    init(@ViewBuilder content: @escaping (GeometryProxy?) -> Content) {
        self.content = content
    }
    
    var body: some View {
        content(geometry)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            geometry = geo
                        }
                }
            )
    }
}
