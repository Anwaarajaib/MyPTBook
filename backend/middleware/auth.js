import jwt from 'jsonwebtoken';
import User from '../models/User.js';

const Protect = async (req, res, next) => {
    try {
        const token = req.headers.authorization?.split(' ')[1]; // Extract token
        if (!token) {
            return res.status(401).json({ message: 'Authentication token is missing' });
        }

        // Verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.userId);
        if (!user) {
            return res.status(401).json({ message: 'User not found' });
        }

        req.user = user; // Attach user to the request
        next(); // Proceed to the next middleware or route
    } catch (error) {
        console.error('Auth middleware error:', error.message);

        // Handle specific JWT errors for better debugging
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ message: 'Authentication token has expired' });
        } else if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({ message: 'Invalid authentication token' });
        }

        res.status(401).json({ message: 'Authentication failed' });
    }
};

export default Protect;
