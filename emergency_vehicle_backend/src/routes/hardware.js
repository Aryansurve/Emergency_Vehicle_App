const express = require('express');
const router = express.Router();
const Preemption = require('../models/Preemption');

// Use the exact filename from your image: authMiddleware
const { protect } = require('../middleware/authMiddleware'); 

// --- UPDATE STATUS (Called by Flutter) ---
router.put('/hardware-preemption',  async (req, res) => {
    try {
        const { isPreemptionActive, targetLane, emergencyId } = req.body;

        const status = await Preemption.findOneAndUpdate(
            {}, 
            { 
                isPreemptionActive, 
                targetLane, 
                emergencyId,
                updatedAt: Date.now() 
            },
            { upsert: true, new: true }
        );

        res.json({ success: true, data: status });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// --- FETCH STATUS (Polled by Raspberry Pi) ---
router.get('/hardware-status', async (req, res) => {
    try {
        const status = await Preemption.findOne({});
        res.json(status || { isPreemptionActive: false, targetLane: 1 });
    } catch (e) {
        res.status(500).json({ error: "Server Error" });
    }
});

module.exports = router;