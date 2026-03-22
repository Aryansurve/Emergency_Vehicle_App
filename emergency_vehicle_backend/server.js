const express = require("express");
const dotenv = require("dotenv");
dotenv.config();
const connectDB = require("./src/config/db");
const authRoutes = require("./src/routes/authRoutes");
const adminRoutes = require("./src/routes/adminRoutes");
const hospitalRoutes = require("./src/routes/hospitalRoutes");
const hospitalAdminRoutes = require("./src/routes/hospitalAdminRoutes");
const driverRoutes = require("./src/routes/driverRoutes"); // <-- ADD THIS LINE
const publicRoutes = require("./src/routes/publicRoutes"); // <-- ADD THIS LINE
const rtoRoutes = require("./src/routes/rtoRoutes");
// ... app setup

// Routes

// ... rest of the file
// Load environment variables

// Connect to the database

const app = express();
connectDB();
const cors = require("cors");
app.use(cors()); // This allows the Flutter app to send files to the Node server
// Middleware
app.use(express.json());
app.use("/api/v1/rto", rtoRoutes);
app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/admin", adminRoutes);
app.use("/api/v1/hospitals", hospitalRoutes);
app.use("/api/v1/hospital-admin", hospitalAdminRoutes);
app.use("/api/v1/driver", driverRoutes); // Corrected from '/vli'
app.use("/api/v1/public", publicRoutes); // <-- ADD THIS LINE

// Test route
app.get("/", (req, res) => {
  res.send("API is running...");
});

const PORT = process.env.PORT || 5000;

const server = require("http").createServer(app); // Create an HTTP server from your Express app
const io = require("socket.io")(server, {
  cors: {
    origin: "*", // For development, allow all connections. For production, restrict this.
  },
});
const onlineDrivers = new Map();

// --- REAL-TIME LOGIC ---
io.on("connection", (socket) => {
  console.log(`🔌 New client connected: ${socket.id}`);

  // Task B: A driver comes online and identifies themselves
  socket.on("driverOnline", (userId) => {
    console.log(`🚗 Driver ${userId} is online with socket ${socket.id}`);
    onlineDrivers.set(userId, socket.id);
  });

  // Task A: A public user joins a tracking room
  socket.on("joinTrackingRoom", (trackingId) => {
    console.log(`👀 Public user joined tracking room: ${trackingId}`);
    socket.join(trackingId);
  });

  // A driver sends a location update
  socket.on("updateLocation", (data) => {
    // Broadcast to the admin dashboard
    socket.broadcast.emit("driverLocation", { driverId: socket.id, ...data });

    // Task A: If the location update includes a trackingId, send it to that specific room
    if (data.trackingId) {
      io.to(data.trackingId).emit("missionUpdate", {
        latitude: data.latitude,
        longitude: data.longitude,
      });
    }
  });

  // --- Add this inside your io.on('connection') block ---

  // Listener for the App to trigger physical hardware
  socket.on("activateHardwareSignal", (data) => {
    console.log(
      `🚨 Hardware Trigger Received from ${socket.id}. Logic: ${data.logic}`,
    );

    // Broadcast to the Raspberry Pi (and everyone else for safety)
    // You can also use socket.broadcast.emit if you don't want the sender to get it back
    io.emit("hardwareTrigger", {
      command: "SET_GREEN",
      lane: data.lane || 1, // Optional: specify which lane if your model has 4
      timestamp: new Date(),
    });
  });

  socket.on("disconnect", () => {
    console.log(`🔌 Client disconnected: ${socket.id}`);
    // Remove driver from the online list upon disconnect
    for (let [userId, socketId] of onlineDrivers.entries()) {
      if (socketId === socket.id) {
        onlineDrivers.delete(userId);
        console.log(`🚗 Driver ${userId} went offline.`);
        break;
      }
    }
  });
});

// --- END OF REAL-TIME LOGIC ---
server.listen(PORT, "0.0.0.0", () =>
  console.log(
    `🚀 Server running in ${process.env.NODE_ENV} mode on port ${PORT}`,
  ),
);

// Handle unhandled promise rejections
process.on("unhandledRejection", (err, promise) => {
  console.log(`Error: ${err.message}`);
  server.close(() => process.exit(1));
});
