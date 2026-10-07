import Foundation
import Photos
import Combine

class PhotoManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var largeMedia: [PHAsset] = []
    @Published var duplicateGroups: [[PHAsset]] = []
    @Published var isScanning = false
    @Published var scannedBytes: Int64 = 0
    @Published var error: Error?

    init() {
        self.authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.authorizationStatus = status
            }
        }
    }

    func scanPhotoLibrary() {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        
        DispatchQueue.main.async {
            self.isScanning = true
            self.largeMedia.removeAll()
            self.duplicateGroups.removeAll()
            self.scannedBytes = 0
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let allAssets = PHAsset.fetchAssets(with: fetchOptions)
            
            var largeAssets: [PHAsset] = []
            var creationDateMap: [Date: [PHAsset]] = [:]
            
            var totalBytes: Int64 = 0
            
            let group = DispatchGroup()
            
            allAssets.enumerateObjects { (asset, index, stop) in
                if let creationDate = asset.creationDate {
                    // Truncate to second for rough duplicate detection
                    let timeInterval = floor(creationDate.timeIntervalSince1970)
                    let truncatedDate = Date(timeIntervalSince1970: timeInterval)
                    creationDateMap[truncatedDate, default: []].append(asset)
                }
                
                group.enter()
                let resources = PHAssetResource.assetResources(for: asset)
                let size = resources.reduce(0) { (result, resource) -> Int64 in
                    if let unsignedSize = resource.value(forKey: "fileSize") as? UInt64 {
                        return result + Int64(unsignedSize)
                    }
                    return result
                }
                
                totalBytes += size
                
                // Define "large" as > 50MB
                if size > 50 * 1024 * 1024 {
                    largeAssets.append(asset)
                }
                group.leave()
            }
            
            group.wait()
            
            let duplicates = creationDateMap.values.filter { $0.count > 1 }.sorted { $0.count > $1.count }
            
            DispatchQueue.main.async {
                self.largeMedia = largeAssets.sorted { 
                    let size0 = PHAssetResource.assetResources(for: $0).reduce(0) { $0 + (Int64($1.value(forKey: "fileSize") as? UInt64 ?? 0)) }
                    let size1 = PHAssetResource.assetResources(for: $1).reduce(0) { $0 + (Int64($1.value(forKey: "fileSize") as? UInt64 ?? 0)) }
                    return size0 > size1
                }
                self.duplicateGroups = duplicates
                self.scannedBytes = totalBytes
                self.isScanning = false
            }
        }
    }
    
    func deleteAssets(_ assets: [PHAsset]) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.scanPhotoLibrary()
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self.error = error
                }
            }
        }
    }
}
