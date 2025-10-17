const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

// This schema defines the structure for all users in the application.
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
        select: false, // Prevents password from being returned in queries by default
    },
    role: {
        type: String,
        enum: ['Driver', 'Admin'],
        default: 'Driver',
    },
    vehicleId: {
        type: String,
        // This is only required for users with the 'Driver' role
        required: function() { return this.role === 'Driver'; }
    },
    hospitalId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Hospital', // Links this driver to a specific Hospital document
        required: function() { return this.role === 'Driver'; }
    },
    verificationStatus: {
        type: String,
        enum: ['Pending', 'Verified', 'Rejected'],
        default: 'Pending',
    }
}, {
    timestamps: true // Adds createdAt and updatedAt timestamps automatically
});

// Middleware (Hook): Hash password before saving the user document 🔑
userSchema.pre('save', async function (next) {
    // Only hash the password if it has been modified (or is new)
    if (!this.isModified('password')) {
        return next();
    }

    // Generate a salt and hash the password
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