import mongoose from 'mongoose';

const exerciseSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true
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
    required: true,
    default: "10"
  },
  notes: String
});

const SessionSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true
  },
  date: {
    type: Date,
    required: true
  },
  exercises: [exerciseSchema],
  isCompleted: {
    type: Boolean,
    default: false
  }
});

const clientSchema = new mongoose.Schema({
  id: {
    type: String,
    required: true
  },
  trainerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  name: {
    type: String,
    required: true
  },
  profileImageData: Buffer,
  age: String,
  height: String,
  weight: String,
  medicalHistory: String,
  goalsNotes: String,
  sessions: [SessionSchema],
  createdAt: {
    type: Date,
    default: Date.now
  }
});

export const Client = mongoose.model('Client', clientSchema); 