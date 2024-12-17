import express from 'express';
import { getClients, createClient, updateClient, deleteClient } from '../controllers/clients.js';
import auth from '../middleware/auth.js';

const router = express.Router();

router.use(auth); // Protect all routes

router.route('/')
    .get(getClients)
    .post(createClient);

router.route('/:id')
    .put(updateClient)
    .delete(async (req, res) => {
        console.log('Delete route hit for ID:', req.params.id);
        await deleteClient(req, res);
    });

export default router; 