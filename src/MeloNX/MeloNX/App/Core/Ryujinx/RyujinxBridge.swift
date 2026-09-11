//
//  RyujinxBridge.swift
//  MeloNX
//
//  Created by Stossy11 on 30/09/2025.
//

import Foundation

final class RyujinxBridge {
    static func initialize() {
        SN_initialize()
    }
    
    static func initialize_dualmapped() -> Bool {
        SN_initialize_dualmapped()
    }

    static func getGameInfo(arg0: Int32, arg1: NSString) -> GameInfo {
        let arg1Ptr = UnsafeMutablePointer<CChar>(mutating: arg1.utf8String)
        return SN_get_game_info(arg0, arg1Ptr)
    }

    static func getDlcList(titleId: String, path: String) -> DlcNcaList {
        titleId.withCString { titlePtr in
            path.withCString { pathPtr in
                return SN_get_dlc_nca_list(titlePtr, pathPtr)
            }
        }
    }

    static func installFirmware(at path: String) -> (string: String, isError: Bool) {
        guard let firmware = (path.withCString { SN_install_firmware($0) }) else { return ("Failed to get error.", true) }
        var string = String(cString: firmware)
        let isErr = string.hasSuffix("✖")
        string.removeLast()
        defer { SN_free_firmware_version(firmware) }
        return (string, isErr)
    }

    static var installedFirmwareVersion: String {
        guard let firmware = SN_installed_firmware_version() else { return "" }
        defer { SN_free_firmware_version(firmware) }
        return String(cString: firmware)
    }

    static func pauseEmulation(_ shouldPause: Bool) {
        SN_pause_emulation(shouldPause)
    }

    static func stopEmulation() {
        SN_stop_emulation()
    }

    static func mainRyu(argv: [String]) -> Int {
        return argv.withCStrings { cStrings, argc in
            Int(SN_main_ryujinx_sdl(argc, cStrings))
        }
    }
    
    static func changeControllerInfo(argv: [String]) {
        argv.withCStrings { cStrings, argc in
            SN_set_gamepad_configuration(argc, cStrings)
        }
    }

    static func updateSettingsExternal(argv: [String]) -> Int {
        return argv.withCStrings { cStrings, argc in
            Int(SN_update_settings_external(argc, cStrings))
        }
    }
    
    static func setViewSize(width: Int, height: Int) {
        SN_set_view_size(Int32(width), Int32(height))
    }

    static var currentFPS: Int {
        Int(SN_get_current_fps())
    }
    
    static var currentVolume: Float {
        get {
            SN_get_game_volume()
        } set {
            SN_set_game_volume(newValue)
        }
    }


    static func touchBegan(x: Float, y: Float, index: Int) {
        SN_touch_began(x, y, Int32(index))
    }

    static func touchMoved(x: Float, y: Float, index: Int) {
        SN_touch_moved(x, y, Int32(index))
    }

    static func touchEnded(index: Int) {
        SN_touch_ended(Int32(index))
    }

    static func setNativeWindow(_ layerPtr: UnsafeMutableRawPointer) {
        SN_set_native_window(layerPtr)
    }

    static func refreshAccountManager() {
        SN_refresh_account_manager()
    }

    static func createAccount(name: String, image: Data) {
        name.withCString { namePtr in
            image.withUnsafeBytes { bufferpointer in
                let imagePtr = bufferpointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                SN_create_account(namePtr, imagePtr, Int32(image.count))
            }
        }
    }

    static func openUser(userId: String) {
        userId.withCString { SN_open_user($0) }
    }

    static func closeUser(userId: String) {
        userId.withCString { SN_close_user($0) }
    }
    
    static func attachGamepad(_ id: UnsafeMutableRawPointer?, _ name: String) {
        _ = name.withCString { SN_attach_gamepad($0, id)  }
    }
    
    static func detachGamepad(_ id: UnsafeMutableRawPointer?) {
        SN_detach_gamepad(id)
    }

    static func setGamepadButtonState(_ id: UnsafeMutableRawPointer?, buttonId: Int, pressed: Bool) {
        print("Gamepad button State \(Int32(buttonId)), pressed \(pressed)")
        SN_set_gamepad_button_state(id, Int32(buttonId), pressed ? 1 : 0)
    }

    static func setGamepadStickAxis(_ id: UnsafeMutableRawPointer?, stickId: Int, x: Float, y: Float) {
        SN_set_gamepad_stick_axis(id, Int32(stickId), x, y)
    }
    
