import mongoose from 'mongoose';

const SessionSchema = new mongoose.Schema({
    workoutName: { type: String, required: true },
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true },
    completedDate: { type: Date },
    exercises: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Exercise' }],
    isCompleted: { type: Boolean, default: false },
});

const Session = mongoose.model('Session', SessionSchema);

export default Session; 