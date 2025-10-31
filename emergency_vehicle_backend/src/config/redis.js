const IORedis = require('ioredis');

let redisClient;

if (process.env.REDIS_URL) {
  // Use Redis URL from environment (Render / Upstash)
  redisClient = new IORedis(process.env.REDIS_URL, {
    // Enable TLS if your URL starts with rediss://
    tls: {
      rejectUnauthorized: false,
    },
    maxRetriesPerRequest: 3, // Avoid infinite retry loops
    reconnectOnError: () => true, // Auto-reconnect if dropped
  });
} else {
  // Local fallback for development
  redisClient = new IORedis("redis://127.0.0.1:6379");
}

redisClient.on('connect', () => {
  console.log('✅ Redis client connected');
});

redisClient.on('ready', () => {
  console.log('🔹 Redis client ready for commands');
});

redisClient.on('error', (err) => {
  console.error('❌ Redis connection error:', err.message);
});

redisClient.on('close', () => {
  console.log('⚠️ Redis connection closed');
});

module.exports = redisClient;
