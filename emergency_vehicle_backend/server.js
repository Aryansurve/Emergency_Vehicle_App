const express = require('express');
const dotenv = require('dotenv');
const connectDB = require('./src/config/db');
const authRoutes = require('./src/routes/auth'); // Correctly imported here!
const adminRoutes = require('./src/routes/admin');
const hospitalRoutes = require('./src/routes/hospital');



// Load environment variables from .env file
dotenv.config();

// Connect to the database
connectDB();

const app = express();

// Middleware to parse incoming JSON bodies
app.use(express.json());
app.use('/api/v1/admin', adminRoutes);
// A simple test route to confirm the server is accessible
app.get('/', (req, res) => {
    res.send('API is running...');
});
app.use('/api/v1/hospitals', hospitalRoutes);

// Mount the authentication router
// Any request to a URL starting with '/api/v1/auth' will be handled by authRoutes
app.use('/api/v1/auth', authRoutes);

const PORT = process.env.PORT || 5000;

const server = app.listen(
    PORT,
    console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`)
);

// Optional but good practice: Handle unhandled promise rejections
process.on('unhandledRejection', (err, promise) => {
    console.log(`Error: ${err.message}`);
    server.close(() => process.exit(1));
});