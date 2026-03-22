const cloudinary = require('cloudinary').v2;

exports.processRTOSubmission = async (req, res) => {
    // Force refresh config using ENV variables
    cloudinary.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
        api_key: process.env.CLOUDINARY_API_KEY,
        api_secret: process.env.CLOUDINARY_API_SECRET
    });

    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: "No video file provided." });
        }

        console.log("🚀 Starting Cloudinary upload...");

        // Use upload_large for better signature handling with videos
        const result = await cloudinary.uploader.upload(req.file.path, {
            resource_type: "video",
            folder: "rto_dashcam_records",
            // We'll let Cloudinary handle the public_id for a moment to simplify the signature
            unique_filename: true, 
        });

        console.log("✅ Cloudinary Upload Success!");
        res.status(200).json({
            success: true,
            videoUrl: result.secure_url,
        });

    } catch (error) {
        console.error("❌ Cloudinary Error Details:", error);
        res.status(401).json({ 
            success: false, 
            message: "Authentication failed. Check your API Secret.",
            error: error.message 
        });
    }
};