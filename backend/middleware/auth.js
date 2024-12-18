import jwt from 'jsonwebtoken';
import User from '../models/User.js';

const auth = async (req, res, next) => {
    try {
        console.log('Auth middleware - Headers:', req.headers);
        
        const token = req.headers.authorization?.replace('Bearer ', '');
        if (!token) {
            console.log('No token provided');
            return res.status(401).json({ message: 'No authentication token provided' });
        }
        
        console.log('Verifying token:', token);
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        console.log('Decoded token:', decoded);
        
        const user = await User.findOne({ _id: decoded.userId });
        if (!user) {
            console.log('User not found:', decoded.userId);
            return res.status(401).json({ message: 'User not found' });
        }
        
        console.log('User authenticated:', user._id);
        req.user = user;
        next();
    } catch (error) {
        console.error('Auth middleware error:', error);
        res.status(401).json({ message: 'Please authenticate' });
    }
};

export default auth; 