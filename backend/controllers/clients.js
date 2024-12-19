import Client from '../models/Client.js';
import { v4 as uuidv4 } from 'uuid';

// Get all clients for a trainer
export const getClients = async (req, res) => {
    try {
        console.log('Getting clients for trainer:', req.user._id);
        
        const clients = await Client.find({ trainer: req.user._id });
        console.log(`Found ${clients.length} clients for trainer ${req.user._id}`);
        
        res.json(clients);
    } catch (error) {
        console.error('Error fetching clients:', error);
        res.status(400).json({ message: error.message });
    }
};

// Create a new client
export const createClient = async (req, res) => {
    try {
        console.log('Creating client for trainer:', req.user._id);
        
        const client = new Client({
            _id: uuidv4(),
            ...req.body,
            trainer: req.user._id
        });
        
        const savedClient = await client.save();
        console.log('Client created:', savedClient._id, 'for trainer:', req.user._id);
        
        res.status(201).json(savedClient);
    } catch (error) {
        console.error('Error creating client:', error);
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
        
        // Delete the client (sessions will be deleted automatically since they're embedded)
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

// Get client sessions
export const getClientSessions = async (req, res) => {
    try {
        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }
        
        res.json(client.sessions);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};

// Create sessions for client
export const createSessions = async (req, res) => {
    try {
        console.log('=== Creating Sessions ===');
        console.log('Client ID:', req.params.clientId);
        console.log('Request body:', JSON.stringify(req.body, null, 2));

        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        
        if (!client) {
            console.log('❌ Client not found');
            return res.status(404).json({ message: 'Client not found' });
        }

        if (!req.body.sessions || !Array.isArray(req.body.sessions)) {
            console.log('❌ Invalid sessions data');
            return res.status(400).json({ message: 'Invalid sessions data' });
        }

        // Map the sessions with proper structure
        const sessionsToAdd = req.body.sessions.map(session => ({
            _id: session._id,
            date: new Date(session.date),
            duration: session.duration || 0,
            exercises: session.exercises.map(exercise => ({
                id: exercise.id,
                name: exercise.name || '',
                sets: exercise.sets || 0,
                reps: exercise.reps || '',
                weight: exercise.weight || '',
                isPartOfCircuit: exercise.isPartOfCircuit || false,
                circuitName: exercise.circuitName || '',
                setPerformances: exercise.setPerformances || []
            })),
            type: session.type || '',
            isCompleted: session.isCompleted || false,
            sessionNumber: session.sessionNumber || 1
        }));

        // Replace existing sessions with new ones
        client.sessions = sessionsToAdd;
        
        const savedClient = await client.save();
        console.log('✅ Client saved successfully');

        // Transform sessions for response
        const responseData = savedClient.sessions.map(session => ({
            id: session._id,
            date: session.date,
            duration: session.duration,
            exercises: session.exercises,
            type: session.type,
            isCompleted: session.isCompleted,
            sessionNumber: session.sessionNumber
        }));
        
        res.status(201).json(responseData);
    } catch (error) {
        console.log('❌ Error creating sessions:', error);
        console.log('Stack trace:', error.stack);
        res.status(400).json({ message: error.message });
    }
};

// Update session
export const updateSession = async (req, res) => {
    try {
        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }

        const sessionIndex = client.sessions.findIndex(
            session => session._id.toString() === req.params.sessionId
        );

        if (sessionIndex === -1) {
            return res.status(404).json({ message: 'Session not found' });
        }

        client.sessions[sessionIndex] = {
            ...client.sessions[sessionIndex],
            ...req.body
        };

        await client.save();
        res.json(client.sessions[sessionIndex]);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

// Delete session
export const deleteSession = async (req, res) => {
    try {
        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        
        if (!client) {
            return res.status(404).json({ message: 'Client not found' });
        }

        client.sessions = client.sessions.filter(
            session => session._id.toString() !== req.params.sessionId
        );

        await client.save();
        res.json({ message: 'Session deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
}; 