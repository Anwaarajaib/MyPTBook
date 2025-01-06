import Exercise from '../models/Exercise.js';
import Session from '../models/Session.js';

export const createExercise = async (req, res) => {
    try {
        const { exerciseName, sets, reps, weight, time, groupType, session } = req.body;
        const foundSession = await Session.findById(session);
        if (!foundSession) {
            return res.status(404).json({ message: 'Session not found' });
        }
        const exercise = new Exercise({
            exerciseName,
            sets,
            reps,
            weight,
            time,
            groupType,
            session
        });
        const savedExercise = await exercise.save();
        foundSession.exercises.push(savedExercise._id);
        await foundSession.save();
        res.status(201).json(savedExercise);
    } catch (error) {
        console.error('Error creating exercise:', error);  // Log the error to the server console for debugging
        res.status(500).json({ message: 'Error creating exercise', error: error.message });
    }
};

export const getExercisesBySession = async (req, res) => {
    try {
        const sessionId = req.params.sessionId;
        const exercises = await Exercise.find({ session: sessionId });
        if (!exercises) {
            return res.status(404).json({ message: 'No exercises found for this session' });
        }
        res.status(200).json(exercises);
    } catch (error) {
        res.status(500).json({ message: 'Error retrieving exercises', error });
    }
};

export const getExerciseById = async (req, res) => {
    try {
        const exerciseId = req.params.exerciseId;
        const exercise = await Exercise.findById(exerciseId);
        if (!exercise) {
            return res.status(404).json({ message: 'Exercise not found' });
        }
        res.status(200).json(exercise);
    } catch (error) {
        res.status(500).json({ message: 'Error retrieving exercise', error });
    }
};

export const updateExercise = async (req, res) => {
    try {
        const exerciseId = req.params.exerciseId;
        const { exerciseName, sets, reps, weight, time, groupType } = req.body;
        const exercise = await Exercise.findByIdAndUpdate(
            exerciseId,
            { exerciseName, sets, reps, weight, time, groupType },
            { new: true }
        );
        if (!exercise) {
            return res.status(404).json({ message: 'Exercise not found' });
        }
        res.status(200).json(exercise);
    } catch (error) {
        res.status(500).json({ message: 'Error updating exercise', error });
    }
};

export const deleteExercise = async (req, res) => {
    try {
        const exerciseId = req.params.exerciseId;
        const exercise = await Exercise.findByIdAndDelete(exerciseId);
        if (!exercise) {
            return res.status(404).json({ message: 'Exercise not found' });
        }
        const session = await Session.findById(exercise.session);
        if (session) {
            session.exercises.pull(exerciseId);
            await session.save();
        }
        res.status(200).json({ message: 'Exercise deleted successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Error deleting exercise', error });
    }
};
