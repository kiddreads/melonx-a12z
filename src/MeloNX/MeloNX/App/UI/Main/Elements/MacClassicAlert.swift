//
//  MacClassicAlert.swift
//  MeloNX
//
//  Created by Stossy11 on 08/11/2025.
//

import Foundation

final class MacClassicAlertViewController: UIViewController {
    private let alertTitle: String
    private let message: String
    private let imageName: String
    private let completion: (() -> Void)?
    
    init(title: String, message: String, imageName: String, completion: (() -> Void)?) {
        self.alertTitle = title
        self.message = message
        self.imageName = imageName
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.clear
        
        
        let effect: UIVisualEffect
        if #available(iOS 19, *), !NativeSettingsManager.shared.disableLiquidGlass.value {
            effect = UIGlassEffect(style: .regular)
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        
        let visualEffect = UIVisualEffectView(effect: effect)
        visualEffect.backgroundColor = .clear
        visualEffect.layer.cornerRadius = 20
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffect)
        
        let container = visualEffect.contentView
        
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(imageLiteralResourceName: imageName)
        container.addSubview(imageView)
        
        let titleLabel = UILabel()
        titleLabel.text = alertTitle
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(messageLabel)
        
        let okButton = UIButton(type: .system)
        okButton.setTitle("OK", for: .normal)
        okButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.addTarget(self, action: #selector(dismissAlert), for: .touchUpInside)
        container.addSubview(okButton)
        
        NSLayoutConstraint.activate([
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.widthAnchor.constraint(equalToConstant: 280),
            
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 80),
            imageView.widthAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            okButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            okButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            okButton.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])
    }
    
    @objc private func dismissAlert() {
        dismiss(animated: true) {
            self.completion?()
        }
    }
}

