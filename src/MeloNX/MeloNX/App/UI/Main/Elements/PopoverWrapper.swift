//
//  PopoverWrapper.swift
//  MeloNX
//
//  Created by Stossy11 on 30/07/2025.
//

import SwiftUI
import UIKit

class PopoverPresentationMode: ObservableObject {
    private let dismissAction: () -> Void
    
    init(dismissAction: @escaping () -> Void) {
        self.dismissAction = dismissAction
    }
    
    func dismiss() {
        dismissAction()
    }
}

class CenteredPopoverWrapper: UIView {
    private let hostingController: UIHostingController<AnyView>
    private var onDismiss: (() -> Void)?
    private let backgroundView = UIView()
    private let originalContent: AnyView
    
    private var popoverSize: CGSize = .zero
    private var hasInitialSize = false
    
    private var sizeObservation: NSKeyValueObservation?
    
    private let maxWidthRatio: CGFloat = 0.9
    private let maxHeightRatio: CGFloat = 0.8
    private let minWidth: CGFloat = 300
    private let minHeight: CGFloat = 200
    
    init<Content: View>(rootView: Content, onDismiss: (() -> Void)? = nil) {
        self.originalContent = AnyView(rootView)
        self.hostingController = UIHostingController(rootView: AnyView(rootView))
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        setup()
        observeContentSize()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        backgroundColor = UIColor.clear
        
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backgroundView.alpha = 0
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tap)
        addSubview(backgroundView)
        
        let containerView = UIView()
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = false
        containerView.backgroundColor = .clear
        
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.3
        containerView.layer.shadowRadius = 20
        containerView.layer.shadowOffset = CGSize(width: 0, height: 8)
        
        hostingController.view.layer.cornerRadius = 20
        hostingController.view.layer.masksToBounds = true
        hostingController.view.backgroundColor = .systemBackground
        
        let presentationMode = PopoverPresentationMode { [weak self] in
            self?.dismiss()
        }
        
        let dismissAction = PopoverDismissAction { [weak self] in
            self?.dismiss()
        }
        
        let wrappedContent = NavigationView {
            originalContent
                .environmentObject(presentationMode)
                .environment(\.dismissPopover, dismissAction)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        
        hostingController.rootView = AnyView(wrappedContent)
        
        containerView.addSubview(hostingController.view)
        addSubview(containerView)
        
        containerView.tag = 999
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
    }
    
    private func observeContentSize() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.superview != nil else {
                timer.invalidate()
                return
            }
            
            self.updateSizeIfNeeded()
        }
        
        sizeObservation = hostingController.view.observe(\.intrinsicContentSize, options: [.new]) { [weak self] view, change in
            guard let self = self else { return }
           Task { @MainActor in
                self.updateSizeIfNeeded()
            }
        }
    }
    
    private func updateSizeIfNeeded() {
        guard let superview = self.superview else { return }
        
        let maxWidth = superview.bounds.width * maxWidthRatio
        let maxHeight = superview.bounds.height * maxHeightRatio
        
        let targetSize = CGSize(width: maxWidth, height: maxHeight)
        let fittingSize = hostingController.view.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        var newSize = fittingSize
        
        newSize.width = max(newSize.width, minWidth)
        newSize.height = max(newSize.height, minHeight)
        
        if newSize.width > maxWidth {
            newSize.width = maxWidth
        }
        if newSize.height > maxHeight {
            newSize.height = maxHeight
        }
        
        if newSize.width < minWidth || newSize.height < minHeight {
            newSize = CGSize(width: maxWidth * 0.8, height: maxHeight * 0.6)
            hasInitialSize = false
        } else {
            hasInitialSize = true
        }
        
        if abs(popoverSize.width - newSize.width) > 1 || abs(popoverSize.height - newSize.height) > 1 {
            popoverSize = newSize
            setNeedsLayout()
            
            if hasInitialSize {
                UIView.animate(withDuration: 0.25, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.layoutIfNeeded()
                }
            } else {
                layoutIfNeeded()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        
        guard let containerView = viewWithTag(999) else { return }
        
        guard popoverSize != .zero else {
            let defaultWidth = bounds.width * 0.8
            let defaultHeight = bounds.height * 0.6
            let x = (bounds.width - defaultWidth) / 2
            let y = (bounds.height - defaultHeight) / 2
            containerView.frame = CGRect(x: x, y: y, width: defaultWidth, height: defaultHeight)
            hostingController.view.frame = containerView.bounds
            return
        }
        
        let x = (bounds.width - popoverSize.width) / 2
        let y = (bounds.height - popoverSize.height) / 2
        
        containerView.frame = CGRect(origin: CGPoint(x: x, y: y), size: popoverSize)
        hostingController.view.frame = containerView.bounds
    }
    
    @objc private func backgroundTapped() {
        dismiss()
    }
    
    func present(in containerView: UIView, animated: Bool = true) {
        frame = containerView.bounds
        containerView.addSubview(self)
        
        guard let popoverContainer = viewWithTag(999) else { return }
        
        popoverContainer.alpha = 0
        popoverContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            .concatenating(CGAffineTransform(translationX: 0, y: 50))
        
        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.backgroundView.alpha = 1
                popoverContainer.alpha = 1
                popoverContainer.transform = .identity
            }
        } else {
            backgroundView.alpha = 1
            popoverContainer.alpha = 1
            popoverContainer.transform = .identity
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateSizeIfNeeded()
        }
    }
    
    func dismiss(animated: Bool = true) {
        guard let popoverContainer = viewWithTag(999) else {
            removeFromSuperview()
            onDismiss?()
            return
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                self.backgroundView.alpha = 0
                popoverContainer.alpha = 0
                popoverContainer.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    .concatenating(CGAffineTransform(translationX: 0, y: 30))
            }) { _ in
                self.removeFromSuperview()
                self.onDismiss?()
            }
        } else {
            removeFromSuperview()
            onDismiss?()
        }
    }
    
    deinit {
        sizeObservation?.invalidate()
    }
}

