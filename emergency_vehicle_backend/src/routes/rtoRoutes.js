const express = require('express');
const router = express.Router();
const videoUpload = require('../middleware/upload'); // Ensure this is your Multer middleware
const rtoController = require('../controllers/rtoController');

// The 'video' string here MUST match the key name in your Flutter MultipartRequest
router.post('/upload-video', videoUpload.single('video'), rtoController.processRTOSubmission);

module.exports = router;