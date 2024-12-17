import express from 'express';
import { login, register, updateProfile, getProfile } from '../controllers/auth.js';
import auth from '../middleware/auth.js';

const router = express.Router();

router.post('/login', login);
router.post('/register', register);
router.get('/profile', auth, getProfile);
router.put('/profile', auth, updateProfile);

export default router;
