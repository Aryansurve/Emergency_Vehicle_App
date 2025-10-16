const User = require('../models/user');
const bcrypt = require('bcryptjs');

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

    const hashedPassword = await bcrypt.hash(password, 10);

    const admin = new User({
      name,
      email,
      password: hashedPassword,
      role: 'Admin',
      verificationStatus: 'Verified' // Admins are verified by default
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

        const user = await User.findOne({ email }).select('+password');

        if (!user || !(await user.matchPassword(password))) {
            return res.status(401).json({ success: false, message: 'Invalid credentials' });
        }

        if (user.verificationStatus !== 'Verified') {
            return res.status(403).json({
                success: false,
                message: `Your account is ${user.verificationStatus}. Please wait for admin approval.`,
            });
        }

        sendTokenResponse(user, 200, res);
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