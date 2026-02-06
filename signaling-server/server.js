// npm install socket.io
const io = require("socket.io")(3000, {
  cors: { origin: "*" }
});

io.on("connection", (socket) => {

  // 1. Join a specific "room" (e.g., 'room-1')
  socket.on("join", (roomId) => {
    console.log("User " + socket.id + " joining room " + roomId);
    const clients = io.sockets.adapter.rooms.get(roomId);
    const numClients = clients ? clients.size : 0;
    console.log("Number of clients in room " + roomId + ": " + (numClients + 1));

    if (numClients === 0) {
      socket.join(roomId);
      socket.emit("created"); // You are the Caller
    } else if (numClients === 1) {
      socket.join(roomId);
      socket.emit("joined"); // You are the Callee, ready to answer
    } else {
      socket.emit("full"); // Room is full (P2P limit)
    }
  });

  // 2. Relay Signaling Messages (Offer, Answer, ICE Candidates)
  socket.on("signal", (data) => {
    // Broadcast to the OTHER person in the room
    socket.to(data.room).emit("signal", {
      type: data.type,
      sdp: data.sdp,
      candidate: data.candidate
    });
  });
});

console.log("Signaling Server running on port 3000");
