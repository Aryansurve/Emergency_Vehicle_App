// src/controllers/driverController.js

const User = require('../models/userModel');
const Emergency = require('../models/emergencyModel');

// @desc    Get the profile of the currently logged-in driver
// @route   GET /api/v1/driver/profile
// @access  Private (Driver)
const getDriverProfile = async (req, res) => {
    try {
        const driver = await User.findById(req.user.id).populate('hospitalId', 'name location');
        if (!driver) {
            return res.status(404).json({ success: false, message: 'Driver not found.' });
        }
        res.status(200).json({ success: true, data: driver });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Update the status of an active emergency
// @route   PUT /api/v1/driver/emergency/update-status
// @access  Private (Driver)
const updateEmergencyStatus = async (req, res) => {
    const { emergencyId, status } = req.body;
    const validStatuses = ['On Scene', 'Resolved', 'Cancelled'];

    if (!emergencyId || !status) {
        return res.status(400).json({ success: false, message: 'Emergency ID and status are required.' });
    }

    if (!validStatuses.includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status provided.' });
    }

    try {
        const emergency = await Emergency.findById(emergencyId);

        if (!emergency || emergency.assignedDriverId.toString() !== req.user.id) {
            return res.status(404).json({ success: false, message: 'Emergency not found or you are not authorized to update it.' });
        }

        emergency.status = status;
        await emergency.save();

        if (status === 'Resolved' || status === 'Cancelled') {
            await User.findByIdAndUpdate(req.user.id, { driverStatus: 'Available' });
        } else {
            await User.findByIdAndUpdate(req.user.id, { driverStatus: status });
        }

        res.status(200).json({ success: true, message: `Emergency status updated to ${status}.`, data: emergency });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// @desc    Update the driver's current status
// @route   PUT /api/v1/driver/status
// @access  Private (Driver)
const updateDriverStatus = async (req, res) => {
    const { status } = req.body;
    if (!status) {
        return res.status(400).json({ success: false, message: 'Status is required.' });
    }

    try {
        console.log(`Driver ${req.user.id} updated status to: ${status}`);
        res.status(200).json({ success: true, message: `Status updated to ${status}` });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Get all drivers
// @route   GET /api/v1/driver/drivers
// @access  Private (Driver)
const getDrivers = async (req, res) => {
    try {
        const drivers = await User.find({ role: 'Driver' });
        res.status(200).json({ success: true, data: drivers });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Update the driver's real-time GPS location
// @route   POST /api/v1/driver/location
// @access  Private (Driver)
const updateLocation = async (req, res) => {
    const { latitude, longitude } = req.body;

    if (latitude === undefined || longitude === undefined) {
        return res.status(400).json({ success: false, message: 'Latitude and longitude are required.' });
    }

    try {
        console.log(`Driver ${req.user.id} location updated to: Lat ${latitude}, Lon ${longitude}`);
        res.status(200).json({ success: true, message: 'Location updated successfully.' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Get the driver's current status
// @route   GET /api/v1/driver/status
// @access  Private (Driver)
const getDriverStatus = async (req, res) => {
    try {
        const driver = await User.findById(req.user.id);
        if (!driver) {
            return res.status(404).json({ success: false, message: 'Driver not found.' });
        }
        res.status(200).json({ success: true, status: driver.driverStatus });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Get active emergencies assigned to the driver
// @route   GET /api/v1/driver/active-emergency
// @access  Private (Driver)
const getActiveEmergency = async (req, res) => {
    try {
        const emergencies = await Emergency.find({ assignedDriverId: req.user.id, status: { $ne: 'Resolved' } });
        res.status(200).json({ success: true, data: emergencies });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// Export all functions
module.exports = {
    getDriverProfile,
    updateDriverStatus,
    updateLocation,
    getActiveEmergency,
    getDriverStatus,
    updateEmergencyStatus,
    getDrivers
};
