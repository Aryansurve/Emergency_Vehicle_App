// src/utils/generateToken.js
const jwt = require('jsonwebtoken');

const generateToken = (id, role, verificationStatus) => {
    return jwt.sign({ id, role, verificationStatus }, process.env.JWT_SECRET, {
        expiresIn: process.env.JWT_EXPIRE || '30d',
    });
};

module.exports = generateToken;