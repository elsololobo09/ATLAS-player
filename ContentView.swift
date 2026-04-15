import Foundation
import Combine
import SwiftUI
import AVKit
import UniformTypeIdentifiers

// MARK: - 1. Data Model
class VideoLibrary: ObservableObject {
    @Published var selectedVideo: URL?
    @Published var videos: [URL] = []
    
    func addVideos(urls: [URL]) {
        for url in urls {
            // Needed to access files outside the app sandbox
            guard url.startAccessingSecurityScopedResource() else { continue }
            
            if !videos.contains(url) {
                videos.append(url)
            }
        }
    }
}

// MARK: - 2. Main View
struct ContentView: View {
    @StateObject private var library = VideoLibrary()
    @State private var showingFilePicker = false

    var body: some View {
        NavigationSplitView {
            SidebarView(library: library, showingFilePicker: $showingFilePicker)
        } detail: {
            if let mediaURL = library.selectedVideo {
                PlayerView(mediaURL: mediaURL)
            } else {
                EmptyStateView(showingFilePicker: $showingFilePicker)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            // Added audio, mp3, and wav formats here
            allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie, .audio, .mp3, .wav],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                library.addVideos(urls: urls)
            case .failure(let error):
                print("File import error: \(error)")
            }
        }
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }
}

// MARK: - 3. Supporting Views

struct SidebarView: View {
    @ObservedObject var library: VideoLibrary
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        List(library.videos, id: \.self, selection: $library.selectedVideo) { video in
            Text(video.lastPathComponent)
                .tag(video as URL?)
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingFilePicker = true }) {
                    Label("Add Media", systemImage: "plus")
                }
            }
        }
    }
}

// UPGRADED: Now includes custom volume controls and state management
struct PlayerView: View {
    let mediaURL: URL
    @State private var player: AVPlayer?
    @State private var volume: Double = 1.0 // Volume goes from 0.0 to 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            if let player = player {
                // The main video/audio player
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                
                // Custom Volume Bar
                HStack(spacing: 15) {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    
                    Slider(value: Binding(
                        get: { self.volume },
                        set: { newValue in
                            self.volume = newValue
                            player.volume = Float(newValue)
                        }
                    ), in: 0...1)
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                }
                .padding()
                #if os(macOS)
                .background(Color(NSColor.controlBackgroundColor))
                #else
                .background(Color(UIColor.secondarySystemBackground))
                #endif
            }
        }
        .onAppear {
            setupPlayer(with: mediaURL)
        }
        // Handle when user clicks a new file in the sidebar
        .onChange(of: mediaURL) { oldValue,newValue in
            setupPlayer(with: newValue)
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    // Helper function to load and start playing the media
    private func setupPlayer(with url: URL) {
        player?.pause() // Stop the old player
        let newPlayer = AVPlayer(url: url)
        newPlayer.volume = Float(volume) // Apply the current volume slider setting
        player = newPlayer
        newPlayer.play() // Auto-play the newly selected file
    }
}

struct EmptyStateView: View {
    @Binding var showingFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.tv")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Media Selected")
                .font(.title2)
                .fontWeight(.medium)
            
            Button("Import Files") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
