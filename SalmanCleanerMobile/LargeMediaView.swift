import SwiftUI
import Photos

struct LargeMediaView: View {
    @ObservedObject var photoManager: PhotoManager
    @State private var selectedAssets: Set<PHAsset> = []
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        List {
            ForEach(photoManager.largeMedia, id: \.localIdentifier) { asset in
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
        .navigationTitle("Large Media")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                }
                .disabled(selectedAssets.isEmpty)
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
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
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
