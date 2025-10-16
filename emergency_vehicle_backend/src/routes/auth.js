const express = require('express');
const router = express.Router();
const { registerAdmin } = require('../controllers/authController');
// Import controller functions
const { register, login } = require('../controllers/authController');

// Import middleware
const { protect, authorize } = require('../middleware/authMiddleware');

// --- Define Auth Routes ---

// @route   POST /api/v1/auth/login
// @desc    Login user
// @access  Public
router.post('/login', login);
// TEMPORARY ROUTE for creating an Admin
router.post('/register-admin', registerAdmin);

// @route   POST /api/v1/auth/register
// @desc    Register a new driver
// @access  Private (Admin only)
// Here, we apply the middleware. 'protect' runs first, then 'authorize'.
// AFTER (Temporarily for testing)
router.post('/register', register);
//router.post('/register', protect, authorize('Admin'), register);


module.exports = router;