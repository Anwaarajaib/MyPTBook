import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

// Define the exercise schema
const exerciseSchema = new mongoose.Schema({
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
}, { _id: false });

// Define the session schema
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
        default: 0
    },
    exercises: [exerciseSchema],
    type: String,
    isCompleted: {
        type: Boolean,
        default: false
    },
    sessionNumber: {
        type: Number,
        required: true
    }
}, { _id: false });

// Define the client schema
const clientSchema = new mongoose.Schema({
    _id: {
        type: String,
        required: true,
        default: uuidv4
    },
    name: {
        type: String,
        required: true
    },
    age: Number,
    height: Number,
    weight: Number,
    medicalHistory: String,
    goals: String,
    goalsNotes: String,
    nutritionPlan: String,
    notes: String,
    sessions: [sessionSchema],
    trainer: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    profileImagePath: String
}, {
    timestamps: true
});

// Pre-save middleware to ensure IDs
clientSchema.pre('save', function(next) {
    // Ensure client has an ID
    if (!this._id) {
        this._id = uuidv4();
    }
    
    // Ensure each session has an ID
    if (this.sessions) {
        this.sessions.forEach(session => {
            if (!session._id) {
                session._id = uuidv4();
            }
            
            // Ensure each exercise has an ID
            if (session.exercises) {
                session.exercises.forEach(exercise => {
                    if (!exercise.id) {
                        exercise.id = uuidv4();
                    }
                });
            }
        });
    }
    
    next();
});

const Client = mongoose.model('Client', clientSchema);
export default Client; 