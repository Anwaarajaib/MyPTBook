import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

const sessionSchema = new mongoose.Schema({
    _id: {
        type: String,
        required: true
    },
    date: {
        type: Date,
        required: true,
        default: Date.now,
        get: (date) => date.toISOString(),
        set: (date) => new Date(date)
    },
    duration: {
        type: Number,
        required: true,
        default: 0
    },
    exercises: [{
        id: String,
        name: String,
        sets: Number,
        reps: String,
        weight: String,
        isPartOfCircuit: Boolean,
        circuitName: String,
        setPerformances: [String]
    }],
    type: {
        type: String,
        required: false
    },
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
    _id: false,
    toJSON: { getters: true }
});

const clientSchema = new mongoose.Schema({
    _id: {
        type: String,
        default: uuidv4,
        required: true
    },
    name: {
        type: String,
        required: true
    },
    age: {
        type: Number,
        required: true
    },
    height: {
        type: Number,
        required: true
    },
    weight: {
        type: Number,
        required: true
    },
    medicalHistory: {
        type: String,
        default: ''
    },
    goals: {
        type: String,
        default: ''
    },
    nutritionPlan: {
        type: String,
        default: ''
    },
    sessions: [sessionSchema],
    trainer: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    profileImagePath: {
        type: String,
        default: null
    }
}, {
    _id: false,
    timestamps: true
});

clientSchema.pre('save', function(next) {
    if (!this._id) {
        this._id = uuidv4();
    }
    
    this.sessions.forEach(session => {
        if (!session._id) {
            console.warn('Session missing _id:', session);
            session._id = uuidv4();
        }
    });
    
    next();
});

clientSchema.set('toJSON', {
    transform: function(doc, ret) {
        ret._id = ret._id.toString();
        if (!ret.sessions) {
            ret.sessions = [];
        }
        return ret;
    }
});

const Client = mongoose.model('Client', clientSchema);
export default Client; 