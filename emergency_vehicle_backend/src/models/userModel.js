const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
    name: {
        type: String,
        required: [true, 'Please provide a name'],
    },
    email: {
        type: String,
        required: [true, 'Please provide an email'],
        unique: true,
        match: [
            /^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/,
            'Please provide a valid email address',
        ],
    },
    password: {
        type: String,
        required: [true, 'Please provide a password'],
        minlength: 6,
        select: false,
    },
    role: {
        type: String,
        // UPDATED: Added HospitalAdmin and PublicUser roles
        enum: ['Driver', 'Admin', 'HospitalAdmin', 'PublicUser'],
        default: 'PublicUser', // Default new signups to PublicUser
    },
    vehicleId: {
        type: String,
        // Only required for users with the 'Driver' role
        required: function() { return this.role === 'Driver'; }
    },
    hospitalId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Hospital',
        // Required for Drivers and HospitalAdmins to link them to their organization
        required: function() { return this.role === 'Driver' || this.role === 'HospitalAdmin'; }
    },
    verificationStatus: {
        type: String,
        // UPDATED: More specific statuses for the multi-step verification process
        enum: ['Not Applicable', 'Pending Hospital Approval', 'Pending Platform Approval', 'Verified', 'Rejected'],
        default: 'Not Applicable', // Default for PublicUsers or Admins
    },
    driverStatus: {
    type: String,
    enum: ['Available', 'En Route', 'Busy', 'Offline'],
    default: 'Offline',
    // Only relevant for users with the 'Driver' role
    required: function() { return this.role === 'Driver'; }
    },
    // NEW: Field to store the reason for rejection
    rejectionReason: {
        type: String,
        default: null
    },
    // NEW: Fields for auditing who verified the user
    verifiedByHospitalAdmin: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    verifiedByPlatformAdmin: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }
}, {
    timestamps: true
});

// Middleware (Hook): Hash password before saving the user document
userSchema.pre('save', async function (next) {
    if (!this.isModified('password')) {
        return next();
    }
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
});

// Method: Compare entered password with the hashed password in the database
userSchema.methods.matchPassword = async function (enteredPassword) {
    return await bcrypt.compare(enteredPassword, this.password);
};

const User = mongoose.model('User', userSchema);
module.exports = User;