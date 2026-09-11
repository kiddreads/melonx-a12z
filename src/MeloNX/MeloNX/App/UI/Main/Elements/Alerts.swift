//
//  Alerts.swift
//  MeloNX
//
//  Created by Stossy11 on 04/07/2025.
//

import UIKit

func showAlert(_ viewController: UIViewController? = nil,
    title: String?,
    message: String?,
    actions: [(title: String, style: UIAlertAction.Style, handler: (() -> Void)?)]) {
    
    
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

    for action in actions {
        let uiAction = UIAlertAction(title: action.title, style: action.style) { _ in
            action.handler?()
        }
        alert.addAction(uiAction)
    }
    
    if Thread.isMainThread {
        let coolVC = viewController ?? UIApplication.shared.windows.first?.rootViewController!
        coolVC!.present(alert, animated: true, completion: nil)
    } else {
        DispatchQueue.main.async {
            let coolVC = viewController ?? UIApplication.shared.windows.first?.rootViewController!
            coolVC!.present(alert, animated: true, completion: nil)
        }
    }
}
