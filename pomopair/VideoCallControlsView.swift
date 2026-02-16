import SwiftUI

struct VideoCallControlsView: View {
    @ObservedObject var viewModel: VideoCallViewModel

    var body: some View {
        VStack {
            Button(action: {
                viewModel.disconnect()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.title)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(.bottom, 20)

            // Media Controls
            Button(action: {
                viewModel.toggleMute()
            }) {
                Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.title2)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(.bottom, 20)

            Button(action: {
                viewModel.toggleSpeaker()
            }) {
                Image(systemName: viewModel.audioOutputIcon)
                    .font(.title2)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(.bottom, 20)

            Button(action: {
                viewModel.toggleVideo()
            }) {
                Image(systemName: viewModel.isVideoEnabled ? "video.fill" : "video.slash.fill")
                    .font(.title2)
                    .padding()
                    .background(Color.gray.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
        }
        .padding(.trailing, 10)
    }
}
