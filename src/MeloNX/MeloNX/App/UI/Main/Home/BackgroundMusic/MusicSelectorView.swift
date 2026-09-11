//
//  MusicSelectorView.swift
//  MeloNX
//
//  Created by Stossy11 on 27/12/2025.
//

import SwiftUI
import AVFoundation


struct MusicItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var path: String
    var name: String?
    var albumArtwork: Data?
    var builtIn: Bool
    var credit: String?
    
    var displayName: String {
        name ?? path.replacingOccurrences(of: ".mp3", with: "")
    }
}

struct MusicSelectorView: View {
    var fileManager: FileManager = .default
    @State var items: [MusicItem] = []
    @State static var delegate: MusicPlayerDelegate = .init()
    @AppStorage("playRandom") var random = false
    @AppStorage("loopBackground") var loop = true
    static let mp3Directory = URL.documentsDirectory.appendingPathComponent("audio")
    let mp3Directory = Self.mp3Directory
    @State var audioplayerChanged = false
    @StateObject var nativeSettings: NativeSettingsManager = .shared
    static var nativeSettings: NativeSettingsManager = .shared
    static var audioPlayer: AVAudioPlayer?
    static var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    static func getRandomItem() -> MusicItem? {
        let allItems =  getMP3s()
        let randomItem = allItems.randomElement()
        return randomItem
    }
    
    static func playMusic(_ musicItem: MusicItem? = nil, at: TimeInterval? = nil) {
        
        let mp3Directory = URL.documentsDirectory.appendingPathComponent("audio")
        var selectedItem = musicItem?.path ?? nativeSettings.backgroundMusic("").value
        let fileManager: FileManager = .default
        
        var fullPath = mp3Directory.appendingPathComponent(selectedItem)
        var mainBundlePath: URL {
            Bundle.main.bundleURL.appendingPathComponent(selectedItem)
        }
        
        if nativeSettings.playRandom.value, musicItem == nil {
            let randomItem = getRandomItem()
            selectedItem = randomItem?.path ?? ""
            fullPath = mp3Directory.appendingPathComponent(selectedItem)
        }
        
        if !fileManager.fileExists(atPath: fullPath.path), fileManager.fileExists(atPath: mainBundlePath.path)  {
            fullPath = mainBundlePath
        }
        
        if !selectedItem.isEmpty && fileManager.fileExists(atPath: fullPath.path) {
            do {
                if audioPlayer == nil || !isPlaying {
                    audioPlayer = try AVAudioPlayer(contentsOf: fullPath)
                    audioPlayer?.currentTime = at ?? 0
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                    audioPlayer?.delegate = delegate
                    print("playing music")
                } else {
                    print("Sound is already playing")
                }
            } catch {
                print("Error playing sound: \(error.localizedDescription)")
            }
        }
    }
    
    
    
    static func stopMusic() {
        if audioPlayer != nil || isPlaying {
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }
    
    static func extractAlbumMetadata(from fileURL: URL) -> (UIImage?, String?, String?) {
        let asset = AVAsset(url: fileURL)
        
        let metadata = asset.metadata(forFormat: .id3Metadata)
        var coolImage: UIImage?
        var artist: String?
        var name: String?
        for item in metadata {
            if item.commonKey == .commonKeyTitle {
                if let stringValue = item.stringValue {
                    name = stringValue
                }
            }
            if item.commonKey == .commonKeyArtist {
                if let stringValue = item.stringValue {
                    artist = stringValue
                }
            }
            if item.commonKey == .commonKeyArtwork {
                if let data = item.dataValue, let image = UIImage(data: data) {
                    coolImage = image
                }
            }
        }
        
        return (coolImage, artist, name)
    }

    
    var body: some View {
        iOSNav {
            List {
                Section {
                    if items.isEmpty {
                        emptyStateView
                    } else if items.count > 1 {
                        Toggle("Shuffle", isOn: $random)
                    }
                    
                    if items.count >= 1, !nativeSettings.backgroundMusic("").value.isEmpty, !self.random {
                        Toggle("Loop", isOn: $loop)
                    }
                }
                
                Section("Built In") {
                    ForEach(items.filter({ $0.builtIn })) { music in
                        musicItemListView(music)
                            .contextMenu {
                                if music.path == "MidiMart.mp3" {
                                    Section {
                                        Button {
                                            UIApplication.shared.open(URL(string: "https://www.youtube.com/channel/UCko46AN5Eqtr8xww2u3UvaA")!)
                                        } label: {
                                            Text("All Credit goes to @SkvlKat")
                                        }
                                        
                                        Text("Thank you for this amazing track.")
                                    }
                                }
                            }
                            .id(audioplayerChanged)
                    }
                }
                
                Section {
                    ForEach(items.filter({ !$0.builtIn })) { music in
                        musicItemListView(music)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if Self.isPlaying {
                        Button {
                            audioplayerChanged.toggle() // this is to make the view update :3
                            Self.stopMusic()
                        } label: {
                            Label("Stop", systemImage: "xmark")
                        }
                    } else if !nativeSettings.backgroundMusic("").value.isEmpty {
                        Button {
                            audioplayerChanged.toggle()
                            Self.playMusic()
                        } label: {
                            Label("Play", systemImage: "play")
                        }
                    }
                }
        
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FileImporterManager.shared.importFiles(types: [.item], allowMultiple: true, completion: handleFileImport)
                    } label: {
                        Label("Add Music", systemImage: "plus")
                    }
                }
            }
            .onAppear() {
                items = Self.getMP3s()
            }
        }
    }
    