    static func setGamepadMotion(_ id: UnsafeMutableRawPointer?, motionType: Int, axis: SIMD3<Float>) {
        SN_set_gamepad_motion_axis(id, Int32(motionType), axis.x, axis.y, axis.z)
    }

    static var avatars: AvatarArray {
        SN_get_avatars()
    }
}

fileprivate extension Array where Element == String {
    func withCStrings<R>(_ body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, Int32) -> R) -> R {
        var cStrings = map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        return cStrings.withUnsafeMutableBufferPointer { buf in
            guard let base = buf.baseAddress else {
                fatalError("Failed to get baseAddress")
            }
            return body(base, Int32(count))
        }
    }
}



// SN stands for silgen name because functions with the same definition like initialize and RyujinxBridge.initialize it kept pointing it to itself.
// could've just done MeloNX.initialize but meh
@_silgen_name("get_game_info")
func SN_get_game_info(_ arg0: Int32, _ arg1: UnsafeMutablePointer<CChar>!) -> GameInfo

@_silgen_name("get_dlc_nca_list")
func SN_get_dlc_nca_list(_ titleIdPtr: UnsafePointer<CChar>!, _ pathPtr: UnsafePointer<CChar>!) -> DlcNcaList

@_silgen_name("install_firmware")
func SN_install_firmware(_ inputPtr: UnsafePointer<CChar>!) -> UnsafeMutablePointer<CChar>!

@_silgen_name("installed_firmware_version")
func SN_installed_firmware_version() -> UnsafeMutablePointer<CChar>!

@_silgen_name("set_native_window")
func SN_set_native_window(_ layerPtr: UnsafeMutableRawPointer!)

@_silgen_name("pause_emulation")
func SN_pause_emulation(_ shouldPause: Bool)

@_silgen_name("stop_emulation")
func SN_stop_emulation()

@_silgen_name("initialize")
func SN_initialize()

@_silgen_name("initialize-dualmapped")
func SN_initialize_dualmapped() -> Bool

@_silgen_name("main_ryujinx_sdl")
func SN_main_ryujinx_sdl(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32

@_silgen_name("set_gamepad_configuration")
func SN_set_gamepad_configuration(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!)

@_silgen_name("update_settings_external")
func SN_update_settings_external(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>!) -> Int32

@_silgen_name("get_current_fps")
func SN_get_current_fps() -> Int32

@_silgen_name("get_game_volume")
func SN_get_game_volume() -> Float

@_silgen_name("set_game_volume")
func SN_set_game_volume(_ vol: Float)

@_silgen_name("touch_began")
func SN_touch_began(_ x: Float, _ y: Float, _ index: Int32)

@_silgen_name("touch_moved")
func SN_touch_moved(_ x: Float, _ y: Float, _ index: Int32)

@_silgen_name("touch_ended")
func SN_touch_ended(_ index: Int32)

@_silgen_name("refresh_account_manager")
func SN_refresh_account_manager()

@_silgen_name("create_account")
func SN_create_account(_ name: UnsafePointer<CChar>!, _ image: UnsafePointer<UInt8>!, _ imagelength: Int32)

@_silgen_name("open_user")
func SN_open_user(_ userid: UnsafePointer<CChar>!)

@_silgen_name("close_user")
func SN_close_user(_ userid: UnsafePointer<CChar>!)

@_silgen_name("get_avatars")
func SN_get_avatars() -> AvatarArray

@_silgen_name("set_view_size")
func SN_set_view_size(_ width: Int32, _ height: Int32)

@_silgen_name("attach_gamepad")
func SN_attach_gamepad(_ namePtr: UnsafePointer<CChar>?, _ idPtr: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("detach_gamepad")
func SN_detach_gamepad(_ idPtr: UnsafeMutableRawPointer?)

@_silgen_name("set_gamepad_button_state")
func SN_set_gamepad_button_state(_ idPtr: UnsafeMutableRawPointer?, _ buttonId: Int32, _ pressed: UInt8)

@_silgen_name("set_gamepad_stick_axis")
func SN_set_gamepad_stick_axis(_ idPtr: UnsafeMutableRawPointer?, _ stickId: Int32, _ x: Float, _ y: Float)

@_silgen_name("set_gamepad_motion_axis")
func SN_set_gamepad_motion_axis(_ idPtr: UnsafeMutableRawPointer?, _ motionType: Int32, _ x: Float, _ y: Float, _ z: Float)

@_silgen_name("free_game_info")
func SN_free_game_info(_ gameInfo: GameInfo)

@_silgen_name("free_firmware_version")
func SN_free_firmware_version(_ gameInfo: UnsafeMutablePointer<CChar>!)
