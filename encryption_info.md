# Apple Export Compliance Encryption Documentation

**App Name:** Pomopair  
**Bundle ID:** shannah.pomopair  

## Overview
Pomopair utilizes standard encryption algorithms to secure peer-to-peer audio and video communications. This encryption is implemented via the WebRTC (Web Real-Time Communication) framework, which is included in the application bundle. Because the app includes its own implementation of these standard encryption protocols (via the WebRTC library) rather than relying solely on the operating system's native encryption APIs, it falls under the category of "Standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system."

## Encryption Implementation Details

### 1. Protocols Used
The app uses **DTLS-SRTP** (Datagram Transport Layer Security over Secure Real-time Transport Protocol) to establish secure peer-to-peer connections.

-   **DTLS (Datagram Transport Layer Security):** Used for key exchange and mutual authentication between peers.
-   **SRTP (Secure Real-time Transport Protocol):** Used for the actual encryption of audio and video media packets.

### 2. Cryptographic Algorithms
The WebRTC stack employs the following standard, non-proprietary algorithms:

*   **Key Exchange:** ECDH (Elliptic Curve Diffie-Hellman) or RSA.
*   **Authentication:** HMAC-SHA1.
*   **Encryption (Cipher Suites):**
    *   **AES-128-GCM** (Advanced Encryption Standard with 128-bit keys in Galois/Counter Mode)
    *   **AES-256-GCM**
    *   **AES-128-CTR** / **AES-256-CTR**

### 3. Purpose of Encryption
The encryption is used strictly for **Information Security**. It ensures the confidentiality and integrity of the real-time media streams (voice and video) flowing between user devices. It is not used for copyright protection or digital rights management.

## Export Classification (Self-Classification)
*   **Export Control Classification Number (ECCN):** 5D002 (Information Security Software)
*   **Authorization:** EAR740.17(b)(1) (Mass Market Encryption or Unrestricted Encryption Source Code)
*   **Category:** Mass Market / Publicly Available

## Summary
Pomopair uses standard WebRTC encryption (DTLS-SRTP) with AES-128/256-GCM and HMAC-SHA1 to secure peer-to-peer audio/video. The app includes these standard algorithms via the WebRTC library to ensure media confidentiality. It is Self-Classified as Mass Market (5D002).
