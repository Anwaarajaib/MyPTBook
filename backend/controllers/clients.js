import Client from '../models/Client.js';
import Session from '../models/Sessions.js';
import { v4 as uuidv4 } from 'uuid';

// Get all clients for a trainer
export const getClients = async (req, res) => {
    try {
        const clients = await Client.find({ trainer: req.user._id });
        res.json(clients);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// Create a new client
export const createClient = async (req, res) => {
    try {
        console.log('Create client request received');
        console.log('Auth header:', req.headers.authorization);
        console.log('User from token:', req.user);
        
        const client = new Client({
            _id: uuidv4(),
            ...req.body,
            trainer: req.user._id
        });
        
        const savedClient = await client.save();
        console.log('Client created:', savedClient);
        
        res.status(201).json(savedClient);
    } catch (error) {
        console.error('Error creating client:', error);
        if (error.name === 'UnauthorizedError') {
            return res.status(401).json({ message: 'Invalid token' });
        }
        res.status(400).json({ message: error.message });
    }
};

// Update a client
export const updateClient = async (req, res) => {
    try {
        const client = await Client.findOneAndUpdate(
            { _id: req.params.id, trainer: req.user._id },
            req.body,
            { new: true }
        );
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }
        res.json(client);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

// Delete a client
export const deleteClient = async (req, res) => {
    try {
        console.log('Delete request for client ID:', req.params.id);
        
        // First find all sessions for this client
        const sessions = await Session.find({ client: req.params.id });
        console.log('Found sessions:', sessions.length);
        
        // Delete all sessions
        if (sessions.length > 0) {
            await Session.deleteMany({ client: req.params.id });
            console.log('Deleted associated sessions');
        }
        
        // Delete the client
        const client = await Client.findOneAndDelete({ 
            _id: req.params.id,
            trainer: req.user._id 
        });
        
        console.log('Found client:', client);
        
        if (!client) {
            console.log('Client not found');
            return res.status(404).json({ message: 'Client not found' });
        }
        
        res.json({ message: 'Client deleted successfully' });
    } catch (error) {
        console.error('Error deleting client:', error);
        res.status(500).json({ message: error.message });
    }
}; 