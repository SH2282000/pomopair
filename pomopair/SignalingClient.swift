import Foundation
import SocketIO
import WebRTC

protocol SignalingClientDelegate: AnyObject {
    func signalClientDidConnect(_ signalClient: SignalingClient)
    func signalClientDidDisconnect(_ signalClient: SignalingClient)
    func signalClient(_ signalClient: SignalingClient, didReceiveRemoteSdp sdp: RTCSessionDescription)
    func signalClient(_ signalClient: SignalingClient, didReceiveCandidate candidate: RTCIceCandidate)
    func signalClientDidJoinRoom(_ signalClient: SignalingClient, isInitiator: Bool)
    func signalClient(_ signalClient: SignalingClient, didReceiveTimerEvent event: [String: Any])
}

final class SignalingClient {
    
    private let manager: SocketManager
    private let socket: SocketIOClient
    weak var delegate: SignalingClientDelegate?
    private let roomName: String
    
    init(serverUrl: URL, roomName: String) {
        self.manager = SocketManager(socketURL: serverUrl, config: [.log(true), .compress])
        self.socket = manager.defaultSocket
        self.roomName = roomName
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
                    guard let candidateData = data["candidate"] as? [String: Any],
                          let sdp = candidateData["candidate"] as? String ?? data["candidate"] as? String,
                          let sdpMLineIndex = candidateData["sdpMLineIndex"] as? Int32 ?? data["sdpMLineIndex"] as? Int32,
                          let sdpMid = candidateData["sdpMid"] as? String ?? data["sdpMid"] as? String else { return }
                    
                    let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                    self.delegate?.signalClient(self, didReceiveCandidate: candidate)
                } else if type == "timer" {
                    // Decoder timer event from SDP field (which we used as a payload carrier)
                    if let payloadString = data["sdp"] as? String,
                       let payloadData = payloadString.data(using: .utf8),
                       let event = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] {
                        self.delegate?.signalClient(self, didReceiveTimerEvent: event)
                    }
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
    
    func send(timerEvent: [String: Any]) {
        // Encode event as JSON string and put in 'sdp' field
        guard let jsonData = try? JSONSerialization.data(withJSONObject: timerEvent, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        let signalData: [String: Any] = [
            "room": self.roomName,
            "type": "timer",
            "sdp": jsonString
        ]
        socket.emit("signal", signalData)
    }
}
