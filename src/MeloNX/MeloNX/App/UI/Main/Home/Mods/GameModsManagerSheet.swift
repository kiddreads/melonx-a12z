//
//  GameUpdateManagerSheet.swift
//  MeloNX
//
//  Created by Stossy11 on 16/02/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ModsManagerSheet: View {
    // MARK: - Properties
    @State private var mods: [ModItem] = []
    var game: Game?
    @State private var modsURL: URL? = nil
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Models
    class ModItem: Identifiable, ObservableObject {
        let id = UUID()
        let url: URL
        let filename: String
        let path: String

        init(url: URL, filename: String, path: String) {
            self.url = url
            self.filename = filename
            self.path = path
        }
    }
    
    // MARK: - Body
    var body: some View {
        iOSNav {
            List {
                Section {
                    Text("Please note that mods currently have limited support and may not work or behave correctly.")
                        .foregroundStyle(.red)
                        .font(.caption.bold())
                }
                
                Section {
                    if mods.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(mods) { update in
                            updateRow(update)
                        }
                        .onDelete(perform: removeUpdates)
                    }
                }
            }
            .navigationTitle("\(game?.titleName ?? "Game") Mods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        FileImporterManager.shared.importFiles(types: [.folder], allowMultiple: true, completion: handleFileImport)
                    } label: {
                        Label("Add Mod", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    // MARK: - Views
    private var emptyStateView: some View {
        Group {
            if #available(iOS 17, *) {
                ContentUnavailableView(
                    "No Mods Found",
                    systemImage: "arrow.down.circle",
                    description: Text("Tap the + button to add game mods.")
                )
            } else {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("No Mods Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Tap the + button to add game mods.")
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
    
    
    private func updateRow(_ update: ModItem) -> some View {
        Button {
            showAlert(title: "Delete", message: "Would you like to delete \(update.filename)?", actions: [
                (title: "Cancel", style: .cancel, handler: nil),
                (title: "Delete", style: .destructive, handler: {
                    if let index = mods.firstIndex(where: { $0.path == update.path }) {
                        removeUpdate(at: IndexSet(integer: index))
                    }
                })
            ])
        } label: {
            HStack {
                Text(update.filename)
                    .foregroundColor(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                if let index = mods.firstIndex(where: { $0.path == update.path }) {
                    removeUpdate(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                if let index = mods.firstIndex(where: { $0.path == update.path }) {
                    removeUpdate(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    

    
    private func loadData() {
        guard let game = game else { return }
        
        let documentsDirectory = URL.documentsDirectory
        let cool =  documentsDirectory
            .appendingPathComponent("mods")
            .appendingPathComponent("contents")
            .appendingPathComponent(game.titleId)
        modsURL = cool
        
        let contents = (try? FileManager.default.contentsOfDirectory(at: cool, includingPropertiesForKeys: nil)) ?? []
        for fileURL in contents {
            let relativePath = "mods/\(game.titleId)/\(fileURL.lastPathComponent)"
            let newUpdate = ModItem(
                url: fileURL,
                filename: fileURL.lastPathComponent,
                path: relativePath
            )
            
            mods.append(newUpdate)
        }
    }
    

    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var updates: [ModItem] = []
            for selectedURL in urls {
                guard let game = game,
                      selectedURL.startAccessingSecurityScopedResource() else {
                    print("Failed to access security-scoped resource")
                    return
                }
                
                defer { selectedURL.stopAccessingSecurityScopedResource() }
                
                do {
                    let fileManager = FileManager.default
                    let updatesDirectory = URL.documentsDirectory.appendingPathComponent("mods")
                    let contentsDirectory = updatesDirectory.appendingPathComponent("contents")
                    let gameModsDirectory = contentsDirectory.appendingPathComponent(game.titleId)
                    
                    // Create directories if needed
                    try? fileManager.createDirectory(at: gameModsDirectory, withIntermediateDirectories: true)
                    
                    // Copy the file
                    try? fileManager.removeItem(at: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent))
                    try fileManager.copyItem(at: selectedURL, to: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent))
                    
                    // Add to updates
                    let relativePath = "mods/\(game.titleId)/\(selectedURL.lastPathComponent)"
                    let newUpdate = ModItem(
                        url: gameModsDirectory.appendingPathComponent(selectedURL.lastPathComponent),
                        filename: selectedURL.lastPathComponent,
                        path: relativePath
                    )
                    
                    
                    updates.append(newUpdate)
            
                } catch {
                    print("Error copying update file: \(error)")
                }
            }
            
            
            self.mods.append(contentsOf: updates)
            
        case .failure(let error):
            print("File import failed: \(error.localizedDescription)")
        }
    }
    
    private func removeUpdates(at offsets: IndexSet) {
        offsets.forEach { removeUpdate(at: IndexSet(integer: $0)) }
    }
    
    private func removeUpdate(at indexSet: IndexSet) {
        guard let index = indexSet.first else { return }
        
        let updateToRemove = mods[index]
        
        do {
            // Remove the file
            try FileManager.default.removeItem(at: updateToRemove.url)
            
            // Remove from updates array
            mods.remove(at: index)
            
        } catch {
            print("Failed to remove update: \(error)")
        }
    }
}
