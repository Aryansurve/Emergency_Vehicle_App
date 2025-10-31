// src/models/hospitalModel.js

const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
    name: {
        type: String,
        required: [true, 'Please provide a hospital name'],
        unique: true,
    },
    location: {
        type: String,
        required: [true, 'Please provide a location'],
    },
    contactNumber: {
        type: String,
        required: [true, 'Please provide a contact number'],
    }
}, {
    timestamps: true
});

module.exports = mongoose.model('Hospital', hospitalSchema);
