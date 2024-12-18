import Client from '../models/Client.js';
import { v4 as uuidv4 } from 'uuid';

// Get all clients for a trainer
export const getClients = async (req, res) => {
    try {
        console.log('Getting clients for trainer:', req.user._id);
        
        const clients = await Client.find({ trainer: req.user._id });
        console.log('Raw clients from DB:', JSON.stringify(clients, null, 2));
        
        if (!clients || clients.length === 0) {
            console.log('No clients found for trainer');
            return res.json([]); // Return empty array instead of error
        }
        
        // Transform the data to match frontend expectations
        const transformedClients = clients.map(client => {
            console.log('Transforming client:', client._id);
            const clientObj = client.toObject();
            
            // Transform sessions
            if (clientObj.sessions) {
                clientObj.sessions = clientObj.sessions.map(session => ({
                    id: session._id,
                    date: session.date,
                    duration: session.duration,
                    exercises: session.exercises,
                    type: session.type,
                    isCompleted: session.isCompleted,
                    sessionNumber: session.sessionNumber
                }));
            }
            
            // Transform client
            return {
                id: clientObj._id,
                name: clientObj.name,
                age: clientObj.age,
                height: clientObj.height,
                weight: clientObj.weight,
                medicalHistory: clientObj.medicalHistory,
                goals: clientObj.goals,
                sessions: clientObj.sessions || [],
                nutritionPlan: clientObj.nutritionPlan,
                profileImagePath: clientObj.profileImagePath
            };
        });
        
        console.log('Sending transformed clients:', JSON.stringify(transformedClients, null, 2));
        res.json(transformedClients);
    } catch (error) {
        console.error('Error getting clients:', error);
        console.error('Error stack:', error.stack);
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
        console.log('User ID:', req.user._id);
        console.log('Auth Token:', req.headers.authorization);

        const client = await Client.findOne({ 
            _id: req.params.clientId, 
            trainer: req.user._id 
        });
        
        if (!client) {
            console.log('❌ Client not found');
            return res.status(404).json({ message: 'Client not found' });
        }

        console.log('✅ Found client:', client._id);

        if (!req.body.sessions || !Array.isArray(req.body.sessions)) {
            console.log('❌ Invalid sessions data');
            return res.status(400).json({ message: 'Invalid sessions data' });
        }

        // Map the sessions to include _id instead of id
        const sessionsToAdd = req.body.sessions.map(session => {
            console.log('Processing session:', session.id);
            return {
                _id: session.id || uuidv4(), // Use existing id or generate new one
                date: new Date(session.date),
                duration: session.duration,
                exercises: session.exercises.map(exercise => ({
                    ...exercise,
                    id: exercise.id || uuidv4() // Ensure exercise has an id
                })),
                type: session.type,
                isCompleted: session.isCompleted,
                sessionNumber: session.sessionNumber
            };
        });

        console.log('Adding sessions to client...');
        client.sessions.push(...sessionsToAdd);
        
        console.log('Saving client...');
        const savedClient = await client.save();
        console.log('✅ Client saved successfully');

        // Transform the sessions back to frontend format
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