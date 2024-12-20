import express from 'express';
import { login, register, updateProfile, getProfile, forgotPassword, resetPassword } from '../controllers/userController.js';
import Protect from '../middleware/auth.js';

const router = express.Router();

router.post('/login', login);
router.post('/register', register);
router.route('/profile').get(Protect, getProfile).put(Protect, updateProfile);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password/:resetToken', resetPassword);

export default router;
