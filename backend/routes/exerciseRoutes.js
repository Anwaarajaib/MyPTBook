import express from 'express';
import { createExercise, getExercisesBySession, getExerciseById, updateExercise, deleteExercise } from '../controllers/exerciseController.js';
import Protect from '../middleware/auth.js';
const router = express.Router();

router.post('/', createExercise);
router.get('/session/:sessionId', getExercisesBySession);
router.get('/:exerciseId', getExerciseById);
router.put('/:exerciseId', updateExercise);
router.delete('/:exerciseId', deleteExercise);

export default router;