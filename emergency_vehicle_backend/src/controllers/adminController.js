const User = require('../models/user');

// @desc    Get all pending users for verification
// @route   GET /api/v1/admin/pending
// @access  Private (Admin)
exports.getPendingUsers = async (req, res) => {
    try {
        const pendingUsers = await User.find({ verificationStatus: 'Pending' }).populate('hospitalId', 'name location');
        res.status(200).json({ success: true, count: pendingUsers.length, data: pendingUsers });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Verify a driver
// @route   PUT /api/v1/admin/verify/:id
// @access  Private (Admin)
exports.verifyUser = async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        user.verificationStatus = 'Verified';
        await user.save();
        res.status(200).json({ success: true, message: 'User verified successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Reject a driver
// @route   PUT /api/v1/admin/reject/:id
// @access  Private (Admin)
exports.rejectUser = async (req, res) => {
    try {
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        user.verificationStatus = 'Rejected';
        await user.save();
        res.status(200).json({ success: true, message: 'User rejected successfully' });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};
