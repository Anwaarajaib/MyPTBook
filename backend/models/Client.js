import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';

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
    sessions: [{
        type: String,
        ref: 'Session'
    }],
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