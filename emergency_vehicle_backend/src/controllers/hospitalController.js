// src/controllers/hospitalController.js
const Hospital = require('../models/hospitalModel');

// Add multiple hospitals at once
exports.addHospitals = async (req, res) => {
    try {
        const newHospitals = req.body.hospitals; // Expect an array of hospitals

        if (!newHospitals || !Array.isArray(newHospitals) || newHospitals.length === 0) {
            return res.status(400).json({ message: "Provide an array of hospitals" });
        }

        // Validate and insert hospitals into MongoDB
        const addedHospitals = await Hospital.insertMany(
            newHospitals.map(h => ({
                name: h.name,
                location: h.location || h.address, // adjust if frontend sends 'address'
                contactNumber: h.phone || h.contactNumber
            }))
        );

        res.status(201).json({
            message: `${addedHospitals.length} hospitals added successfully`,
            hospitals: addedHospitals
        });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: "Server error", error: error.message });
    }
};

// Get all hospitals
exports.getHospitals = async (req, res) => {
    try {
        const hospitals = await Hospital.find(); // Fetch from MongoDB
        res.status(200).json({ success: true, hospitals });
    } catch (error) {
        console.error(error);
        res.status(500).json({ success: false, message: "Server error", error: error.message });
    }
};
