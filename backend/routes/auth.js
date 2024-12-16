import express from 'express';
import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import auth from '../middleware/auth.js';

const router = express.Router();

// Register
router.post('/register', async (req, res) => {
    try {
        console.log('Register request received:', req.body);

        const { name, email, password } = req.body;

        // Check if user exists
        const userExists = await User.findOne({ email });
        if (userExists) {
            console.log(`User already exists: ${email}`);
            return res.status(400).json({ message: 'User already exists' });
        }

        // Create user
        const user = await User.create({
            name,
            email,
            password
        });

        if (user) {
            console.log(`User created successfully: ${user._id}`);
            res.status(201).json({
                _id: user._id,
                name: user.name,
                email: user.email,
                token: generateToken(user._id)
            });
        }
    } catch (error) {
        console.error('Error in register:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
});

// Login
router.post('/login', async (req, res) => {
    try {
        console.log('Login request received:', req.body);

        const { email, password } = req.body;

        // Find user
        const user = await User.findOne({ email });

        if (user && (await user.matchPassword(password))) {
            console.log(`Login successful for user: ${user._id}`);
            res.json({
                _id: user._id,
                name: user.name,
                email: user.email,
                token: generateToken(user._id)
            });
        } else {
            console.log(`Invalid credentials for email: ${email}`);
            res.status(401).json({ message: 'Invalid email or password' });
        }
    } catch (error) {
        console.error('Error in login:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
});

// Get user profile
router.get('/profile', auth, async (req, res) => {
    try {
        console.log('Profile request for user:', req.user.id);

        const user = await User.findById(req.user.id).select('-password');
        if (user) {
            console.log('Profile data retrieved successfully');
            res.json(user);
        } else {
            console.log('User not found');
            res.status(404).json({ message: 'User not found' });
        }
    } catch (error) {
        console.error('Error retrieving user profile:', error.message);
        res.status(500).json({ message: 'Server error' });
    }
});

// Generate JWT
const generateToken = (id) => {
    console.log(`Generating token for user ID: ${id}`);
    return jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: '30d'
    });
};

export default router;
