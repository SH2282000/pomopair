import SwiftUI
import WebRTC
import SocketIO
import Combine
import UIKit


struct VideoCallView: View {
    @StateObject private var viewModel: VideoCallViewModel

    init(roomId: String? = nil, viewModel: VideoCallViewModel? = nil) {
        if let viewModel = viewModel {
            _viewModel = StateObject(wrappedValue: viewModel)
        } else {
            _viewModel = StateObject(wrappedValue: VideoCallViewModel(roomId: roomId))
        }
    }

    var body: some View {
        ZStack {
            // Remote Video (Full Screen) or Waiting State
            if let remoteTrack = viewModel.remoteVideoTrack {
                RTCVideoView(videoTrack: remoteTrack)
                    .edgesIgnoringSafeArea(.all)
            } else {
                WaitingView(viewModel: viewModel)
            }

            // Local Video (PiP)
            VStack {
                HStack {
                    if let localTrack = viewModel.localVideoTrack {
                        RTCVideoView(videoTrack: localTrack)
                            .frame(width: 120, height: 160)
                            .cornerRadius(10)
                            .shadow(radius: 10)
                            .padding()
                    }
                    Spacer()
                }
                Spacer()
            }

            // Controls & Timer Overlay
            if viewModel.remoteVideoTrack != nil {
                VStack {
                    HStack{
                        Spacer()
                        VideoCallControlsView(viewModel: viewModel)
                    }
                    Spacer()
                    TimerOverlayView(viewModel: viewModel.timerViewModel)
                    }
                }
        }
        .onAppear {
            viewModel.connect()
        }
    }
}

// Additional fix for VM init:
extension VideoCallViewModel {
    func startLocalVideo() {
        // WebRTCClient.startCapture() -> starts camera.
        // RTCVideoView.updateUIView -> adds uiView to track.
    }
}


#Preview("BEFORE CALL") {
    VideoCallView()
}

#Preview("IN CALL") {
    let viewModel = VideoCallViewModel(roomId: "PREVIEW_ROOM")

    let factory = RTCPeerConnectionFactory()
    let source = factory.videoSource()
    let track = factory.videoTrack(with: source, trackId: "previewTrack")

    viewModel.remoteVideoTrack = track

    return VideoCallView(viewModel: viewModel)
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
