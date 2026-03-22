const multer = require('multer');
const path = require('path');

// Basic disk storage configuration
const storage = multer.diskStorage({});

const fileFilter = (req, file, cb) => {
  // Ensure it's a video
  if (file.mimetype.startsWith('video')) {
    cb(null, true);
  } else {
    cb(new Error('Only video files are allowed!'), false);
  }
};

const upload = multer({ storage, fileFilter });
module.exports = upload;