import express from 'express';
import multer from 'multer';
import {
    createClient, deleteClient, getAllClients,
    updateClient, uploadClientImage
} from '../controllers/clientController.js';
import Protect from '../middleware/auth.js';

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage() });

router.route("/").get(Protect, getAllClients).post(Protect, createClient);
router.route("/:clientId").put(Protect, updateClient).delete(Protect, deleteClient);
router.post("/upload-image", Protect, upload.single('image'), uploadClientImage);

export default router; 