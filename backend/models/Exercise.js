import mongoose from 'mongoose';

const ExerciseSchema = new mongoose.Schema({
    exerciseName: { type: String, required: true },
    sets: { type: Number },
    reps: { type: Number },
    weight: { type: Number },
    time: { type: Number },
    groupType: { type: String, enum: ['superset', 'circuit'], default: null },
    groupId: { type: String },
    session: { type: mongoose.Schema.Types.ObjectId, ref: 'Session', required: true },
});

const Exercise = mongoose.models.Exercise || mongoose.model('Exercise', ExerciseSchema);

export default Exercise;