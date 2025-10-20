// src/controllers/adminController.js

const User = require('../models/userModel');
const Hospital = require('../models/hospitalModel');
const Emergency = require('../models/emergencyModel'); // <-- Add this import
// @desc    Get users pending FINAL platform approval
// @route   GET /api/v1/admin/pending-users
// @access  Private (Admin)
exports.getPendingUsers = async (req, res) => {
    try {
        // Find users that have been approved by hospitals and are awaiting final review
        const pendingUsers = await User.find({ verificationStatus: 'Pending Platform Approval' })
            .populate('hospitalId', 'name location') // Show which hospital they belong to
            .select('name email vehicleId hospitalId createdAt');

        res.status(200).json({ success: true, count: pendingUsers.length, data: pendingUsers });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// Assumes you have access to the `io` and `onlineDrivers` map from your server.js
// You might set them in server.js like: app.set('socketio', io); app.set('onlineDrivers', onlineDrivers);

exports.assignEmergencyToDriver = async (req, res) => {
    // Get the io instance and online drivers map from the request object
    const io = req.app.get('socketio');
    const onlineDrivers = req.app.get('onlineDrivers');
    
    const { emergencyId, driverId } = req.body;

    if (!emergencyId || !driverId) {
        return res.status(400).json({ success: false, message: 'Emergency ID and Driver ID are required.' });
    }

    try {
        const emergency = await Emergency.findById(emergencyId);
        if (!emergency) {
            return res.status(404).json({ success: false, message: 'Emergency not found.' });
        }
        if (emergency.status !== 'Pending') {
            return res.status(400).json({ success: false, message: 'This emergency has already been assigned.' });
        }

        const driver = await User.findById(driverId);
        if (!driver || driver.role !== 'Driver') {
            return res.status(404).json({ success: false, message: 'Driver not found.' });
        }

        // Update the emergency
        emergency.assignedDriverId = driverId;
        emergency.status = 'Assigned';
        await emergency.save();

        // Update the driver's status
        driver.driverStatus = 'En Route';
        await driver.save();

        // --- NEW: REAL-TIME NOTIFICATION LOGIC ---
        // Find the driver's live socket connection from the map
        const driverSocketId = onlineDrivers.get(driverId.toString());
        
        if (driverSocketId) {
            // Instantly push the new mission data to the specific driver's app
            io.to(driverSocketId).emit('newMission', emergency);
            console.log(`✅ Mission instantly sent to driver ${driverId}`);
        } else {
            console.log(`⚠️ Driver ${driverId} is not currently online. They will see the mission upon next login.`);
        }
        // --- END OF NEW LOGIC ---

        res.status(200).json({ success: true, message: `Emergency assigned to driver ${driver.name}.` });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// @desc    Verify a user (Final approval by Platform Admin)
// @route   PUT /api/v1/admin/verify/:userId
// @access  Private (Admin)
exports.verifyUser = async (req, res) => {
    try {
        const user = await User.findById(req.params.userId);

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        user.verificationStatus = 'Verified';
        user.verifiedByPlatformAdmin = req.user.id; // Audit trail
        user.rejectionReason = null; // Clear any previous rejection reason
        await user.save();

        res.status(200).json({ success: true, message: 'User verified successfully. Account is now active.' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Reject a user (Final rejection by Platform Admin)
// @route   PUT /api/v1/admin/reject/:userId
// @access  Private (Admin)
exports.rejectUser = async (req, res) => {
    const { reason } = req.body;
    if (!reason) {
        return res.status(400).json({ success: false, message: 'A reason for rejection is required.' });
    }

    try {
        const user = await User.findById(req.params.userId);

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        user.verificationStatus = 'Rejected';
        user.rejectionReason = reason; // Store the reason
        await user.save();

        res.status(200).json({ success: true, message: 'User rejected successfully.' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// --- NEW FUNCTIONALITY ---

// @desc    Create a Hospital Admin account
// @route   POST /api/v1/admin/create-hospital-admin
// @access  Private (Admin)
exports.createHospitalAdmin = async (req, res) => {
    const { name, email, password, hospitalId } = req.body;

    try {
        // Basic validation
        if (!name || !email || !password || !hospitalId) {
            return res.status(400).json({ success: false, message: 'Please provide name, email, password, and hospitalId.' });
        }
        
        // Check if user or hospital exists
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ success: false, message: 'An account with this email already exists.' });
        }

        const hospitalExists = await Hospital.findById(hospitalId);
        if (!hospitalExists) {
            return res.status(404).json({ success: false, message: 'Hospital not found.' });
        }

        // Create the new user with the HospitalAdmin role
        const hospitalAdmin = await User.create({
            name,
            email,
            password,
            hospitalId,
            role: 'HospitalAdmin',
            verificationStatus: 'Verified', // Hospital Admins are auto-verified
        });

        res.status(201).json({ success: true, message: 'Hospital Admin account created successfully.', data: hospitalAdmin });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};


// @desc    Get all emergencies that are 'Pending'
// @route   GET /api/v1/admin/emergencies/unassigned
// @access  Private (Admin)
exports.getUnassignedEmergencies = async (req, res) => {
    try {
        const emergencies = await Emergency.find({ status: 'Pending' })
            .populate('publicUserId', 'name email');
        res.status(200).json({ success: true, data: emergencies });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};

// @desc    Assign an emergency to an available driver
// @route   PUT /api/v1/admin/emergencies/assign
// @access  Private (Admin)
exports.assignEmergencyToDriver = async (req, res) => {
    const { emergencyId, driverId } = req.body;

    if (!emergencyId || !driverId) {
        return res.status(400).json({ success: false, message: 'Emergency ID and Driver ID are required.' });
    }

    try {
        const emergency = await Emergency.findById(emergencyId);
        if (!emergency) {
            return res.status(404).json({ success: false, message: 'Emergency not found.' });
        }
        if (emergency.status !== 'Pending') {
            return res.status(400).json({ success: false, message: 'This emergency has already been assigned.' });
        }

        const driver = await User.findById(driverId);
        if (!driver || driver.role !== 'Driver') {
            return res.status(404).json({ success: false, message: 'Driver not found.' });
        }

        // Update the emergency
        emergency.assignedDriverId = driverId;
        emergency.status = 'Assigned'; // Or 'En Route'
        await emergency.save();

        // Update the driver's status
        driver.driverStatus = 'En Route';
        await driver.save();

        res.status(200).json({ success: true, message: `Emergency assigned to driver ${driver.name}.` });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};
// ... existing functions ...

// @desc    Get all drivers with status 'Available'
// @route   GET /api/v1/admin/drivers/available
// @access  Private (Admin)
exports.getAvailableDrivers = async (req, res) => {
    try {
        const drivers = await User.find({ role: 'Driver', driverStatus: 'Available' })
            .select('name vehicleId');
        res.status(200).json({ success: true, data: drivers });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};