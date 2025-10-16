// src/controllers/hospitalController.js

// Temporary in-memory storage
let hospitals = [];

// Add multiple hospitals at once
exports.addHospitals = (req, res) => {
    const newHospitals = req.body.hospitals; // Expect an array of hospitals

    if (!newHospitals || !Array.isArray(newHospitals) || newHospitals.length === 0) {
        return res.status(400).json({ message: "Provide an array of hospitals" });
    }

    const addedHospitals = newHospitals.map((hospital, index) => {
        const { name, address, phone } = hospital;

        if (!name || !address || !phone) {
            throw new Error(`Hospital at index ${index} is missing required fields`);
        }

        const newHospital = {
            id: hospitals.length + 1,
            name,
            address,
            phone
        };

        hospitals.push(newHospital);
        return newHospital;
    });

    res.status(201).json({
        message: `${addedHospitals.length} hospitals added successfully`,
        hospitals: addedHospitals
    });
};

// Get all hospitals
exports.getHospitals = (req, res) => {
    res.status(200).json({ hospitals });
};
