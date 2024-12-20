import express from 'express';
import {
    createNutrition,
    getNutritionByClient,
    getNutritionById,
    updateNutrition,
    deleteNutrition
} from '../controllers/nutritionController.js';
import Protect from '../middleware/auth.js';

const router = express.Router();

router.post('/', Protect, createNutrition); // Create Nutrition Plan
router.get('/client/:clientId', Protect, getNutritionByClient); // Get Nutrition Plan by Client ID
router.get('/:nutritionId', Protect, getNutritionById); // Get Nutrition Plan by ID
router.put('/:nutritionId', Protect, updateNutrition); // Update Nutrition Plan
router.delete('/:nutritionId', Protect, deleteNutrition); // Delete Nutrition Plan

export default router;
