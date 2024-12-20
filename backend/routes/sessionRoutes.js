import express from 'express';
import { createSession, getSessionsByClient, getSessionById, updateSession, deleteSession } from '../controllers/sessionController.js';
import Protect from '../middleware/auth.js';
const router = express.Router();


router.post('/', createSession);
router.get('/client/:clientId', getSessionsByClient);
router.get('/:sessionId', getSessionById);
router.put('/:sessionId', updateSession);
router.delete('/:sessionId', deleteSession);


export default router;