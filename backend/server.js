import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import connectDB from "./config/db.js";
import userRoutes from "./routes/userRoutes.js";
import clientRoutes from "./routes/clientRoutes.js";
import sessionRoutes from "./routes/sessionRoutes.js";
import exerciseRoute from "./routes/exerciseRoutes.js";
import nutritionRoutes from "./routes/nutritionRoutes.js";

dotenv.config();

// Database connection
connectDB();

const app = express();

// Add detailed logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.url}`);
  next();
});

// Middleware
app.use(
  cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);
app.use(express.json());

// Default route
app.get("/", (req, res) => {
  res.send("Backend running");
});

// API routes
app.use("/api/user", userRoutes);
app.use("/api/client", clientRoutes);
app.use("/api/session", sessionRoutes);
app.use("/api/exercise", exerciseRoute);
app.use("/api/nutrition", nutritionRoutes);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Error:", err);
  res.status(500).json({ message: err.message });
});

// Handle unhandled promise rejections
process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
});

// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  console.error("Uncaught Exception:", error.message);
});

// For local development
if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 5001;
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Try accessing: http://localhost:${PORT}/api/user/login`);
  });
}

// Export app for serverless platforms (like Vercel)
export default app;
