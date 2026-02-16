//
//  VideoCallViewModel.swift
//  pomopair
//
//  Created by Shannah on 16/02/2026.
//

import SwiftUI
import WebRTC
import SocketIO
import Combine
import UIKit


class VideoCallViewModel: NSObject, ObservableObject {

    // Changed to var to allow reconnection to different rooms
    private var signalingClient: SignalingClient
    private let webRTCClient: WebRTCClient
    let timerViewModel = TimerViewModel()

    @Published var localVideoTrack: RTCVideoTrack?
    @Published var remoteVideoTrack: RTCVideoTrack?

    // Room State - Changed to @Published var for dynamic updates
    @Published var roomId: String
    @Published var isJoiner: Bool // True if we joined via link, False if we created the room

    // Media State
    @Published var isMuted: Bool = false
    @Published var isVideoEnabled: Bool = true
    @Published var audioOutput: WebRTCClient.AudioOutput = .speaker

    var audioOutputIcon: String {
        switch audioOutput {
        case .mute: return "speaker.slash.fill"
        case .ear: return "ear"
        case .speaker: return "speaker.wave.3.fill"
        }
    }

    var shareUrl: URL {
        return URL(string: "https://85-214-6-146.nip.io/join/\(roomId)")!
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            webRTCClient.muteAudio()
        } else {
            webRTCClient.unmuteAudio()
        }
    }

    func toggleVideo() {
        isVideoEnabled.toggle()
        if isVideoEnabled {
            webRTCClient.showVideo()
        } else {
            webRTCClient.hideVideo()
        }
    }

    func toggleSpeaker() {
        // Cycle: Speaker -> Mute -> Low/Ear -> Speaker
        switch audioOutput {
        case .speaker:
            audioOutput = .mute
        case .mute:
            audioOutput = .ear
        case .ear:
            audioOutput = .speaker
        }
        webRTCClient.setAudioOutput(audioOutput)
    }

    init(roomId: String? = nil) {
        // Using the predefined infrastructure from prompt
        let signalUrl = URL(string: "http://85.214.6.146:3000")!
        let turnServers = [""]

        // Determine Room ID and Role locally
        let finalRoomId: String
        let finalIsJoiner: Bool

        if let id = roomId {
            finalRoomId = id
            finalIsJoiner = true
        } else {
            finalRoomId = UUID().uuidString
            finalIsJoiner = false
        }

        self.roomId = finalRoomId
        self.isJoiner = finalIsJoiner

        print("VideoCallViewModel initialized. Room: \(finalRoomId), isJoiner: \(finalIsJoiner)")

        self.signalingClient = SignalingClient(serverUrl: signalUrl, roomName: finalRoomId)
        self.webRTCClient = WebRTCClient(iceServers: turnServers)

        super.init()

        self.signalingClient.delegate = self
        self.webRTCClient.delegate = self

        self.webRTCClient.startCaptureLocalVideo()
        self.localVideoTrack = self.webRTCClient.localVideoTrack

        // Initialize Audio Output
        self.webRTCClient.setAudioOutput(self.audioOutput)

        // Setup Timer Connection
        self.timerViewModel.onTimerUpdate = { [weak self] action, payload in
            guard let self = self else { return }
            print("Sending timer event: \(action)")
            // Wrap in payload for network
            var event = payload
            event["action"] = action
            self.signalingClient.send(timerEvent: event)
        }
    }

    func connect() {
        self.signalingClient.connect()
    }

    func disconnect() {
        self.webRTCClient.peerConnection?.close()
        self.signalingClient.disconnect()
        self.localVideoTrack = nil
        self.remoteVideoTrack = nil
        // In a real app we might want to dismiss the view or navigate back here
    }

    func attemptJoinFromClipboard() -> Bool {
        guard let clipboardString = UIPasteboard.general.string else { return false }

        // Check for basic format: https://85-214-6-146.nip.io/join/<UUID>
        // Or just raw UUID if we want to be permissive, but user asked for "matching the pattern"
        let pattern = "https://85-214-6-146.nip.io/join/"

        if clipboardString.hasPrefix(pattern) {
            let extractedUuid = clipboardString.replacingOccurrences(of: pattern, with: "")
            // Validate UUID simply by checking length or attempting init (though init is strict)
            if !extractedUuid.isEmpty {
                 joinNewRoom(id: extractedUuid)
                 return true
            }
        }
        return false
    }

    private func joinNewRoom(id: String) {
        print("Switching to room: \(id)")
        // 1. Disconnect current
        self.signalingClient.disconnect()

        // 2. Update State
        self.roomId = id
        self.isJoiner = true
        self.remoteVideoTrack = nil // Clear remote track

        // 3. Re-init Signaling Client with new room
        let signalUrl = URL(string: "http://85.214.6.146:3000")!
        self.signalingClient = SignalingClient(serverUrl: signalUrl, roomName: self.roomId)
        self.signalingClient.delegate = self

        // 4. Connect
        self.signalingClient.connect()
    }
}


extension VideoCallViewModel: SignalingClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        print("Signaling Connected - Waiting to join room...")
    }

    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        print("Signaling Disconnected")
    }

    func signalClientDidJoinRoom(_ signalClient: SignalingClient, isInitiator: Bool) {
        // Logic adaptation based on server.js limitation:
        // The server sends 'created' to the first user but does NOT notify them when user 2 joins.
        // The server sends 'joined' to the second user.
        // Therefore, the user who receives 'joined' (isInitiator == false) knows connection is ready and must OFFER.

        print("Joined room. Role: \(isInitiator ? "Creator (Wait)" : "Joiner (Offer)")")

        if !isInitiator {
            // We are the second one in, so we start the call
            print("I am the joiner. Creating offer.")
            self.webRTCClient.offer { sdp in
                self.signalingClient.send(sdp: sdp)
            }
        } else {
             print("I am the creator. Waiting for joiner to offer.")
        }
    }

    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription) {
        print("Received Remote SDP: \(sdp.type.rawValue)")
        self.webRTCClient.set(remoteSdp: sdp) { error in
            if sdp.type == .offer {
                self.webRTCClient.answer { answerSdp in
                    self.signalingClient.send(sdp: answerSdp)
                }
            }
        }
    }

    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate) {
        print("Received Remote Candidate")
        self.webRTCClient.set(remoteCandidate: candidate)
    }

    func signalClient(_ signalClient: SignalingClient, didReceiveTimerEvent event: [String: Any]) {
        print("Received Timer Event")
        if let action = event["action"] as? String {
            self.timerViewModel.updateFromRemote(action: action, payload: event)
        }
    }
}

extension VideoCallViewModel: WebRTCClientDelegate {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate) {
        print("Discovered local candidate")
        self.signalingClient.send(candidate: candidate)
    }

    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState) {
        DispatchQueue.main.async {
            print("Connection state changed: \(state)")
        }
    }

    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data) {
        // handle data channel
    }

    func webRTCClient(_ client: WebRTCClient, didAddRemoteVideoTrack track: RTCVideoTrack) {
        print("Did add remote video track")
        DispatchQueue.main.async {
            self.remoteVideoTrack = track
        }
    }
}
