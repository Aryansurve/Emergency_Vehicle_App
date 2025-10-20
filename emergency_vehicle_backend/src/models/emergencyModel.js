// src/models/emergencyModel.js

const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid'); // To generate a unique tracking ID

const emergencySchema = new mongoose.Schema({
    publicUserId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
    },
    trackingId: {
        type: String,
        default: () => uuidv4(), // Automatically generate a unique ID
        unique: true,
        index: true,
    },
    location: { // In a real app, this would be a GeoJSON object
        type: String,
        required: [true, 'Please provide the emergency location.'],
    },
    details: {
        type: String,
        required: [true, 'Please provide details about the emergency.'],
    },
    status: {
        type: String,
        enum: ['Pending', 'Assigned', 'En Route', 'On Scene', 'Resolved', 'Cancelled'],
        default: 'Pending',
    },
    assignedDriverId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null,
    },
    hospitalId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Hospital',
        default: null,
    }
}, {
    timestamps: true
});

module.exports = mongoose.model('Emergency', emergencySchema);