struct PopoverUIKit<Content: View>: UIViewRepresentable {
    @Binding var isPresented: Bool
    let content: Content
    
    class Coordinator {
        var popover: CenteredPopoverWrapper?
        var isPresented: Binding<Bool>
        
        init(isPresented: Binding<Bool>) {
            self.isPresented = isPresented
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    func makeUIView(context: Context) -> UIView {
        UIView()
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let window = AppDelegate.window else { return }
        
        if isPresented {
            if context.coordinator.popover == nil {
                let popover = CenteredPopoverWrapper(rootView: content) {
                   Task { @MainActor in
                        context.coordinator.isPresented.wrappedValue = false
                    }
                }
                context.coordinator.popover = popover
                popover.present(in: window)
            }
        } else {
            context.coordinator.popover?.dismiss()
            context.coordinator.popover = nil
        }
    }
}

extension View {
    func popoverUIKit<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        background(
            PopoverUIKit(isPresented: isPresented, content: content())
                .frame(width: 0, height: 0)
        )
    }
}

private struct PopoverPresentationModeKey: EnvironmentKey {
    static let defaultValue: PopoverPresentationMode? = nil
}

extension EnvironmentValues {
    var popoverPresentationMode: PopoverPresentationMode? {
        get { self[PopoverPresentationModeKey.self] }
        set { self[PopoverPresentationModeKey.self] = newValue }
    }
}

extension View {
    func onPopoverDismiss(_ action: @escaping () -> Void) -> some View {
        self.environmentObject(PopoverPresentationMode(dismissAction: action))
    }
}

fileprivate func dismissPopover() {
   Task { @MainActor in
       if let window = AppDelegate.window {
           
           func findPopover(in view: UIView) -> CenteredPopoverWrapper? {
               if let popover = view as? CenteredPopoverWrapper {
                   return popover
               }
               for subview in view.subviews {
                   if let found = findPopover(in: subview) {
                       return found
                   }
               }
               return nil
           }
           
           if let popover = findPopover(in: window) {
               popover.dismiss()
           }
       }
    }
}

struct PopoverDismissAction {
    private let action: () -> Void
    
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    
    func callAsFunction() {
        action()
    }
}

private struct PopoverDismissKey: EnvironmentKey {
    static let defaultValue = PopoverDismissAction { dismissPopover() }
}

extension EnvironmentValues {
    var dismissPopover: PopoverDismissAction {
        get { self[PopoverDismissKey.self] }
        set { self[PopoverDismissKey.self] = newValue }
    }
}
