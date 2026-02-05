import SwiftUI

struct ContentView: View {
    var activeRoomId: String?

    var body: some View {
        VideoCallView(roomId: activeRoomId)
    }
}

#Preview {
    ContentView()
}
