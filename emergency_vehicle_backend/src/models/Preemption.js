const mongoose = require('mongoose');

const PreemptionSchema = new mongoose.Schema({
    // Which lane should be green (1-4)
    targetLane: { 
        type: Number, 
        default: 1 
    },
    // The master switch for the hardware logic
    isPreemptionActive: { 
        type: Boolean, 
        default: false 
    },
    // Link it to the active mission for tracking
    emergencyId: {
        type: String, // String or ObjectId depending on your setup
        default: "simulated_id"
    },
    updatedAt: { 
        type: Date, 
        default: Date.now 
    }
});

module.exports = mongoose.model('Preemption', PreemptionSchema);