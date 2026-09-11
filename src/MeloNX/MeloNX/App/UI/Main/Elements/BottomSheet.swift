//
//  BottomSheet.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import SwiftUI
import UIKit

extension View {
    func halfScreenSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.background(
            HalfScreenSheetPresenter(
                isPresented: isPresented,
                content: content
            )
        )
    }
}

struct HalfScreenSheetPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content
    
    class Coordinator {
        var halfScreenController: HalfScreenViewController<Content>?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            if uiViewController.presentedViewController == nil {
                let halfScreenController = HalfScreenViewController(
                    content: content(),
                    onDismiss: { isPresented = false }
                )
                context.coordinator.halfScreenController = halfScreenController
                halfScreenController.modalPresentationStyle = .overFullScreen
                halfScreenController.modalTransitionStyle = .crossDissolve
                uiViewController.present(halfScreenController, animated: true)
            } else if let existing = context.coordinator.halfScreenController {
                existing.updateContent(content())
            }
        } else {
            uiViewController.presentedViewController?.dismiss(animated: true)
        }
    }
}



class HalfScreenViewController<Content: View>: UIViewController {
    private let content: Content
    private let onDismiss: () -> Void
    private var blurView: UIVisualEffectView!
    private var contentView: UIView!
    private var hostingController: UIHostingController<Content>!
    private var contentHeightConstraint: NSLayoutConstraint!

    
    init(content: Content, onDismiss: @escaping () -> Void) {
        self.content = content
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupGestures()
    }
    
    func updateContent(_ newContent: Content) {
        hostingController.rootView = newContent
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
    }
    
    private func setupViews() {
        view.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        blurView = UIVisualEffectView(effect: blurEffect)
        blurView.alpha = 0.89
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)
        
        contentView = UIView()
        contentView.backgroundColor = self.traitCollection.userInterfaceStyle == .dark ? UIColor.systemGray5 : UIColor.gray
        // contentView.layer.cornerRadius = 20
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
        
        hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        contentView.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: contentView.topAnchor),

            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 0)
        contentHeightConstraint.isActive = true

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissSheet))
        blurView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissSheet() {
        onDismiss()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                contentView.transform = CGAffineTransform(translationX: 0, y: translation.y)
            }
        case .ended:
            if translation.y > 100 || velocity.y > 500 {
                dismissSheet()
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.contentView.transform = .identity
                }
            }
        default:
            break
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let isPhone = UIDevice.current.userInterfaceIdiom == .phone && view.bounds.width > view.bounds.height
        let multiplier: CGFloat = isPhone ? 0.75 : 0.5
        contentHeightConstraint.constant = view.bounds.height * multiplier
    }

}
