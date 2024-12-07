import express from 'express';
import { User } from '../models/User';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import multer from 'multer';
import { auth } from '../middleware/auth';

const router = express.Router();
const upload = multer();

// Register
router.post('/register', async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { name, email, password } = req.body;

    // Validate input
    if (!email || !password || !name) {
      res.status(400).json({ errors: ['All fields are required'] });
      return;
    }

    // Check if user exists
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      res.status(400).json({ errors: ['Email already registered'] });
      return;
    }

    const user = await User.create({
      name,
      email: email.toLowerCase(),
      password
    });

    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    );

    res.status(201).json({ token });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(400).json({ errors: ['Registration failed'] });
  }
});

// Login
router.post('/login', async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { email, password } = req.body;
    
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !(await user.comparePassword(password))) {
      res.status(401).json({ errors: ['Invalid email or password'] });
      return;
    }
    
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET!,
      { expiresIn: '7d' }
    );

    res.json({ token });
  } catch (error) {
    console.error('Login error:', error);
    res.status(400).json({ errors: ['Login failed'] });
  }
});

// Get current user profile
router.get('/me', auth, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const user = await User.findById((req as any).user.id);
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }
    res.json(user);
  } catch (error) {
    res.status(400).json({ error: 'Failed to fetch user profile' });
    return;
  }
});
// Update user profile
router.put('/me', auth, upload.single('profileImage'), async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const updates = { ...req.body };
    if (req.file) {
      updates.profileImageData = req.file.buffer;
    }

    // Don't allow password update through this route
    delete updates.password;
    const user = await User.findByIdAndUpdate(
      (req as any).user.id,
      updates,
      { new: true, runValidators: true }
    );
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(user);
  } catch (error) {
    res.status(400).json({ error: 'Failed to update profile' });
  }
});

// Change password
router.put('/change-password', auth, async (req: express.Request, res: express.Response): Promise<void> => {
  try {
    const { currentPassword, newPassword } = req.body as { currentPassword: string; newPassword: string };
    // Find user
    const user = await User.findById((req as any).user.id);
    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    // Compare current password
    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      res.status(401).json({ error: 'Current password is incorrect' });
      return;
    }

    // Update password
    user.password = newPassword;
    await user.save();

    res.json({ message: 'Password updated successfully' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(400).json({ error: 'Failed to change password' });
  }
});

// Health check endpoint
router.get('/health', (req: express.Request, res: express.Response) => {
  res.json({ status: 'ok' });
});

export default router;