    @ViewBuilder
    func musicItemListView(_ music: MusicItem) -> some View {
        HStack {
            if let image = UIImage(data: music.albumArtwork ?? Data()) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading) {
                Button(music.displayName) {
                    if music.path == nativeSettings.backgroundMusic("").value {
                        nativeSettings.backgroundMusic("").value = ""
                    } else {
                        nativeSettings.backgroundMusic("").value = music.path
                    }
                }
                
                if let credit = music.credit {
                    Text(credit)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !random {
                Image(systemName: music.path == nativeSettings.backgroundMusic("").value ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(music.path == nativeSettings.backgroundMusic("").value ? .primary : .secondary)
                    .imageScale(.large)
            }
        }
        .foregroundStyle(.white)
    }
    
    private var emptyStateView: some View {
        Group {
            if #available(iOS 17, *) {
                ContentUnavailableView(
                    "No Music Found",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap the + button to add background music.")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Music Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap the + button to add background music.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
            }
        }
    }
    
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                if !fileManager.fileExists(atPath: mp3Directory.path) {
                    try? fileManager.createDirectory(at: mp3Directory, withIntermediateDirectories: true)
                }
                
                try? fileManager.copyItem(at: url, to: mp3Directory.appendingPathComponent(url.lastPathComponent))
                
                items = Self.getMP3s()
                setSelectedItem()
            }
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    
    static func getMP3s() -> [MusicItem] {
        var items: [MusicItem] = []
        if let enumerator = FileManager.default.enumerator(at: mp3Directory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension != "mp3" {
                    continue
                }
                let (image, artist, name) = extractAlbumMetadata(from: fileURL)
                    
                items.append(MusicItem(path: fileURL.lastPathComponent, name: name, albumArtwork: image?.jpgData(compressionQuality: 1.0), builtIn: false, credit: artist))
    
            }
        }
        
        if let enumerator = FileManager.default.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension != "mp3" {
                    continue
                }
                
                
                let (image, artist, name) = extractAlbumMetadata(from: fileURL)
                    
                items.append(MusicItem(path: fileURL.lastPathComponent, name: name, albumArtwork: image?.jpgData(compressionQuality: 1.0), builtIn: true, credit: artist))
            }
            
        }
        
        return items
    }
    
    static func setMusicItemPath(_ musicItem: MusicItem) {
        nativeSettings.backgroundMusic("").value = musicItem.path
    }
    
    func setSelectedItem() {
        if nativeSettings.backgroundMusic("").value.isEmpty || !fileManager.fileExists(atPath: mp3Directory.appendingPathComponent(nativeSettings.backgroundMusic("").value).path) {
            
            if !fileManager.fileExists(atPath: mp3Directory.appendingPathComponent(items.first?.path ?? "").path) {
                nativeSettings.backgroundMusic("").value = items.first?.path ?? ""
            }
        }
    }
}


class MusicPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    var nativeSettings: NativeSettingsManager = .shared
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if nativeSettings.playRandom.value {
            player.stop()
            MusicSelectorView.audioPlayer = nil
            
            if let randomItem = MusicSelectorView.getRandomItem() {
                nativeSettings.backgroundMusic("").value = randomItem.path
                MusicSelectorView.playMusic()
            }
        } else if flag, (nativeSettings.hasbeenfinished.value || (nativeSettings.backgroundMusic("").value.contains("Setup.mp3") && nativeSettings.loopBackground.value)) {
            let mp3 = MusicSelectorView.getMP3s().first(where: { $0.builtIn })
            MusicSelectorView.playMusic(mp3, at: 7.85)
        } else if nativeSettings.loopBackground.value {
            MusicSelectorView.playMusic()
        } else {
            MusicSelectorView.audioPlayer = nil
        }
    }
    
}
