import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import connectDB from "./config/db.js";
import authRoutes from "./routes/auth.js";

// Load environment variables
dotenv.config();

// Connect to the database
connectDB();

// Initialize the app
const app = express();

// Middleware
app.use(cors());
app.use(express.json());
// Root route to show "Backend running"
app.get("/", (req, res) => {
  res.send("Backend running");
});
// Routes
app.use("/api/auth", authRoutes);

// Serverless compatibility
if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 5001;
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running locally on port ${PORT}`);
  });
}

// Export the app for serverless environments like Vercel
export default app;
//hellobackend