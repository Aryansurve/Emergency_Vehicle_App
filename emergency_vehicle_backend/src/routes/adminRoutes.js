// src/routes/adminRoutes.js

const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/authMiddleware');
const { 
    getPendingUsers, 
    verifyUser, 
    rejectUser,
    createHospitalAdmin,
    getUnassignedEmergencies, // <-- Import new
    assignEmergencyToDriver,
    getAvailableDrivers  
} = require('../controllers/adminController');

// All routes in this file are protected and for Admins only
router.use(protect, authorize('Admin'));

// Routes for managing driver verification
router.get('/pending-users', getPendingUsers);
router.put('/verify/:userId', verifyUser);
router.put('/reject/:userId', rejectUser);
router.get('/emergencies/unassigned', getUnassignedEmergencies);
router.put('/emergencies/assign', assignEmergencyToDriver);
router.post('/create-hospital-admin', createHospitalAdmin); // <-- Add new route
router.get('/drivers/available', getAvailableDrivers); // <-- Add new route


module.exports = router;