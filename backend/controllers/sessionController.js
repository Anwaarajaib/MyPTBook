import Session from '../models/Session.js';

export const createSession = async (req, res) => {
    try {
        const { workoutName, client, completedDate, exercises, isCompleted } = req.body;
        const session = new Session({
            workoutName,
            client,
            completedDate,
            exercises,
            isCompleted
        });
        const savedSession = await session.save();
        res.status(201).json(savedSession);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error creating session', error: error.message });
    }
};

export const getSessionsByClient = async (req, res) => {
    try {
        const { clientId } = req.params;
        const sessions = await Session.find({ client: clientId }).populate('exercises');
        if (!sessions) {
            return res.status(404).json({ message: 'No sessions found for this client' });
        }
        res.status(200).json(sessions);
    } catch (error) {
        res.status(500).json({ message: 'Error retrieving sessions', error });
    }
};

export const getSessionById = async (req, res) => {
    try {
        const sessionId = req.params.sessionId;
        const session = await Session.findById(sessionId)
            .populate('exercises')
            .lean();
            
        if (!session) {
            return res.status(404).json({ message: 'Session not found' });
        }
        
        res.status(200).json(session);
    } catch (error) {
        console.error('Error in getSessionById:', error);
        res.status(500).json({ 
            message: 'Error retrieving session', 
            error: error.message 
        });
    }
};

export const updateSession = async (req, res) => {
    try {
        const sessionId = req.params.sessionId;
        const { workoutName, isCompleted, completedDate } = req.body;
        const session = await Session.findByIdAndUpdate(
            sessionId,
            { workoutName, isCompleted, completedDate },
            { new: true }
        ).populate('exercises');
        if (!session) {
            return res.status(404).json({ message: 'Session not found' });
        }
        res.status(200).json(session);
    } catch (error) {
        res.status(500).json({ message: 'Error updating session', error });
    }
};

export const deleteSession = async (req, res) => {
    try {
        const sessionId = req.params.sessionId;
        const session = await Session.findByIdAndDelete(sessionId);
        if (!session) {
            return res.status(404).json({ message: 'Session not found' });
        }
        res.status(200).json({ message: 'Session deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting session', error });
    }
};
