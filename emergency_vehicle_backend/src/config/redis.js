const IORedis = require('ioredis');

// Use REDIS_URL if available, otherwise default to localhost
const redisClient = new IORedis(process.env.REDIS_URL);

redisClient.on('connect', () => {
  console.log('✅ Redis client connected');
});

redisClient.on('error', (err) => {
  console.error('❌ Redis connection error:', err);
});

module.exports = redisClient;
