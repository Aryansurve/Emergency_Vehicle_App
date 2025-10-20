// src/routes/publicRoutes.js

const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/authMiddleware');
const { 
    getHospitalList, 
    createEmergencyRequest, // <-- IMPORT NEW FUNCTION
    trackEmergencyStatus 
} = require('../controllers/publicController');

router.use(protect, authorize('PublicUser', 'Admin'));

router.get('/hospitals', getHospitalList);
router.post('/emergency/create', createEmergencyRequest); // <-- ADD THIS NEW ROUTE
router.get('/emergency/:trackingId', trackEmergencyStatus);

module.exports = router;