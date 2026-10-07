import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoManager = PhotoManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if photoManager.authorizationStatus == .notDetermined {
                    Text("Welcome to SalmanCleaner Mobile")
                        .font(.title)
                        .padding()
                    Text("We need access to your photos to find large media and duplicates.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Grant Access") {
                        photoManager.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                } else if photoManager.authorizationStatus == .denied || photoManager.authorizationStatus == .restricted {
                    Text("Permission Denied")
                        .font(.title)
                    Text("Please enable photo access in Settings.")
                } else {
                    DashboardView(photoManager: photoManager)
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                if photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited {
                    if photoManager.largeMedia.isEmpty && photoManager.duplicateGroups.isEmpty && !photoManager.isScanning {
                        photoManager.scanPhotoLibrary()
                    }
                }
            }
        }
    }
}

struct DashboardView: View {
    @ObservedObject var photoManager: PhotoManager
    
    var body: some View {
        List {
            Section(header: Text("Storage Overview")) {
                if photoManager.isScanning {
                    HStack {
                        ProgressView()
                        Text("Scanning...")
                            .padding(.leading)
                    }
                } else {
                    HStack {
                        Text("Scanned Size")
                        Spacer()
                        Text(formatBytes(photoManager.scannedBytes))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Recommendations")) {
                NavigationLink(destination: LargeMediaView(photoManager: photoManager)) {
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.blue)
                        Text("Large Media")
                        Spacer()
                        Text("\(photoManager.largeMedia.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: DuplicatesView(photoManager: photoManager)) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(.orange)
                        Text("Similar Items (Candidates)")
                        Spacer()
                        Text("\(photoManager.duplicateGroups.count) groups")
                            .foregroundColor(.secondary)
                    }
                }
                
                NavigationLink(destination: FileBrowserView()) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.purple)
                        Text("Manage Files")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

