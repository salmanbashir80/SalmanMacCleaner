import SwiftUI
import Photos

struct DuplicatesView: View {
    @ObservedObject var photoManager: PhotoManager
    @State private var selectedAssets: Set<PHAsset> = []
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            ForEach(0..<photoManager.duplicateGroups.count, id: \.self) { index in
                Section(header: Text("Group \(index + 1)")) {
                    let group = photoManager.duplicateGroups[index]
                    ForEach(group, id: \.localIdentifier) { asset in
                        HStack {
                            Image(systemName: asset.mediaType == .video ? "video" : "photo")
                            VStack(alignment: .leading) {
                                Text(asset.localIdentifier.prefix(8))
                                Text(formatDate(asset.creationDate))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(formatSize(asset))
                                .foregroundColor(.secondary)
                            
                            if selectedAssets.contains(asset) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedAssets.contains(asset) {
                                selectedAssets.remove(asset)
                            } else {
                                selectedAssets.insert(asset)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Similar Items")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
                .disabled(selectedAssets.isEmpty)
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Auto-Select") {
                    autoSelectDuplicates()
                }
                .disabled(photoManager.duplicateGroups.isEmpty)
            }
        }
        .confirmationDialog("Delete selected items?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                photoManager.deleteAssets(Array(selectedAssets))
                selectedAssets.removeAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These items will be permanently deleted from your iCloud Photo Library.")
        }
    }
    
    private func autoSelectDuplicates() {
        selectedAssets.removeAll()
        for group in photoManager.duplicateGroups {
            // Keep the first one, select the rest
            if group.count > 1 {
                let sortedGroup = group.sorted {
                    let size0 = PHAssetResource.assetResources(for: $0).reduce(0) { $0 + (Int64($1.value(forKey: "fileSize") as? UInt64 ?? 0)) }
                    let size1 = PHAssetResource.assetResources(for: $1).reduce(0) { $0 + (Int64($1.value(forKey: "fileSize") as? UInt64 ?? 0)) }
                    return size0 > size1
                }
                selectedAssets.formUnion(sortedGroup.dropFirst())
            }
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatSize(_ asset: PHAsset) -> String {
        let size = PHAssetResource.assetResources(for: asset).reduce(0) { $0 + (Int64($1.value(forKey: "fileSize") as? UInt64 ?? 0)) }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
