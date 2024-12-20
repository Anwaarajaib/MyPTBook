import mongoose from 'mongoose';

const ClientSchema = new mongoose.Schema({
    name: { type: String, required: true },
    clientImage: { type: String },
    age: { type: Number, required: true },
    height: { type: Number, required: true },
    weight: { type: Number, required: true },
    medicalHistory: { type: String },
    goals: { type: String },
    user: { type: mongoose.Schema.Types.ObjectId, required: true },
});

const Client = mongoose.model('Client', ClientSchema);
export default Client; 