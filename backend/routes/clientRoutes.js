import express from 'express';
import {
    createClient, deleteClient, getAllClients,
    updateClient
} from '../controllers/clientController.js';
import Protect from '../middleware/auth.js';

const router = express.Router();

router.route("/").get(Protect, getAllClients).post(Protect, createClient)
router.route("/:clientId").put(Protect, updateClient).delete(Protect, deleteClient)
export default router; 