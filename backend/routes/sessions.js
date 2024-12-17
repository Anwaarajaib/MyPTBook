import express from 'express';
import { getClientSessions, createSessions, updateSession, deleteSession } from '../controllers/sessions.js';
import auth from '../middleware/auth.js';

const router = express.Router();

router.use(auth); // Protect all routes

router.route('/:clientId/sessions')
    .get(getClientSessions)
    .post(createSessions);

router.route('/:clientId/sessions/:sessionId')
    .put(updateSession)
    .delete(deleteSession);

export default router; 