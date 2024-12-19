import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

const sessionSchema = new mongoose.Schema({
    _id: {
        type: String,
        required: true,
        default: uuidv4
    },
    date: {
        type: Date,
        required: true,
        default: Date.now
    },
    duration: {
        type: Number,
        required: true,
        default: 0
    },
    exercises: [{
        id: {
            type: String,
            required: true
        },
        name: String,
        sets: Number,
        reps: String,
        weight: String,
        isPartOfCircuit: Boolean,
        circuitName: String,
        setPerformances: [String]
    }],
    type: String,
    isCompleted: {
        type: Boolean,
        default: false
    },
    sessionNumber: {
        type: Number,
        required: true
    }
}, {
    timestamps: true,
    _id: false
});

export default sessionSchema; 