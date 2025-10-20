// src/controllers/publicController.js
const Emergency = require('../models/emergencyModel'); // <-- IMPORT THE NEW MODEL
const Hospital = require('../models/hospitalModel');
// In the future, you might have an Emergency model
// const Emergency = require('../models/emergencyModel');

// @desc    Get a list of all hospitals
// @route   GET /api/v1/public/hospitals
// @access  Private (PublicUser)
exports.getHospitalList = async (req, res) => {
    try {
        // This functionality is simple: fetch all hospitals from the database.
        const hospitals = await Hospital.find().select('name location contactNumber');
        res.status(200).json({ success: true, count: hospitals.length, data: hospitals });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// --- NEW FUNCTION ---
// @desc    Create a new emergency request
// @route   POST /api/v1/public/emergency/create
// @access  Private (PublicUser)
exports.createEmergencyRequest = async (req, res) => {
    const { location, details } = req.body;

    if (!location || !details) {
        return res.status(400).json({ success: false, message: 'Location and details are required.' });
    }

    try {
        const emergency = await Emergency.create({
            publicUserId: req.user.id,
            location,
            details,
        });

        // In a real system, this would also trigger a notification to a dispatch center.
        res.status(201).json({ 
            success: true, 
            message: 'Emergency request submitted. Help is on the way.',
            trackingId: emergency.trackingId // Return the ID so the user can track it
        });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};


// --- UPDATED FUNCTION (NO MORE SIMULATION) ---
// @desc    Track a specific emergency by its tracking ID
// @route   GET /api/v1/public/emergency/:trackingId
// @access  Private (PublicUser)
exports.trackEmergencyStatus = async (req, res) => {
    try {
        const { trackingId } = req.params;

        // Find the emergency and ensure it belongs to the user requesting it for privacy
        const emergency = await Emergency.findOne({ 
            trackingId: trackingId, 
            publicUserId: req.user.id 
        }).populate('assignedDriverId', 'name vehicleId'); // Get driver's name and vehicle ID

        if (!emergency) {
            return res.status(404).json({ success: false, message: 'Emergency not found or you are not authorized to view it.' });
        }

        res.status(200).json({ success: true, data: emergency });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};