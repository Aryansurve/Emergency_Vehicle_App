// src/controllers/authController.js
const jwt = require('jsonwebtoken');
const redisClient = require('../config/redis');
const User = require('../models/userModel');
const Hospital = require('../models/hospitalModel'); // Required for validation
const generateToken = require('../utils/generateToken'); // Assuming you have this helper

// @desc    Register a new Driver
// @route   POST /api/v1/auth/register/driver
// @access  Public
exports.registerDriver = async (req, res) => {
    const { name, email, password, vehicleId, hospitalId } = req.body;

    try {
        if (!name || !email || !password || !vehicleId || !hospitalId) {
            return res.status(400).json({ success: false, message: 'Please provide all required fields for driver registration.' });
        }

        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ success: false, message: 'User already exists with this email' });
        }

        const hospitalExists = await Hospital.findById(hospitalId);
        if (!hospitalExists) {
            return res.status(404).json({ success: false, message: 'Hospital not found' });
        }

        const user = await User.create({
            name,
            email,
            password,
            vehicleId,
            hospitalId,
            role: 'Driver',
            verificationStatus: 'Pending Hospital Approval', // Set initial status
        });

        res.status(201).json({
            success: true,
            message: "Driver registration successful. Your application is pending approval from the hospital.",
        });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};

// @desc    Register a new Public User
// @route   POST /api/v1/auth/register/user
// @access  Public
exports.registerPublicUser = async (req, res) => {
    const { name, email, password } = req.body;
    
    try {
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ success: false, message: 'User already exists' });
        }

        const user = await User.create({
            name,
            email,
            password,
            role: 'PublicUser',
            verificationStatus: 'Not Applicable',
        });

        // Log in the user immediately after registration
        const token = generateToken(user._id, user.role, user.verificationStatus);
        res.status(201).json({ success: true, token });

    } catch (error) {
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};


// @desc    Login user
// @route   POST /api/v1/auth/login
// @access  Public
exports.login = async (req, res) => {
    const { email, password } = req.body;
    console.time('Login Process Total Time'); // Start total timer ⏱️

    try {
        if (!email || !password) {
            return res.status(400).json({ success: false, message: 'Please provide an email and password' });
        }

        console.time('DB Find User'); // Start DB query timer
        const user = await User.findOne({ email }).select('+password');
        console.timeEnd('DB Find User'); // End DB query timer 📊

        // Check if user exists first
        if (!user) {
            console.log("Login failed: User not found.");
            return res.status(401).json({ success: false, message: 'Invalid credentials - user not found' });
        }

        console.time('Bcrypt Compare'); // Start password comparison timer
        const isMatch = await user.matchPassword(password);
        console.timeEnd('Bcrypt Compare'); // End password comparison timer 🔐

        if (!isMatch) {
            console.log("Login failed: Incorrect password.");
            return res.status(401).json({ success: false, message: 'Invalid credentials - wrong password' });
        }

        // --- Verification Status Checks ---
        if (user.role === 'Driver') {
            switch (user.verificationStatus) {
                case 'Pending Hospital Approval':
                    console.log("Login blocked: Pending Hospital Approval.");
                    return res.status(403).json({ success: false, message: 'Your application is still pending approval from your hospital.' });
                case 'Pending Platform Approval':
                    console.log("Login blocked: Pending Platform Approval.");
                    return res.status(403).json({ success: false, message: 'Your application has been approved by your hospital and is now pending final review by the platform admin.' });
                case 'Rejected':
                    console.log("Login blocked: Account Rejected.");
                    return res.status(403).json({
                        success: false,
                        message: 'Your application was rejected.',
                        reason: user.rejectionReason || 'No reason provided.'
                    });
            }
        }
        // --- End Verification Status Checks ---

        console.time('Generate Token'); // Start token generation timer
        const token = generateToken(user._id, user.role, user.verificationStatus);
        console.timeEnd('Generate Token'); // End token generation timer 🔑

        console.log(`Login successful for user: ${user.email}, Role: ${user.role}`);
        res.status(200).json({ success: true, token });

    } catch (error) {
        console.error("!!! Server Error during login: ", error); // Log any unexpected errors
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    } finally {
        console.timeEnd('Login Process Total Time'); // End total timer ⏱️
    }
};


// Note: registerAdmin can remain as is for creating the super admin.
// We will create Hospital Admins from the main Admin controller.
exports.registerAdmin = async (req, res) => {
    try {
        const { name, email, password } = req.body;
        const existingAdmin = await User.findOne({ email });
        if (existingAdmin) {
            return res.status(400).json({ message: 'Admin already exists' });
        }
        const admin = new User({
            name,
            email,
            password,
            role: 'Admin',
            verificationStatus: 'Verified'
        });
        await admin.save();
        res.status(201).json({ message: 'Admin registered successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error', error: error.message });
    }
};

// --- NEW LOGOUT FUNCTION ---
// @desc    Logout user and blacklist token
// @route   POST /api/v1/auth/logout
// @access  Private
exports.logout = async (req, res) => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(400).json({ success: false, message: 'No token provided' });
        }

        const token = authHeader.split(' ')[1];
        
        // Decode the token to get its expiration time
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const expiresAt = decoded.exp; // Expiration time in seconds since epoch
        const now = Math.floor(Date.now() / 1000); // Current time in seconds

        // Add the token to the Redis blacklist with an expiry time
        // This ensures Redis doesn't get filled with expired tokens
        await redisClient.set(token, 'blacklisted', 'EX', expiresAt - now);

        res.status(200).json({ success: true, message: 'Logged out successfully' });
    } catch (error) {
        // Handle cases where the token might be invalid or expired already
        if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
             return res.status(200).json({ success: true, message: 'Logged out successfully (token invalid)' });
        }
        res.status(500).json({ success: false, message: 'Server Error', error: error.message });
    }
};