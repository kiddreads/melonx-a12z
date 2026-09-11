//
//  MetalViewContainer.swift
//  MeloNX
//
//  Created by Stossy11 on 06/07/2025.
//

import SwiftUI

struct MetalViewContainer: View {
    var hudView: AnyView
    
    init(isPortrait: Binding<Bool>, @ViewBuilder hudView: @escaping () -> some View) {
        self.hudView = AnyView(hudView())
        _isPortrait = isPortrait
    }
    
    @EnvironmentObject var ryujinx: Ryujinx
    @EnvironmentObject var gameHandler: LaunchGameHandler
    
    @State private var targetSize1: CGSize = .zero
    @Binding var isPortrait: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                
                VStack {
                    MetalView()
                        .frame(width: targetSize1.width,
                               height: targetSize1.height)
                        .allowsHitTesting(true)
                        .ignoresSafeArea(.container,
                                         edges: !isPortrait ? .all : .horizontal)
                    
                    if isPortrait {
                        hudView
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isPortrait ? .top : .center)
            .onAppear {
                getSize()
            }
            .onChange(of: geo.size) { newSize in
                getSize()
            }
            .onChange(of: ryujinx.aspectRatio) { _ in
                getSize()
            }
        }
    }
    

    
    func getSize() {
        targetSize1 = targetSize(ryujinx: ryujinx)
                                 
        guard let window = AppDelegate.window else { return }
        gameHandler.isPortrait = window.bounds.size.height > window.bounds.size.width
        isPortrait = gameHandler.isPortrait
    }
}



func targetSize(for containerSize: CGSize? = nil, ryujinx: Ryujinx) -> CGSize {
    var targetAspect: CGFloat
    
    guard let window = AppDelegate.window else { return containerSize ?? .zero }
    
    let containerSize = containerSize ?? window.frame.size
    let ratio = ryujinx.aspectRatio
    
    switch ratio {
    case .fixed4x3:
        targetAspect = 4.0 / 3.0
    case .fixed16x9:
        targetAspect = 16.0 / 9.0
    case .fixed16x10:
        targetAspect = 16.0 / 10.0
    case .fixed21x9:
        targetAspect = 21.0 / 9.0
    case .fixed32x9:
        targetAspect = 32.0 / 9.0
    case .stretched:
        return containerSize
    }
    
    let containerAspect = containerSize.width / containerSize.height
    
    if containerAspect > targetAspect {
        // Container is wider than target - fit to height
        let targetHeight = containerSize.height
        let targetWidth = targetHeight * targetAspect
        return CGSize(width: targetWidth, height: targetHeight)
    } else {
        // Container is taller than target - fit to width
        let targetWidth = containerSize.width
        let targetHeight = targetWidth / targetAspect
        return CGSize(width: targetWidth, height: targetHeight)
    }
}

func isScreenAspectRatio(_ targetWidth: CGFloat, _ targetHeight: CGFloat, tolerance: CGFloat = 0.05) -> Bool {
    let screenSize = UIScreen.main.bounds.size
    let width = max(screenSize.width, screenSize.height)
    let height = min(screenSize.width, screenSize.height)

    let actualRatio = width / height
    let targetRatio = targetWidth / targetHeight

    return abs(actualRatio - targetRatio) < tolerance
}


