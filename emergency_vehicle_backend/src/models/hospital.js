const mongoose = require('mongoose');

const hospitalSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        unique: true,
    },
    location: {
        type: String,
        required: true,
    },
});

const Hospital = mongoose.model('Hospital', hospitalSchema);
module.exports = Hospital;
