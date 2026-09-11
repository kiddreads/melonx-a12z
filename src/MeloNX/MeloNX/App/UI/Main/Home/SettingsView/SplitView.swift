//
//  SplitViewController.swift
//  MeloNX
//
//  Created by Stossy11 on 10/11/2025.
//

import Foundation
import SwiftUI

class SplitViewController: UISplitViewController {
    private let sidebarViewController: UIViewController
    private let contentViewController: UIViewController
    
    init(sidebarViewController: UIViewController, contentViewController: UIViewController) {
        self.sidebarViewController = sidebarViewController
        self.contentViewController = contentViewController
        super.init(style: .doubleColumn)
        
        self.preferredDisplayMode = .oneBesideSecondary
        self.preferredSplitBehavior = .tile
        self.presentsWithGesture = true
        
        self.setViewController(sidebarViewController, for: .primary)
        self.setViewController(contentViewController, for: .secondary)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.primaryBackgroundStyle = .sidebar
        
        let displayModeButtonItem = self.displayModeButtonItem
        contentViewController.navigationItem.leftBarButtonItem = displayModeButtonItem
    }
    
    func showSidebar() {
        self.preferredDisplayMode = .oneBesideSecondary
    }
    
    func hideSidebar() {
        self.preferredDisplayMode = .secondaryOnly
    }
    
    func toggleSidebar() {
        if self.displayMode == .oneBesideSecondary {
            self.preferredDisplayMode = .secondaryOnly
        } else {
            self.preferredDisplayMode = .oneBesideSecondary
        }
    }
}

struct SidebarView<Content: View>: View {
    var sidebar: () -> AnyView
    var content: () -> Content
    @Binding var showSidebar: Bool
    
    init(sidebar: @escaping () -> AnyView, content: @escaping () -> Content, showSidebar: Binding<Bool>) {
        self.sidebar = sidebar
        self.content = content
        self._showSidebar = showSidebar
    }
    
    var body: some View {
        SidebarViewRepresentable(
            sidebar: sidebar(),
            content: content(),
            showSidebar: $showSidebar
        )
    }
}

struct SidebarViewRepresentable<Sidebar: View, Content: View>: UIViewControllerRepresentable {
    var sidebar: Sidebar
    var content: Content
    @Binding var showSidebar: Bool
    
    func makeUIViewController(context: Context) -> SplitViewController {
        let sidebarVC = UIHostingController(rootView: sidebar)
        let contentVC = UINavigationController(rootViewController: UIHostingController(rootView: content))
        
        let splitVC = SplitViewController(sidebarViewController: sidebarVC, contentViewController: contentVC)
        splitVC.setOverrideTraitCollection(
            UITraitCollection(horizontalSizeClass: .regular),
            forChild: splitVC
        )
        return splitVC
    }
    
    func updateUIViewController(_ uiViewController: SplitViewController, context: Context) {
        if let sidebarVC = uiViewController.viewController(for: .primary) as? UIHostingController<Sidebar> {
            sidebarVC.rootView = sidebar
        }
        if let navController = uiViewController.viewController(for: .secondary) as? UINavigationController,
           let contentVC = navController.topViewController as? UIHostingController<Content> {
            contentVC.rootView = content
        }
        
        if showSidebar {
            uiViewController.showSidebar()
        } else {
            uiViewController.hideSidebar()
        }
    }
    
    static func dismantleUIViewController(_ uiViewController: SplitViewController, coordinator: Coordinator) {
    }
}
