# Pomopair

Pomopair is a privacy-focused, peer-to-peer productivity app designed for remote body doubling. It combines high-quality video calling with a synchronized Pomodoro timer, allowing users to stay focused and accountable with a partner anywhere in the world.

## Features & Mechanisms

### 1. Peer-to-Peer Video & Audio
**Mechanism:** WebRTC (Web Real-Time Communication)
Pomopair establishes a direct connection between two devices.
-   **Signaling:** Uses a lightweight Socket.IO server to exchange initial connection details (SDP offers/answers and ICE candidates).
-   **Media Stream:** Once connected, video and audio data flow directly between peers, bypassing the server entirely. This ensures low latency and high quality.

### 2. Synchronized Focus Timer
**Mechanism:** Real-time Event Propagation
The Pomodoro timer state is synchronized instantly between both users.
-   When one user starts, pauses, or resets the timer, the event is transmitted to the peer.
-   This ensures both partners are always on the exact same schedule, fostering a shared sense of deep work.

### 3. Instant Joining via Deep Links
**Mechanism:** Universal Links & Deferred Deep Linking
Joining a session is frictionless.
-   **Universal Links:** Users can share a link like `https://85-214-6-146.nip.io/join/<UUID>`. Tapping this link immediately opens the app and joins the specific room.
-   **Clipboard Fallback:** If a user doesn't have the app installed, the web landing page copies the Room UUID to their clipboard. Upon first launch, Pomopair detects this UUID and automatically enters the session.

## Data Privacy & Security

Pomopair is built with a **Privacy-First** architecture.

-   **Peer-to-Peer Media:** Your video and audio streams **never** touch our servers. They travel directly from your device to your partner's device using end-to-end WebRTC encryption. We cannot record, listen to, or see your calls.
-   **Ephemeral Rooms:** Rooms are dynamically generated using random UUIDs and are transient. No room history or session logs are stored permanently.
-   **Minimal Server Footprint:** The signaling server is only used for the initial handshake (metadata exchange). Once the connection is established, the server's job is done. Your personal data remains on your device.
