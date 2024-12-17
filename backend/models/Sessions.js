import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

const exerciseSchema = new mongoose.Schema({
    _id: {
        type: String,
        default: () => uuidv4()
    },
    name: {
        type: String,
        required: true
    },
    sets: {
        type: Number,
        required: true,
        default: 3
    },
    reps: {
        type: String,
        required: true
    },
    isPartOfCircuit: {
        type: Boolean,
        default: false
    },
    circuitRounds: {
        type: Number
    },
    circuitName: {
        type: String
    }
});

const sessionSchema = new mongoose.Schema({
    _id: {
        type: String,
        default: () => uuidv4()
    },
    date: {
        type: Date,
        required: true,
        default: Date.now
    },
    exercises: [exerciseSchema],
    type: {
        type: String
    },
    isCompleted: {
        type: Boolean,
        default: false
    },
    sessionNumber: {
        type: Number,
        required: true
    },
    client: {
        type: String,
        ref: 'Client',
        required: true
    }
}, { timestamps: true });

sessionSchema.set('toJSON', {
    transform: function(doc, ret) {
        ret._id = ret._id.toString();
        return ret;
    }
});

const Session = mongoose.model('Session', sessionSchema);
export default Session;
