// src/routes/driverRoutes.js

const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/authMiddleware');
const {
    getDriverProfile,
    updateDriverStatus,
    updateLocation,
    getActiveEmergency,
    getDriverStatus,
    updateEmergencyStatus,
    getDrivers
} = require('../controllers/driverController'); // single import

// Middleware to protect all driver routes
router.use(protect, authorize('Driver'));

// A custom middleware to check if the driver is verified before proceeding
const isVerifiedDriver = (req, res, next) => {
    if (req.user.verificationStatus !== 'Verified') {
        return res.status(403).json({ success: false, message: 'Access denied. Your account is not verified.' });
    }
    next();
};

// Apply the verification check to all subsequent routes
router.use(isVerifiedDriver);

router.get('/drivers', getDrivers); // use the function you imported
router.get('/status', getDriverStatus);
router.get('/profile', getDriverProfile);
router.put('/status', updateDriverStatus);
router.post('/location', updateLocation);
router.put('/status/update', updateDriverStatus);
router.get('/active-emergency', getActiveEmergency);
router.put('/emergency/update-status', updateEmergencyStatus);

module.exports = router;
