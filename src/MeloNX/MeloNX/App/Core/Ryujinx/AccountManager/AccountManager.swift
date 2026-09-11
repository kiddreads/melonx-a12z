//
//  Accounts.swift
//  MeloNX
//
//  Created by Stossy11 on 17/07/2025.
//

import Foundation

class AccountManager {
    static func createAccount(name: String, imageData: Data) {
        RyujinxBridge.createAccount(name: name, image: imageData)
    }
    
    static func openUser(_ id: String) {
        RyujinxBridge.openUser(userId: id)
    }
    
    static func closeUser(_ id: String) {
        RyujinxBridge.closeUser(userId: id)
    }
    
    static func getFirmwareIcons() -> [Avatar] {
        let avatarArray = RyujinxBridge.avatars
        let count = Int(avatarArray.Count)
        var result: [Avatar] = []
        
        guard let avatarsPtr = avatarArray.Avatars else {
            return []
        }

        for i in 0..<count {
            let avatar = avatarsPtr.advanced(by: i).pointee
            
            if let imageDataPtr = avatar.ImageData {
                let imageSize = Int(avatar.ImageSize)
                let image = imageFromRawRGBA(Data(bytes: imageDataPtr, count: imageSize))
                
                let filename = avatar.FileName != nil ? String(cString: avatar.FileName!) : ""
                
                
                result.append(Avatar(icon: image ?? UIImage(), name: filename))
            }
        }
        
        return result
    }
    
    private static func imageFromRawRGBA(_ data: Data, width: Int = 256, height: Int = 256) -> UIImage? {
        guard data.count == width * height * 4 else {
            return nil
        }

        let cfData = data as CFData
        guard let provider = CGDataProvider(data: cfData) else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.last.rawValue | // RGBA (not premultiplied)
            CGBitmapInfo.byteOrder32Big.rawValue // Make sure it's big endian RGBA
        )

        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

extension UIImage {
    func jpgData(compressionQuality: CGFloat = 1.0) -> Data? {
        return self.jpegData(compressionQuality: compressionQuality)
    }
}
