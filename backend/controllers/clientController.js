import Client from '../models/Client.js';

export const createClient = async (req, res) => {
    const { name, age, height, weight, goals, medicalHistory, userId, clientImage } = req.body;
    try {
        const client = new Client({ name, clientImage, age, height, weight, goals, medicalHistory, user: userId });
        await client.save();
        res.status(201).json(client);
    } catch (error) {
        res.status(404).json({ error: error.message })
    }
};

export const getAllClients = async (req, res) => {
    try {
        console.log(req.user)
        const clients = await Client.find({ user: req.user._id });
        console.log(clients)
        res.json(clients);
    } catch (error) {
        console.error('Error fetching clients:', error);
        res.status(400).json({ message: error.message });
    }
};

export const updateClient = async (req, res) => {
    try {
        const { clientId } = req.params;
        const updates = req.body;
        const client = await Client.findOneAndUpdate({
            _id: clientId, user: req.user._id
        }, updates, { new: true });
        if (!client) {
            return res.status(404).json({ message: "Client not found" });
        }
        res.json(client)
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
};

export const deleteClient = async (req, res) => {
    try {
        const { clientId } = req.params;
        const client = await Client.findOneAndDelete({
            _id: clientId,
            user: req.user._id
        })
        if (!client) {
            res.status(404).json({ message: "Client not found" })
        }
        res.json({ message: 'Client deleted successfully' })
    } catch (error) {
        res.status(500).json({ message: error.message })
    }
};
