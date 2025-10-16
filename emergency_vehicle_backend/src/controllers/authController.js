const User = require('../models/user');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// @desc    Register a new user (Driver)
// @route   POST /api/v1/auth/register
// @access  Private (Requires Admin role)
exports.register = async (req, res) => {
    const { name, email, password, vehicleId, hospitalId } = req.body;

    try {
        const userExists = await User.findOne({ email });

        if (userExists) {
            return res.status(400).json({ success: false, message: 'User already exists' });
        }

        // The user model's 'pre-save' hook will automatically hash the password
        const user = await User.create({
            name,
            email,
            password,
            vehicleId,
            hospitalId,
            role: 'Driver', // New registrations via this route are always Drivers
        });

        if (user) {
            res.status(201).json({
                success: true,
                message: "Driver account created successfully. Verification is pending.",
                data: {
                    _id: user._id,
                    name: user.name,
                    email: user.email,
                    role: user.role,
                    verificationStatus: user.verificationStatus,
                }
            });
        } else {
            res.status(400).json({ success: false, message: 'Invalid user data' });
        }
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};
// @desc    Register a new Admin (TEMPORARY SETUP)
// @route   POST /api/v1/auth/register-admin
// @access  Public (Use once, then disable)
exports.registerAdmin = async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Check if admin already exists
    const existingAdmin = await User.findOne({ email });
    if (existingAdmin) {
      return res.status(400).json({ message: 'Admin already exists' });
    }

    const admin = new User({
  name,
  email,
  password, // plain password — pre-save hook will handle hashing
  role: 'Admin',
  verificationStatus: 'Verified'
});


    await admin.save();
    res.status(201).json({ message: 'Admin registered successfully', admin });
  } catch (error) {
    res.status(500).json({ message: 'Server error', error: error.message });
  }
};

// @desc    Login user & get token
// @route   POST /api/v1/auth/login
// @access  Public
exports.login = async (req, res) => {
  const { email, password } = req.body;

  try {
    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide an email and password' });
    }

    // Find the user and explicitly select the password field
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials - user not found' });
    }

    // Compare entered password with hashed password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Invalid credentials - wrong password' });
    }

    // Only block Rejected users
    if (user.verificationStatus === 'Rejected') {
      return res.status(403).json({
        success: false,
        message: 'Your account has been rejected by admin.',
      });
    }

    // Generate token
    const payload = {
      id: user._id,
      role: user.role,
      verificationStatus: user.verificationStatus,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, {
      expiresIn: process.env.JWT_EXPIRE || '7d',
    });

    res.status(200).json({
      success: true,
      token,
    });

  } catch (error) {
    res.status(500).json({ success: false, message: 'Server Error', error: error.message });
  }
};


// Helper function to create, sign, and send the JWT
const sendTokenResponse = (user, statusCode, res) => {
    // This payload is critical. The frontend will decode it to manage the UI.
    const payload = {
        id: user._id,
        role: user.role,
        verificationStatus: user.verificationStatus,
    };

    const token = jwt.sign(payload, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRE,
    });

    res.status(statusCode).json({
        success: true,
        token: token,
    });
};