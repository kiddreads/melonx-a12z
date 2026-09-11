//
//  ContentView.swift
//  MeloNX
//
//  Created by Stossy11 on 09/11/2025.
//

import OSLog
import SwiftUI

struct ContentView: View {
    @StateObject var gameHandler = LaunchGameHandler()
    @StateObject var controllerManager = ControllerManager.shared
    @StateObject var ryujinx = Ryujinx.shared
    @Namespace var gameAnimation
    @State private var selectedTab: Tab = .games
    @State var showing = true
    @Binding var viewShown: Bool
    @State var date: Date?

    @StateObject var nativeSettings: NativeSettingsManager = .shared

    @AppStorage("gametorun") var gametorun: String = ""
    @AppStorage("gametorun-date") var gametorunDate: String = ""

    private var shouldLaunchGameBinding: Binding<Bool> {
        .init(get: { gameHandler.shouldLaunchGame }, set: { _ in })
    }

    private var shouldShowEntitlementBinding: Binding<Bool> {
        .init(get: { gameHandler.shouldShowEntitlement }, set: { _ in })
    }

    private var shouldCheckJITBinding: Binding<Bool> {
        .init(get: { gameHandler.shouldCheckJIT }, set: { _ in })
    }

    private var shouldShowPopoverBinding: Binding<Bool> {
        .init(get: { gameHandler.shouldShowPopover }, set: { _ in })
    }

    @ViewBuilder
    var tabView: some View {
        if #available(iOS 19, *), nativeSettings.disableLiquidGlass.value, UIDevice.current.userInterfaceIdiom == .phone {
            Pre26TabView(selectedIndex: $selectedTab, items: [
                Pre26TabItem(title: "Library", image: "gamecontroller.fill", view: { GamesListView() }),
                
                Pre26TabItem(title: "Settings", image: "gear", view: { SettingsViewNew() })
            ])
            .ignoresSafeArea(edges: .bottom)
            .ignoresSafeArea(edges: .horizontal)
            .if(!gameHandler.showApp) { $0.hidden() }
        } else {
            TabView(selection: $selectedTab) {
                GamesListView()
                    .tabItem { Label("Library", systemImage: "gamecontroller.fill") }
                    .tag(Tab.games)

                SettingsViewNew()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(Tab.settings)
            }
            .if(!gameHandler.showApp) { $0.hidden() }
        }
    }

    // MARK: - Body

    var body: some View {
        tabView
            .background {
                if showing {
                    SettingsViewNew().allBody
                        .opacity(0.001)
                }
            }
            .onAppear {
                controllerManager.initAll()
                MusicSelectorView.playMusic()

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    
                    if AppDelegate.url == nil {
                        gameHandler.enableJIT()
                    }
                    
                    if let url = AppDelegate.url {
                        handleDeepLink(url)
                    }

                    if !ProcessInfo.processInfo.isiOSAppOnMac {
                        Air.play(AnyView(
                            GamesListAirplay()
                                .environmentObject(gameHandler)
                                .environmentObject(ryujinx)
                        ))
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000)
                    showing = false

                    try? await Task.sleep(nanoseconds: 200_000_000)
                    viewShown = true

                    checkJITAndRunGame()
                    
                    if nativeSettings.mainThreadWatchdog.value {
                        Watchdog.shared.start()
                    }
                }
            }
            .environmentObject(gameHandler)
            .environmentObject(ryujinx)
            .environment(\.gameNamespace, gameAnimation)
            .fullScreenCover(isPresented: shouldLaunchGameBinding) {
                Group {
                    if #available(iOS 18.0, *) {
                        EmulationContainerView()
                            .navigationTransition(.zoom(
                                sourceID: gameHandler.currentGame?.fileURL.absoluteString ?? "cool",
                                in: gameAnimation
                            ))
                    } else {
                        EmulationContainerView()
                    }
                }
                .onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                        gameHandler.showApp = false
                    }
                }
                .onDisappear {
                    gameHandler.showApp = true
                }
                .interactiveDismissDisabled()
                .environmentObject(gameHandler)
                .environmentObject(ryujinx)
            }
            .alert(isPresented: shouldShowEntitlementBinding) {
                Alert(
                    title: Text("Entitlement"),
                    message: Text(LocalizedStringKey("MeloNX **REQUIRES** the Increased Memory Limit entitlement, Please follow the instructions on how to Install MeloNX and Enable the Entitlement.")),
                    primaryButton: .default(Text("Instructions")) {
                        UIApplication.shared.open(
                            URL(string: "https://git.ryujinx.app/melonx/emu#how-to-install")!,
                            options: [:],
                            completionHandler: nil
                        )
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
            .fullScreenCover(isPresented: shouldCheckJITBinding) {
                JITPopover() {}
                    .environmentObject(gameHandler)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("URLOpened"))) { notif in
                guard let url = notif.object as? URL else { return }
                handleDeepLink(url)
            }
            .if(gameHandler.shouldShowPopover) { view in
                view.halfScreenSheet(isPresented: shouldShowPopoverBinding) {
                    AccountSelector { success in
                        if success {
                            gameHandler.profileSelected = true
                        } else {
                            gameHandler.currentGame = nil
                        }
                    }
                }
            }
    }

    func checkJITAndRunGame(attempt: Int = 0) {
        guard !gametorun.isEmpty, attempt < 6 else { return }

        if isJITEnabled() {
            let shouldLaunch: Bool
            if let timeInterval = TimeInterval(gametorunDate) {
                let savedDate = Date(timeIntervalSince1970: timeInterval)
                shouldLaunch = Date().timeIntervalSince(savedDate) <= 60
            } else {
                shouldLaunch = true
            }

            if shouldLaunch {
                gameHandler.currentGame = ryujinx.games.first {
                    $0.titleId == gametorun || $0.titleName == gametorun
                }
            }

            gametorunDate = ""
            gametorun = ""
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                checkJITAndRunGame(attempt: attempt + 1)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        Task {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return }

            switch components.host {
            case "game":
                let idMatch = components.queryItems?.first(where: { $0.name == "id" })?.value
                let nameMatch = components.queryItems?.first(where: { $0.name == "name" })?.value

                if let query = idMatch ?? nameMatch {
                    gameHandler.currentGame = ryujinx.games.first {
                        $0.titleId == query || $0.titleName == query
                    }
                }

            case "gameInfo":
                guard let urlscheme = components.queryItems?.first(where: { $0.name == "scheme" })?.value,
                      let data = try? JSONEncoder().encode(ryujinx.games.map { GameScheme($0) }) else { return }

                let encoded = data.base64urlEncodedString()
                let scheme = url.scheme ?? "melonx"
                if let returnURL = URL(string: "\(urlscheme)://\(scheme)?games=\(encoded)") {
                    await UIApplication.shared.open(returnURL)
                    if !ryujinx.jitenabled {
                        exit(0)
                    }
                }

            default:
                return
            }
        }
    }
}

extension Data {
    public func base64urlEncodedString() -> String {
        self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

struct GameNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var gameNamespace: Namespace.ID? {
        get { self[GameNamespaceKey.self] }
        set { self[GameNamespaceKey.self] = newValue }
    }
}
