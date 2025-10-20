// src/controllers/hospitalAdminController.js

const User = require('../models/userModel');

// @desc    Get pending drivers for the logged-in hospital admin's hospital
// @route   GET /api/v1/hospital-admin/pending-drivers
// @access  Private (HospitalAdmin)
exports.getPendingDrivers = async (req, res) => {
    try {
        // Find drivers that belong to this admin's hospital and are pending their approval
        const pendingDrivers = await User.find({ 
            hospitalId: req.user.hospitalId, 
            verificationStatus: 'Pending Hospital Approval' 
        }).select('name email vehicleId createdAt');

        res.status(200).json({ success: true, count: pendingDrivers.length, data: pendingDrivers });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Approve a driver (by Hospital Admin)
// @route   PUT /api/v1/hospital-admin/approve/:driverId
// @access  Private (HospitalAdmin)
exports.approveDriver = async (req, res) => {
    try {
        const driver = await User.findById(req.params.driverId);

        if (!driver || driver.hospitalId.toString() !== req.user.hospitalId.toString()) {
            return res.status(404).json({ success: false, message: 'Driver not found in your hospital or does not exist.' });
        }
        
        driver.verificationStatus = 'Pending Platform Approval'; // Move to next stage
        driver.verifiedByHospitalAdmin = req.user.id; // Audit trail
        await driver.save();
        
        res.status(200).json({ success: true, message: 'Driver approved and sent for final platform verification.' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Reject a driver (by Hospital Admin)
// @route   PUT /api/v1/hospital-admin/reject/:driverId
// @access  Private (HospitalAdmin)
exports.rejectDriver = async (req, res) => {
    const { reason } = req.body;
    if (!reason) {
        return res.status(400).json({ success: false, message: 'A reason for rejection is required.' });
    }

    try {
        const driver = await User.findById(req.params.driverId);

        if (!driver || driver.hospitalId.toString() !== req.user.hospitalId.toString()) {
            return res.status(404).json({ success: false, message: 'Driver not found in your hospital or does not exist.' });
        }

        driver.verificationStatus = 'Rejected';
        driver.rejectionReason = reason; // Store the reason
        await driver.save();
        
        res.status(200).json({ success: true, message: 'Driver has been rejected.' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};