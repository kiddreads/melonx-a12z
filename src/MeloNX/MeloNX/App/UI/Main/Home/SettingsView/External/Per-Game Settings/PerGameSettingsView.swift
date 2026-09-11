//
//  PerGameSettingsView.swift
//  MeloNX
//
//  Created by Stossy11 on 12/06/2025.
//

import SwiftUI

protocol PerGameSettingsManaging: ObservableObject {
    var config: [String: Ryujinx.Arguments] { get set }
    
    func debouncedSave()
    func saveSettings()
    func loadSettings()
    
    static func loadSettings() -> [String: Ryujinx.Arguments]?
}



class PerGameSettingsManager: PerGameSettingsManaging {
    @Published var config: [String: Ryujinx.Arguments] {
        didSet {
            debouncedSave()
        }
    }
    
    private var saveWorkItem: DispatchWorkItem?
    
    public static var shared = PerGameSettingsManager()
    
    private init() {
        self.config = PerGameSettingsManager.loadSettings() ?? [:]
    }
    
    func debouncedSave() {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.saveSettings()
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            
            let fileURL = URL.documentsDirectory.appendingPathComponent("config-pergame.json")
            
            try data.write(to: fileURL)
            print("Settings saved successfully")
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    static func loadSettings() -> [String: Ryujinx.Arguments]? {
        do {
            let fileURL = URL.documentsDirectory.appendingPathComponent("config-pergame.json")
            
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                print("Config file does not exist, creating new config")
                return nil
            }
            
            let data = try Data(contentsOf: fileURL)
            
            let decoder = JSONDecoder()
            let configs = try decoder.decode([String: Ryujinx.Arguments].self, from: data)
            return configs
        } catch {
            print("Failed to load settings: \(error)")
            return nil
        }
    }
    
    func loadSettings() {
        self.config = PerGameSettingsManager.loadSettings() ?? [:]
    }
}


struct PerGameSettingsView: View {
    
    @StateObject private var settingsManager: PerGameSettingsManager
    
    var titleId: String

    init(titleId: String, manager: any PerGameSettingsManaging = PerGameSettingsManager.shared) {
        self._settingsManager = StateObject(wrappedValue: manager as! PerGameSettingsManager)
        self.titleId = titleId 
    }
    
    private func configBinding<T>(_ keyPath: WritableKeyPath<Ryujinx.Arguments, T>) -> Binding<T> {
        Binding(
            get: {
                (settingsManager.config[titleId] ?? Ryujinx.Arguments())[keyPath: keyPath]
            },
            set: { newValue in
                var config = settingsManager.config[titleId] ?? Ryujinx.Arguments()
                config[keyPath: keyPath] = newValue
                settingsManager.config[titleId] = config
            }
        )
    }
    
    
    var memoryManagerModes = [
        ("HostMapped", "Host (fast)"),
        ("HostMappedUnsafe", "Host Unchecked (fast, unstable / unsafe)"),
        ("SoftwarePageTable", "Software (slow)"),
    ]
    
    
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    
    @State private var showResolutionInfo = false
    @State private var showAnisotropicInfo = false
    @State private var showControllerInfo = false
    @State private var showAppIconSwitcher = false
    @State private var searchText = ""
    @StateObject var ryujinx = Ryujinx.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass: UserInterfaceSizeClass?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    
    @State private var selectedCategory: PerSettingsCategory = .graphics
    
    @StateObject var metalHudEnabler = MTLHud.shared
    
    var filteredMemoryModes: [(String, String)] {
        guard !searchText.isEmpty else { return memoryManagerModes }
        return memoryManagerModes.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
    }
    
