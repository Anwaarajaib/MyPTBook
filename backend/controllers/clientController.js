import Client from '../models/Client.js';
import { cloudinary } from '../config/cloudinary.js';
import { Readable } from 'stream';

export const createClient = async (req, res) => {
    const { name, age, height, weight, goals, medicalHistory, userId, clientImage } = req.body;
    try {
        const client = new Client({ name, clientImage, age, height, weight, goals, medicalHistory, user: userId });
        await client.save();
        res.status(201).json(client);
    } catch (error) {
        res.status(404).json({ error: error.message })
    }
};

export const getAllClients = async (req, res) => {
    try {
        console.log(req.user)
        const clients = await Client.find({ user: req.user._id });
        console.log(clients)
        res.json(clients);
    } catch (error) {
        console.error('Error fetching clients:', error);
        res.status(400).json({ message: error.message });
    }
};

export const updateClient = async (req, res) => {
    try {
        const { clientId } = req.params;
        const updates = req.body;
        const client = await Client.findOneAndUpdate({
            _id: clientId, user: req.user._id
        }, updates, { new: true });
        if (!client) {
            return res.status(404).json({ message: "Client not found" });
        }
        res.json(client)
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

export const deleteClient = async (req, res) => {
    try {
        const { clientId } = req.params;
        const client = await Client.findOneAndDelete({
            _id: clientId,
            user: req.user._id
        })
        if (!client) {
            res.status(404).json({ message: "Client not found" })
        }
        res.json({ message: 'Client deleted successfully' })
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
};

export const uploadClientImage = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: "No image file provided" });
        }

        // Convert buffer to base64
        const b64 = Buffer.from(req.file.buffer).toString('base64');
        let dataURI = "data:" + req.file.mimetype + ";base64," + b64;
        
        // Upload to cloudinary
        const uploadResponse = await cloudinary.uploader.upload(dataURI, {
            folder: 'client-images',
            resource_type: 'auto'
        });

        res.json({ 
            imageUrl: uploadResponse.secure_url,
            message: 'Image uploaded successfully'
        });

    } catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({ message: error.message });
    }
};
