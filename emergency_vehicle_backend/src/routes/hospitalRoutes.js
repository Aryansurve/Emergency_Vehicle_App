const express = require('express');
const router = express.Router();
const { addHospitals, getHospitals } = require('../controllers/hospitalController');
const { protect } = require('../middleware/authMiddleware');
const User = require('../models/userModel');
const Hospital = require('../models/hospitalModel');
// Add multiple hospitals
router.post('/add-multiple', addHospitals);

router.post('/request', protect, async (req, res) => {
  try {
    const userId = req.user.id; // get from token
    const { hospitalId } = req.body;

    if (!hospitalId) {
      return res.status(400).json({ success: false, message: "Hospital ID is required" });
    }

    const hospital = await Hospital.findById(hospitalId);
    if (!hospital) {
      return res.status(404).json({ success: false, message: "Hospital not found" });
    }

    // Update user with pending request
    const user = await User.findByIdAndUpdate(
      userId,
      { requestedHospital: hospitalId, verificationStatus: "Pending" },
      { new: true }
    );

    res.status(200).json({ success: true, message: "Verification request sent" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: "Server Error" });
  }
});

// Get all hospitals
router.get('/', getHospitals);

module.exports = router;
