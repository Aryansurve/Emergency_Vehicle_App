// src/routes/authRoutes.js

const express = require('express');
const router = express.Router();
const { 
    registerDriver, 
    registerPublicUser, 
    login,
    registerAdmin,
    logout // <-- IMPORT NEW FUNCTION
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');

// Define specific registration routes
router.post('/register/driver', registerDriver);
router.post('/register/user', registerPublicUser);
router.post('/logout', protect, logout); // <-- ADD THIS NEW ROUTE
// Login route
router.post('/login', login);

// Admin registration route (for initial setup)
router.post('/register-admin', registerAdmin);

module.exports = router;