import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
    @ObservedObject var store: RouteStore
    let userId: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var processedCount = 0
    @State private var skippedCount = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Processing \(processedCount + skippedCount) photos…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 50,
                        matching: .images
                    ) {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 48))
                                .foregroundStyle(Config.accent)
                            Text("Select Photos")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Choose geotagged photos from your library.\nThey'll be matched to nearby routes.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .onChange(of: selectedItems) { _, items in
                        guard !items.isEmpty else { return }
                        Task { await processItems(items) }
                    }

                    if !store.photos.isEmpty {
                        Divider()
                        Text("\(store.photos.count) photo\(store.photos.count == 1 ? "" : "s") on map")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Config.accent)
                }
            }
        }
    }

    private func processItems(_ items: [PhotosPickerItem]) async {
        isProcessing = true
        processedCount = 0
        skippedCount = 0

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data)
            else { skippedCount += 1; continue }

            let filename = item.itemIdentifier ?? UUID().uuidString
            await store.addPhoto(imageData: data, image: image, filename: filename, userId: userId)
            processedCount += 1
        }

        isProcessing = false
        dismiss()
    }
}

// MARK: — Photo markers overlay (placed over the map)

struct PhotoMarkersView: View {
    let photos: [PhotoItem]
    let mapSize: CGSize
    /// Convert a coordinate to screen position — injected from map
    var coordinateToPoint: (CLLocationCoordinate2D) -> CGPoint?
    @State private var selectedPhoto: PhotoItem?

    var body: some View {
        ZStack {
            ForEach(photos) { photo in
                if let pt = coordinateToPoint(photo.coordinate) {
                    PhotoMarker(photo: photo)
                        .position(pt)
                        .onTapGesture { selectedPhoto = photo }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoLightboxView(photo: photo, onDelete: {
                selectedPhoto = nil
            })
        }
    }
}

struct PhotoMarker: View {
    let photo: PhotoItem

    var body: some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 1.5))
            .shadow(radius: 4, y: 2)
    }
}

struct PhotoLightboxView: View {
    let photo: PhotoItem
    @ObservedObject var store: RouteStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea(edges: .horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.system(size: 24))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    VStack(spacing: 2) {
                        if let date = photo.photoTime {
                            Text(date, style: .date)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                        }
                        Text(photo.originalFilename)
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Delete Photo", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.removePhoto(photo)
                    store.selectedPhoto = nil
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the photo.")
            }
        }
    }
}

import CoreLocation
