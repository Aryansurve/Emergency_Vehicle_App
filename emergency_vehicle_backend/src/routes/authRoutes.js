const express = require('express');
const router = express.Router();
const { registerAdmin } = require('../controllers/authController');

// Admin registration route
router.post('/register-admin', registerAdmin);

module.exports = router;
