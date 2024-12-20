import mongoose from 'mongoose';

const NutritionSchema = new mongoose.Schema({
    client: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: true, unique: true },
    meals: [
        {
            mealName: { type: String, required: true },
            items: [
                {
                    name: { type: String, required: true },
                    quantity: { type: String, required: true }
                }
            ]
        }
    ]
});

export default mongoose.model('Nutrition', NutritionSchema);
