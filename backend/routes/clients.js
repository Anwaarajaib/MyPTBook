import express from 'express';
import { 
    getClients, 
    createClient, 
    updateClient, 
    deleteClient,
    getClientSessions,
    createSessions,
    updateSession,
    deleteSession 
} from '../controllers/clients.js';
import auth from '../middleware/auth.js';

const router = express.Router();

router.use(auth);

// Client routes
router.route('/')
    .get(getClients)
    .post(createClient);

router.route('/:id')
    .put(updateClient)
    .delete(deleteClient);

// Session routes (nested under clients)
router.route('/:clientId/sessions')
    .get(getClientSessions)
    .post(createSessions);

router.route('/:clientId/sessions/:sessionId')
    .put(updateSession)
    .delete(deleteSession);

export default router; 