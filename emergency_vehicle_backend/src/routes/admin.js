const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/authMiddleware');
const { getPendingUsers, verifyUser, rejectUser } = require('../controllers/adminController');

// Admin Routes
router.get('/pending', protect, authorize('Admin'), getPendingUsers);
router.put('/verify/:id', protect, authorize('Admin'), verifyUser);
router.put('/reject/:id', protect, authorize('Admin'), rejectUser);

module.exports = router;
