const IORedis = require('ioredis');

// Connect to Redis. By default, it connects to 127.0.0.1:6379
// For production, you would use process.env.REDIS_URL
const redisClient = new IORedis();

redisClient.on('connect', () => {
    console.log('Redis client connected');
});

redisClient.on('error', (err) => {
    console.error('Redis connection error:', err);
});

module.exports = redisClient;