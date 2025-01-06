import jwt from 'jsonwebtoken';
import User from '../models/User.js';
import crypto from 'crypto'
import nodemailer from 'nodemailer'
import bcrypt from 'bcryptjs'
import { cloudinary } from '../config/cloudinary.js';

export const login = async (req, res) => {
    try {
        console.log('Processing login request');
        const { email, password } = req.body;
        
        const user = await User.findOne({ email: email.toLowerCase() });
        if (!user) {
            console.log('User not found');
            return res.status(401).json({ message: "Invalid email or password" });
        }

        const isValidPassword = await user.comparePassword(password);
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
        console.log('User data:', {
            id: user._id,
            name: user.name,
            email: user.email,
            userImage: user.userImage || null
        });
        
        res.json({
            token,
            user: {
                id: user._id.toString(),
                name: user.name,
                email: user.email,
                userImage: user.userImage || null
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
        console.log('Updating profile with data:', req.body);
        const updateData = {
            name: req.body.name
        };
        
        // Only update userImage if it's provided
        if (req.body.userImage) {
            updateData.userImage = req.body.userImage;
        }
        
        console.log('Update data:', updateData);
        
        const updatedUser = await User.findByIdAndUpdate(
            req.user._id,
            updateData,
            { new: true }
        ).select('-password');
        
        if (!updatedUser) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        console.log('Updated user:', updatedUser);
        res.json({
            id: updatedUser._id,
            name: updatedUser.name,
            email: updatedUser.email,
            userImage: updatedUser.userImage || null
        });
    } catch (error) {
        console.error('Error updating profile:', error);
        res.status(400).json({ message: error.message });
    }
};

export const getProfile = async (req, res) => {
    try {
        console.log('Getting profile for user ID:', req.user._id);
        const user = await User.findById(req.user._id)
            .select('-password')
            .lean();  // Convert to plain object
            
        if (!user) {
            console.log('User not found');
            return res.status(404).json({ message: 'User not found' });
        }

        console.log('Found user:', user);
        console.log('User image:', user.userImage);

        const response = {
            id: user._id,
            name: user.name,
            email: user.email,
            profileImage: user.userImage || null
        };

        console.log('Sending response:', response);
        res.json(response);
    } catch (error) {
        console.error('Error in getProfile:', error);
        res.status(400).json({ message: error.message });
    }
};

export const uploadImage = async (req, res) => {
    try {
        console.log('Received image upload request');
        if (!req.file) {
            return res.status(400).json({ message: 'No image file provided' });
        }

        // Convert buffer to base64
        const b64 = Buffer.from(req.file.buffer).toString('base64');
        let dataURI = "data:" + req.file.mimetype + ";base64," + b64;
        
        console.log('Uploading to Cloudinary...');
        const result = await cloudinary.uploader.upload(dataURI, {
            resource_type: 'auto',
            folder: 'user_profiles'
        });
        
        console.log('Upload successful:', result.secure_url);
        res.json({ imageUrl: result.secure_url });
    } catch (error) {
        console.error('Image upload error:', error);
        res.status(500).json({ message: 'Error uploading image', error: error.message });
    }
}; 