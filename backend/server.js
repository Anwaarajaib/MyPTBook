import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import connectDB from "./config/db.js";
import userRoutes from "./routes/userRoutes.js";
import clientRoutes from './routes/clientRoutes.js';
import sessionRoutes from './routes/sessionRoutes.js'
import exerciseRoute from './routes/exerciseRoutes.js'



dotenv.config();

connectDB();

const app = express();

app.use(cors());
app.use(express.json());
app.get("/", (req, res) => {
  res.send("Backend running");
});

app.use("/api/user", userRoutes);
app.use('/api/client', clientRoutes);
app.use('/api/session', sessionRoutes)
app.use('/api/exercise', exerciseRoute)

// Serverless compatibility
if (process.env.NODE_ENV !== "production") {
  const PORT = process.env.PORT || 5001;
  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running locally on port ${PORT}`);
  });
}

export default app;
