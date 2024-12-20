import mongoose from 'mongoose';
import Nutrition from '../models/Nutrition.js';


export const createNutrition = async (req, res) => {
    try {
        const { client, meals } = req.body;

        if (!client || !Array.isArray(meals) || meals.length === 0) {
            return res.status(400).json({ message: 'Client and meals are required' });
        }

        // Ensure meals are valid
        const invalidMeals = meals.filter(
            meal => !meal.mealName || !Array.isArray(meal.items) || meal.items.length === 0
        );
        if (invalidMeals.length > 0) {
            return res.status(400).json({ message: 'Each meal must include mealName and items' });
        }

        // Check if a nutrition plan already exists for this client
        const existingPlan = await Nutrition.findOne({ client });
        if (existingPlan) {
            return res.status(400).json({ message: 'Nutrition plan already exists for this client' });
        }

        const nutritionPlan = new Nutrition({ client, meals });
        const savedPlan = await nutritionPlan.save();

        res.status(201).json(savedPlan);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error creating nutrition plan', error: error.message });
    }
};

export const getNutritionByClient = async (req, res) => {
    try {
        const { clientId } = req.params;

        const nutritionPlan = await Nutrition.findOne({ client: clientId });
        if (!nutritionPlan) {
            return res.status(404).json({ message: 'Nutrition plan not found for this client' });
        }

        res.status(200).json(nutritionPlan);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error retrieving nutrition plan', error });
    }
};

export const getNutritionById = async (req, res) => {
    try {
        const { nutritionId } = req.params;

        const nutritionPlan = await Nutrition.findById(nutritionId);
        if (!nutritionPlan) {
            return res.status(404).json({ message: 'Nutrition plan not found' });
        }
        res.status(200).json(nutritionPlan);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error retrieving nutrition plan', error });
    }
};


export const updateNutrition = async (req, res) => {
    try {
        const { nutritionId } = req.params;
        const { meals } = req.body;

        if (!Array.isArray(meals) || meals.length === 0) {
            return res.status(400).json({ message: 'Meals array is required for updating' });
        }

        const invalidMeals = meals.filter(
            meal => !meal.mealName || !Array.isArray(meal.items) || meal.items.length === 0
        );
        if (invalidMeals.length > 0) {
            return res.status(400).json({ message: 'Each meal must include mealName and items' });
        }

        const updatedNutrition = await Nutrition.findByIdAndUpdate(
            nutritionId,
            { $set: { meals } },
            { new: true }
        );

        if (!updatedNutrition) {
            return res.status(404).json({ message: 'Nutrition plan not found' });
        }

        res.status(200).json(updatedNutrition);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error updating nutrition plan', error });
    }
};

export const deleteNutrition = async (req, res) => {
    try {
        const { nutritionId } = req.params;

        const deletedNutrition = await Nutrition.findByIdAndDelete(nutritionId);
        if (!deletedNutrition) {
            return res.status(404).json({ message: 'Nutrition plan not found' });
        }

        res.status(200).json({ message: 'Nutrition plan deleted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Error deleting nutrition plan', error });
    }
};
