import Foundation
import SocketIO
import WebRTC

protocol SignalingClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
    func signalClientDidJoinRoom(_ signalClient: SignalingClient, isInitiator: Bool)
}

final class SignalingClient {
    
    private let manager: SocketManager
    private let socket: SocketIOClient
    weak var delegate: SignalingClientDelegate?
    private let roomName = "test_room" // Hardcoded for simplicity/testing
    
    init(serverUrl: URL) {
        self.manager = SocketManager(socketURL: serverUrl, config: [.log(true), .compress])
        self.socket = manager.defaultSocket
    }
    
    func connect() {
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
            guard let self = self else { return }
            self.delegate?.signalClientDidConnect(self)
            
            // Auto-join room on connect
            self.socket.emit("join", self.roomName)
        }
        
        socket.on("created") { [weak self] data, ack in
            print("Room created - You are the initiator")
            guard let self = self else { return }
            self.delegate?.signalClientDidJoinRoom(self, isInitiator: true)
        }
        
        socket.on("joined") { [weak self] data, ack in
            print("Room joined - You are the peer")
            guard let self = self else { return }
            self.delegate?.signalClientDidJoinRoom(self, isInitiator: false)
        }
        
        socket.on("full") { data, ack in
            print("Room is full")
        }
        
        // Unified "signal" event from server
        socket.on("signal") { [weak self] data, ack in
            print("Received signal: \(data)")
            guard let self = self,
                  let data = data.first as? [String: Any] else { return }
            
            if let type = data["type"] as? String {
                if type == "offer" || type == "answer" {
                    guard let sdp = data["sdp"] as? String else { return }
                    let sdpType: RTCSdpType = (type == "offer") ? .offer : .answer
                    let sessionDescription = RTCSessionDescription(type: sdpType, sdp: sdp)
                    self.delegate?.signalClient(self, didReceiveRemoteSdp: sessionDescription)
                } else if type == "candidate" {
                    guard let candidateData = data["candidate"] as? [String: Any], // Wrapped in candidate object or flat?
                          // Based on server.js: socket.to(data.room).emit("signal", { type: data.type, sdp: data.sdp, candidate: data.candidate });
                          // The client usually sends "candidate" object in the "signal" wrapper.
                          // Let's assume the payload sent by client (and reflected by server) is flat or nested.
                          // Let's be robust: Support both 'sdp'+'sdpMLineIndex' at top level OR inside 'candidate'
                          let sdp = candidateData["candidate"] as? String ?? data["candidate"] as? String, // Careful with naming collision
                          let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32 ?? data["sdpMLineIndex"] as? Int32,
                          let sdpMid = candidateData["sdpMid"] as? String ?? data["sdpMid"] as? String else { return }
                    
                    let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                    self.delegate?.signalClient(self, didReceiveCandidate: candidate)
                }
            }
        }
        
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func send(sdp rtcSdp: RTCSessionDescription) {
        let type = (rtcSdp.type == .offer) ? "offer" : "answer"
        let signalData: [String: Any] = [
            "room": self.roomName,
            "type": type,
            "sdp": rtcSdp.sdp
        ]
        socket.emit("signal", signalData)
    }
    
    func send(candidate rtcCandidate: RTCIceCandidate) {
        let candidateDict: [String: Any] = [
            "candidate": rtcCandidate.sdp,
            "sdpMLineIndex": rtcCandidate.sdpMLineIndex,
            "sdpMid": rtcCandidate.sdpMid ?? ""
        ]
        
        let signalData: [String: Any] = [
            "room": self.roomName,
            "type": "candidate",
            "candidate": candidateDict
        ]
        socket.emit("signal", signalData)
    }
}
