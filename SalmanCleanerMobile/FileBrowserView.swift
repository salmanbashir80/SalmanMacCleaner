import SwiftUI
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @State private var isDocumentPickerPresented = false
    @State private var selectedFileURLs: [URL] = []
    
    var body: some View {
        VStack {
            if selectedFileURLs.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("No Files Selected")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Select files or folders to manage them securely within the app's sandbox.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                List {
                    ForEach(selectedFileURLs, id: \.self) { url in
                        HStack {
                            Image(systemName: "doc")
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.headline)
                            }
                        }
                    }
                    .onDelete(perform: deleteItem)
                }
            }
            
            Button(action: {
                isDocumentPickerPresented = true
            }) {
                Label("Select Files", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Files")
        .fileImporter(
            isPresented: $isDocumentPickerPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                for url in urls {
                    // Start accessing a security-scoped resource.
                    let _ = url.startAccessingSecurityScopedResource()
                }
                selectedFileURLs.append(contentsOf: urls)
            } catch {
                print("Error selecting files: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteItem(at offsets: IndexSet) {
        for index in offsets {
            let url = selectedFileURLs[index]
            url.stopAccessingSecurityScopedResource()
        }
        selectedFileURLs.remove(atOffsets: offsets)
    }
}
