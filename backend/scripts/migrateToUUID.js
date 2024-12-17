import mongoose from 'mongoose';
import { v4 as uuidv4 } from 'uuid';
import Client from '../models/Client.js';
import Session from '../models/Sessions.js';
import dotenv from 'dotenv';

dotenv.config();

async function migrateToUUID() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // Get all clients
        const clients = await Client.find({});
        console.log(`Found ${clients.length} clients to migrate`);

        for (const client of clients) {
            // Generate new UUID
            const newId = uuidv4();
            
            // Update associated sessions
            await Session.updateMany(
                { client: client._id },
                { client: newId }
            );

            // Create new client with UUID
            const newClient = new Client({
                _id: newId,
                ...client.toObject(),
                sessions: client.sessions
            });

            // Save new client
            await newClient.save();

            // Delete old client
            await Client.findByIdAndDelete(client._id);

            console.log(`Migrated client ${client._id} to ${newId}`);
        }

        console.log('Migration completed successfully');
        process.exit(0);
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
}

migrateToUUID(); 