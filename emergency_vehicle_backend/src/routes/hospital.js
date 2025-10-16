const express = require('express');
const router = express.Router();
const Hospital = require('../models/hospital');
const { protect, authorize } = require('../middleware/authMiddleware');

// @route   POST /api/v1/hospitals
// @desc    Add new hospital
// @access  Private (Admin only)
router.post('/', protect, authorize('Admin'), async (req, res) => {
    try {
        const { name, location } = req.body;
        if (!name || !location) {
            return res.status(400).json({ success: false, message: 'Please provide name and location' });
        }
        const hospital = await Hospital.create({ name, location });
        res.status(201).json({ success: true, data: hospital });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
});

// (Optional) GET all hospitals
router.get('/', async (req, res) => {
    try {
        const hospitals = await Hospital.find();
        res.status(200).json({ success: true, count: hospitals.length, data: hospitals });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
});

module.exports = router;
