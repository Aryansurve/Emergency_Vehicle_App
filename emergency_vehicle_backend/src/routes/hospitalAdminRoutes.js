// src/routes/hospitalAdminRoutes.js

const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/authMiddleware');
const { 
    getPendingDrivers, 
    approveDriver, 
    rejectDriver 
} = require('../controllers/hospitalAdminController');

// All routes in this file are protected and for HospitalAdmins only
router.use(protect, authorize('HospitalAdmin'));

router.get('/pending-drivers', getPendingDrivers);
router.put('/approve/:driverId', approveDriver);
router.put('/reject/:driverId', rejectDriver);

module.exports = router;