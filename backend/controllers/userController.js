import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import crypto from 'crypto'
import nodemailer from 'nodemailer'
import bcrypt from 'bcryptjs'

export const login = async (req, res) => {
    try {
        console.log('Processing login request');
        const { email, password } = req.body;
        console.log('Login attempt for email:', email);
        
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user) {
            console.log('User not found');
            return res.status(401).json({ message: "Invalid email or password" });
        }

        const isValidPassword = await user.comparePassword(password);
        console.log('Password validation result:', isValidPassword);
        
        if (!isValidPassword) {
            console.log('Invalid password');
            return res.status(401).json({ message: "Invalid email or password" });
        }

        const token = jwt.sign(
            { userId: user._id },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
        
        console.log('Login successful for user:', user._id);
        
        res.json({
            token,
            user: {
                id: user._id.toString(),
                name: user.name,
                email: user.email
            }
        });
    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ message: error.message });
    }
};

export const register = async (req, res) => {
    try {
        const { name, email, password } = req.body;
        const existingUser = await User.findOne({ email: email.toLowerCase() });
        if (existingUser) {
            return res.status(400).json({ message: "Email already registered" });
        }
        const user = new User({
            name,
            email: email.toLowerCase(),
            password
        });
        await user.save();
        const token = jwt.sign(
            { userId: user._id },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
        res.status(201).json({
            token,
            user: {
                id: user._id,
                name: user.name,
                email: user.email
            }
        });
    } catch (error) {
        console.error('Registration error:', error);
        res.status(400).json({ message: error.message });
    }
};

export const verifyToken = async (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        if (!token) {
            return res.status(401).json({ message: "No token provided" });
        }
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(401).json({ message: "Invalid token" });
        }
        res.json({ valid: true });
    } catch (error) {
        res.status(401).json({ message: "Invalid token" });
    }
};

export const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user) {
            return res.status(404).json({ message: "No user exists with this email" });
        }

        // Generate reset token
        const resetToken = crypto.randomBytes(20).toString('hex');
        const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');

        // Save hashed token and expiry to user
        user.resetPasswordToken = hashedToken;
        user.resetPasswordExpires = Date.now() + 3600000; // 1-hour validity
        await user.save();
        const transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_PASSWORD,
            },
        });

        const mailOptions = {
            to: user.email,
            from: process.env.EMAIL_USER,
            subject: 'Password Reset - MyPTBook',
            text: `You are receiving this email because you (or someone else) requested a password reset for your account.\n\n
                    Please click on the following link, or paste it into your browser, to complete the process:\n\n
                    http://${req.headers.host}/reset-password/${resetToken}\n\n
                    Here's the reset token ${resetToken}\n\n
                    If you did not request this, please ignore this email and your password will remain unchanged.\n`,
        };

        await transporter.sendMail(mailOptions);

        res.status(200).json({ message: "Password reset token sent to email" });
    } catch (error) {
        console.error('Forgot password error:', error);
        res.status(500).json({ message: 'Error sending password reset email', error });
    }
};


export const resetPassword = async (req, res) => {
    try {
        const { resetToken } = req.params;
        const { newPassword } = req.body;
        const hashedToken = crypto.createHash('sha256').update(resetToken).digest('hex');

        const user = await User.findOne({
            resetPasswordToken: hashedToken,
            resetPasswordExpires: { $gt: Date.now() },
        });

        if (!user) {
            return res.status(400).json({ message: 'Invalid or expired reset token' });
        }
        user.password = newPassword;
        user.resetPasswordToken = undefined;
        user.resetPasswordExpires = undefined;

        await user.save();
        res.status(200).json({ message: 'Password has been successfully updated' });
    } catch (error) {
        console.error('Reset password error:', error);
        res.status(500).json({ message: 'Error resetting password', error });
    }
};



export const updateProfile = async (req, res) => {
    try {
        const updateData = {
            name: req.body.name,
            userImage: req.body.userImage,
        };
        const updatedUser = await User.findByIdAndUpdate(
            req.user._id,
            updateData,
            { new: true }
        ).select('-password');
        if (!updatedUser) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.json({
            id: updatedUser._id,
            name: updatedUser.name,
            email: updatedUser.email
        });
    } catch (error) {
        console.error('Error updating profile:', error);
        res.status(400).json({ message: error.message });
    }
};

export const getProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('-password');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        res.json({
            id: user._id,
            name: user.name,
            email: user.email
        });
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
}; 