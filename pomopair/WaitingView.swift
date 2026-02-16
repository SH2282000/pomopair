import SwiftUI


struct WaitingView: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @State private var showShareSheet = false // maybe should be a binding

    var body: some View {
        ZStack {
            // Waiting State with Gradient Background
            LinearGradient(gradient: Gradient(colors: [Color.black, Color(UIColor.darkGray)]), startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 30) {
                Spacer()

                Text("Waiting for peer... 🌐🫂")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Share the link to start the session.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    // Smart Action: Check Clipboard -> Join OR Share
                    if !viewModel.attemptJoinFromClipboard() {
                        showShareSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                            .font(.headline)
                        Text(viewModel.isJoiner ? "Join Room" : "Invite Peer")
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
                .padding()
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [viewModel.shareUrl])
                }

                Spacer()
            }
        }
    }
}

struct PreviewWaitingView: View {
    @StateObject private var viewModel = VideoCallViewModel(roomId: "test")

    var body: some View {
        WaitingView(viewModel: viewModel)
    }
}

#Preview {
    PreviewWaitingView()
}
