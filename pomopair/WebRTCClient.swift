import Foundation
import WebRTC

protocol WebRTCClientDelegate: AnyObject {
    func webRTCClient(_ client: WebRTCClient, didDiscoverLocalCandidate candidate: RTCIceCandidate)
    func webRTCClient(_ client: WebRTCClient, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCClient(_ client: WebRTCClient, didReceiveData data: Data)
    func webRTCClient(_ client: WebRTCClient, didAddRemoteVideoTrack track: RTCVideoTrack)
}

final class WebRTCClient: NSObject {
    
    // MARK: - Properties
    private let factory: RTCPeerConnectionFactory
    var peerConnection: RTCPeerConnection?
    
    weak var delegate: WebRTCClientDelegate?
    private let mediaConstrains = [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                   kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
    
    var localVideoTrack: RTCVideoTrack?
    var remoteVideoTrack: RTCVideoTrack?
    var remoteAudioTrack: RTCAudioTrack?
    var currentAudioOutput: AudioOutput = .speaker // Default to match VM

    enum AudioOutput {
        case mute
        case speaker
        case ear
    }
    
    @available(*, unavailable)
    override init() {
        fatalError("WebRTCClient:init is unavailable")
    }
    
    required init(iceServers: [String]) {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        super.init()
        setup(iceServers: iceServers)
    }
    
    // MARK: - Public
    func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection?.offer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
        let constrains = RTCMediaConstraints(mandatoryConstraints: self.mediaConstrains,
                                             optionalConstraints: nil)
        self.peerConnection?.answer(for: constrains) { (sdp, error) in
            guard let sdp = sdp else {
                return
            }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { (error) in
                completion(sdp)
            })
        }
    }
    
    func set(remoteSdp: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        self.peerConnection?.setRemoteDescription(remoteSdp, completionHandler: completion)
    }
    
    func set(remoteCandidate: RTCIceCandidate) {
        self.peerConnection?.add(remoteCandidate)
    }
    
    func startCaptureLocalVideo() {
        guard let capturer = self.videoCapturer as? RTCCameraVideoCapturer else { return }
        // Find front camera
        guard let frontCamera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }) else {
            return
        }
        
        // Find compatible format (priority: 1280x720 @ 30fps)
        let targetWidth = 1280
        let targetHeight = 720
        let targetFps = 30
        
        var selectedFormat: AVCaptureDevice.Format?
        var selectedFps: Int = targetFps
        
        for format in RTCCameraVideoCapturer.supportedFormats(for: frontCamera) {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            
            // WebRTC supports NV12 (420v) and 420f usually
            if dimensions.width == targetWidth && dimensions.height == targetHeight {
                 for range in format.videoSupportedFrameRateRanges {
                     if Int(range.maxFrameRate) >= targetFps {
                         selectedFormat = format
                         selectedFps = targetFps // caps at 30
                         break
                     }
                 }
            }
            if selectedFormat != nil { break }
        }
        
        // Fallback to whatever is available if 720p not found
        if selectedFormat == nil {
             selectedFormat = RTCCameraVideoCapturer.supportedFormats(for: frontCamera).last
        }
        
        guard let format = selectedFormat else { return }
        
        capturer.startCapture(with: frontCamera, format: format, fps: selectedFps)
    }
    
    // MARK: - Media Control
    func muteAudio() {
        self.setAudioEnabled(false)
    }
    
    func unmuteAudio() {
        self.setAudioEnabled(true)
    }
    
    // Fallback: If strict speaker toggle is needed:
    func setAudioOutput(_ output: AudioOutput) {
        self.currentAudioOutput = output
        let session = AVAudioSession.sharedInstance()
        do {
            switch output {
            case .mute:
                self.remoteAudioTrack?.isEnabled = false
            case .speaker:
                self.remoteAudioTrack?.isEnabled = true
                try session.overrideOutputAudioPort(.speaker)
            case .ear:
                self.remoteAudioTrack?.isEnabled = true
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Error setting audio output: \(error)")
        }
    }
    
    func hideVideo() {
        self.localVideoTrack?.isEnabled = false
    }
    
    func showVideo() {
        self.localVideoTrack?.isEnabled = true
    }
    
    private func setAudioEnabled(_ isEnabled: Bool) {
        if let audioTransceiver = self.peerConnection?.transceivers.first(where: { $0.mediaType == .audio }),
           let track = audioTransceiver.sender.track as? RTCAudioTrack {
            track.isEnabled = isEnabled
        }
    }
    
    // MARK: - Private
    private func setup(iceServers: [String]) {
        let config = RTCConfiguration()
        
        // Convert string URLs to RTCIceServer
        // Note: In a real app we would parse user/pass too, passing simplified here based on request or hardcoded
        // The prompt gave specific TURN with user/pass
        
        // HARDCODED TURN based on Prompt
        let turnServer = RTCIceServer(urlStrings: ["turn:85.214.6.146:3478"],
                                      username: "myuser",
                                      credential: "mypassword")
        
        // HARDCODED STUN based on Prompt
        let stunServer = RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        
        config.iceServers = [turnServer, stunServer]
        config.sdpSemantics = .unifiedPlan
        // config.continuouslyGatherIceCandidates = true // Not available in all versions
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])
        
        self.peerConnection = self.factory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        self.createMediaSenders()
        self.configureAudioSession()
    }
    
    private func createMediaSenders() {
        let streamId = "stream"
        
        // Audio
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.factory.audioSource(with: audioConstrains)
        let audioTrack = self.factory.audioTrack(with: audioSource, trackId: "audio0")
        self.peerConnection?.add(audioTrack, streamIds: [streamId])
        
        // Video
        let videoSource = self.factory.videoSource()
        self.videoCapturer = RTCCameraVideoCapturer(delegate: videoSource)
        let videoTrack = self.factory.videoTrack(with: videoSource, trackId: "video0")
        self.localVideoTrack = videoTrack
        self.peerConnection?.add(videoTrack, streamIds: [streamId])
    }
    
    private var videoCapturer: RTCVideoCapturer?
    
    private func configureAudioSession() {
        // Use standard background queue for audio session config
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, options: [.allowBluetoothHFP])
                try session.setActive(true)
            } catch {
                print("AVAudioSession configuration error: \(error)")
            }
        }
    }
}

extension WebRTCClient: RTCPeerConnectionDelegate {
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("peerConnection new signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("peerConnection new connection state: \(newState)")
        self.delegate?.webRTCClient(self, didChangeConnectionState: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("peerConnection new gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        self.delegate?.webRTCClient(self, didDiscoverLocalCandidate: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("didAdd stream")
        if let track = stream.videoTracks.first {
            print("found remote video track")
            self.remoteVideoTrack = track
            self.delegate?.webRTCClient(self, didAddRemoteVideoTrack: track)
        }
        if let audioTrack = stream.audioTracks.first {
            print("found remote audio track")
            audioTrack.isEnabled = (self.currentAudioOutput != .mute)
            self.remoteAudioTrack = audioTrack
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
}
