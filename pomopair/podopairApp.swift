//
//  pomopairApp.swift
//  pomopair
//
//  Created by Shannah on 19/01/2026.
//

import SwiftUI
import SwiftData

@main
struct pomopairApp: App {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @State private var activeRoomId: String?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(activeRoomId: activeRoomId)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onAppear {
                    checkClipboardForRoom()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Expected URL: https://85-214-6-146.nip.io/join/<UUID>
        print("Incoming URL: \(url)")
        
        let pathComponents = url.pathComponents
        // pathComponents usually looks like ["/", "join", "UUID"]
        
        if let joinIndex = pathComponents.firstIndex(of: "join"),
           joinIndex + 1 < pathComponents.count {
            let roomId = pathComponents[joinIndex + 1]
            print("Extracted Room ID from URL: \(roomId)")
            self.activeRoomId = roomId
        }
    }
    
    private func checkClipboardForRoom() {
        if !hasLaunchedBefore {
            // First launch check
            if let clipboardString = UIPasteboard.general.string {
                // simple check if it looks like a uuid or contains our link
                // The prompt says "If it contains a valid UUID".
                // Let's be robust: Check if it IS a UUID.
                
                if let uuid = UUID(uuidString: clipboardString) {
                    print("Found UUID in clipboard on first launch: \(uuid.uuidString)")
                    self.activeRoomId = uuid.uuidString
                }
            }
            hasLaunchedBefore = true
            // Save immediately so we don't check again next time
        }
    }
}
