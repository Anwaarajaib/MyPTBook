import Session from '../models/Sessions.js';
import Client from '../models/Client.js';

// Get all sessions for a client
export const getClientSessions = async (req, res) => {
    try {
        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }

        const sessions = await Session.find({ client: req.params.clientId });
        res.json(sessions);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// Create new sessions for a client
export const createSessions = async (req, res) => {
    try {
        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }

        const sessions = await Session.create(
            req.body.sessions.map(session => ({
                ...session,
                client: req.params.clientId
            }))
        );
        res.status(201).json(sessions);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

// Update a session
export const updateSession = async (req, res) => {
    try {
        const session = await Session.findOneAndUpdate(
            { _id: req.params.sessionId, client: req.params.clientId },
            req.body,
            { new: true }
        );
        if (!session) {
            return res.status(404).json({ message: 'Session not found' });
        }
        res.json(session);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

// Delete a session
export const deleteSession = async (req, res) => {
    try {
        const session = await Session.findOneAndDelete({ 
            _id: req.params.sessionId, 
            client: req.params.clientId 
        });
        if (!session) {
            return res.status(404).json({ message: 'Session not found' });
        }
        res.json({ message: 'Session deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