    var appVersion: String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "Unknown"
        }
        return version
    }
    
    @FocusState private var isArgumentsKeyboardVisible: Bool
    
    
    @State private var selectedView = "Data Management"
    @State private var sidebar = true
    
    enum PerSettingsCategory: LocalizedStringKey, CaseIterable, Identifiable {
        case graphics = "Graphics"
        case system = "System"
        case network = "Network"
        case advanced = "Advanced"
        
        var id: String { "\(self.rawValue)" }
        
        var icon: String {
            switch self {
            case .graphics: return "paintbrush.fill"
            case .system: return "gearshape.fill"
            case .network: return "network"
            case .advanced: return "terminal.fill"
            }
        }
    }
    
    var body: some View {
        iOSNav {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(PerSettingsCategory.allCases, id: \.id) { category in
                                CategoryButton(
                                    title: category.rawValue,
                                    icon: category.icon,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // Settings content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedCategory {
                            case .graphics:
                                graphicsSettings
                                    .padding(.top)
                            case .system:
                                systemSettings
                                    .padding(.top)
                            case .network:
                                miscSettings
                                    .padding(.top)
                            case .advanced:
                                advancedSettings
                                    .padding(.top)

                            }
                            
                            Spacer(minLength: 50)
                        }
                        .padding(.bottom)
                    }
                    .scrollDismissesKeyboardIfAvailable()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settingsManager.debouncedSave()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        dismiss()
                        settingsManager.config[titleId] = nil
                        settingsManager.saveSettings()
                    }
                }
            }
            // .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .onAppear {
                
                // if let configs = SettingsManager.loadSettings() {
                // settingsManager.loadSettings()
                // } else {
                // settingsManager.saveSettings()
                //}
                
                print(titleId)
                
                if settingsManager.config[titleId] == nil {
                    settingsManager.config[titleId] = Ryujinx.Arguments()
                    settingsManager.debouncedSave()
                }
            }
        }
    }

    // MARK: - Graphics Settings
    
    private var graphicsSettings: some View {
        SettingsSection(title: "Graphics & Performance") {
            // Resolution scale card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        labelWithIcon("Resolution Scale", iconName: "magnifyingglass")
                            .font(.headline)
                        Spacer()
                        Button {
                            showResolutionInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .alert(isPresented: $showResolutionInfo) {
                            Alert(
                                title: Text("Resolution Scale"),
                                message: Text("Adjust the internal rendering resolution. Higher values improve visuals but may reduce performance."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Slider(value: configBinding(\.resscale), in: 0.1...3.0, step: 0.05)
                        
                        HStack {
                            Text("0.1x")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(configBinding(\.resscale).wrappedValue, specifier: "%.2f")x")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("3.0x")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Anisotropic filtering card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        labelWithIcon("Max Anisotropic Filtering", iconName: "magnifyingglass")
                            .font(.headline)
                        Spacer()
                        Button {
                            showAnisotropicInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .alert(isPresented: $showAnisotropicInfo) {
                            Alert(
                                title: Text("Max Anisotropic Filtering"),
                                message: Text("Adjust the internal Anisotropic filtering. Higher values improve texture quality at angles but may reduce performance. Default at 0 lets game decide."),
                                dismissButton: .default(Text("OK"))
                            )
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Slider(value: configBinding(\.maxAnisotropy), in: 0...16.0, step: 0.1)
                        
                        HStack {
                            Text("Off")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(configBinding(\.maxAnisotropy).wrappedValue, specifier: "%.1f")x")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Text("16x")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Toggle options card
            SettingsCard {
                VStack(spacing: 4) {
                    PerSettingsToggle(isOn: configBinding(\.enableShaderCache), icon: "memorychip", label: "Shader Cache")
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.disablevsync).reversed, icon: "arrow.triangle.2.circlepath", label: "VSync")
                    
                    Divider()
                    
                    // PerSettingsToggle(isOn: configBinding(\.enableTextureRecompression), icon: "rectangle.compress.vertical", label: "Texture Recompression")
                    
                    // Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.enableDockedMode), icon: "dock.rectangle", label: "Docked Mode")
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.macroHLE), icon: "gearshape", label: "Macro HLE")
                }
            }
            
            // Aspect ratio card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    labelWithIcon("Aspect Ratio", iconName: "rectangle.expand.vertical")
                        .font(.headline)
                    
                    if (horizontalSizeClass == .regular && verticalSizeClass == .regular) || (horizontalSizeClass == .regular && verticalSizeClass == .compact) {
                        Picker(selection: configBinding(\.aspectRatio)) {
                            ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                Text(ratio.displayName).tag(ratio)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker(selection: configBinding(\.aspectRatio)) {
                            ForEach(AspectRatio.allCases, id: \.self) { ratio in
                                Text(ratio.displayName).tag(ratio)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    
    // MARK: - System Settings
    
    private var systemSettings: some View {
        SettingsSection(title: "System Configuration") {
            // Language and region card
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        labelWithIcon("System Language", iconName: "character.bubble")
                            .font(.headline)
                        
                        Picker(selection: configBinding(\.language)) {
                            ForEach(SystemLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        labelWithIcon("Region", iconName: "globe")
                            .font(.headline)
                        
                        Picker(selection: configBinding(\.regioncode)) {
                            ForEach(SystemRegionCode.allCases, id: \.self) { region in
                                Text(region.displayName).tag(region)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // CPU options card
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CPU Configuration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Manager Mode")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker(selection: configBinding(\.memoryManagerMode)) {
                            ForEach(filteredMemoryModes, id: \.0) { key, displayName in
                                Text(displayName).tag(key)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.disablePTC).reversed, icon: "cpu", label: "PTC")
                    
                    if let gpuInfo = getGPUInfo(), gpuInfo.hasPrefix("Apple M") {
                        Divider()
                        
                        if #available(iOS 16.4, *) {
                            PerSettingsToggle(isOn: .constant(false), icon: "bolt", label: "Hypervisor")
                                .disabled(true)
                        } else if checkAppEntitlement("com.apple.private.hypervisor") {
                            PerSettingsToggle(isOn: configBinding(\.hypervisor), icon: "bolt", label: "Hypervisor")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettings: some View {
        SettingsSection(title: "Advanced Options") {
            // Debug options card
            SettingsCard {
                VStack(spacing: 4) {
                    PerSettingsToggle(isOn: configBinding(\.debuglogs), icon: "exclamationmark.bubble", label: "Debug Logs")
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.tracelogs), icon: "waveform.path", label: "Trace Logs")
                }
            }
            
            // Advanced toggles card
            SettingsCard {
                VStack(spacing: 4) {
                    
                    PerSettingsToggle(isOn: configBinding(\.dfsIntegrityChecks), icon: "checkmark.shield", label: "Disable FS Integrity Checks")
                        .accentColor(.red)
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.expandRam), icon: "exclamationmark.bubble", label: "Expand Guest RAM")
                        .accentColor(.red)
                        .disabled(totalMemory < 5723)
                    
                    Divider()
                    
                    PerSettingsToggle(isOn: configBinding(\.ignoreMissingServices), icon: "waveform.path", label: "Ignore Missing Services")
                        .accentColor(.red)
                }
            }
            
            // Additional args card
            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Additional Arguments")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    let binding = Binding(
                        get: {
                            configBinding(\.additionalArgs).wrappedValue.joined(separator: ", ")
                        },
                        set: { newValue in
                            let args = newValue
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                            configBinding(\.additionalArgs).wrappedValue = args
                        }
                    )
                    
                    
                    if #available(iOS 15.0, *) {
                        TextField("Separate arguments with commas", text: binding)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.vertical, 4)
                            .toolbar {
                                ToolbarItem(placement: .keyboard) {
                                    Button("Dismiss") {
                                        isArgumentsKeyboardVisible = false
                                    }
                                }
                            }
                            .focused($isArgumentsKeyboardVisible)
                    } else {
                        TextField("Separate arguments with commas", text: binding)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .disableAutocorrection(true)
                            .padding(.vertical, 4)
                    }
                }
            }
            
            // Page size info card
            SettingsCard {
                HStack {
                    labelWithIcon("Page Size", iconName: "textformat.size")
                    Spacer()
                    Text("\(String(Int(getpagesize())))")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Miscellaneous Settings
    
    private var miscSettings: some View {
        SettingsSection(title: "Network Options") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsToggle(isOn: configBinding(\.enableInternet), icon: "wifi.router.fill", label: "Guest Internet Access / LAN Mode")
                    
                    Divider()
                    
                    SettingsToggle(isOn: configBinding(\.ldn_mitm), icon: "ipad.sizes", label: "ldn_mitm")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    
    func getGPUInfo() -> String? {
        let device = MTLCreateSystemDefaultDevice()
        return device?.name
    }
    
    @ViewBuilder
    private func labelWithIcon(_ text: String, iconName: String, flipimage: Bool? = nil) -> some View {
        HStack(spacing: 8) {
            if iconName.hasSuffix(".svg") {
                if let flipimage, flipimage {
                    SVGView(svgName: iconName, color: .blue)
                        // .symbolRenderingMode(.hierarchical)
                        .frame(width: 20, height: 20)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                } else {
                    SVGView(svgName: iconName, color: .blue)
                        // .symbolRenderingMode(.hierarchical)
                        .frame(width: 20, height: 20)
                }
            } else if !iconName.isEmpty {
                Image(systemName: iconName)
                    // .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.blue)
            }
            Text(text)
        }
        .font(.body)
    }
}


// MARK: - Supporting Views

// PerSettingsToggle(isOn: config.handHeldController, icon: "formfitting.gamecontroller", label: "Player 1 to Handheld")

struct PerSettingsCard<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("oldSettingsUI") var oldSettingsUI = false
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(.systemGray6) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
    }
}

struct PerSettingsToggle: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    var disabled: Bool = false
    @AppStorage("toggleGreen") var toggleGreen: Bool = false
    @AppStorage("oldSettingsUI") var oldSettingsUI = false
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                if icon.hasSuffix(".svg") {
                    SVGView(svgName: icon, color: .blue)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                    // .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.blue)
                }
                
                Text(label)
                    .font(.body)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
        .disabled(disabled)
        .padding(.vertical, 6)
    }
    
    func disabled(_ disabled: Bool) -> PerSettingsToggle {
        var view = self
        view.disabled = disabled
        return view
    }
    
    func accentColor(_ color: Color) -> PerSettingsToggle {
        var view = self
        return view
    }
}
