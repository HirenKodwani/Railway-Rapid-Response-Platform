const dotenv = require('dotenv');

/**
 * Load and validate environment variables
 * Call this at the very start of the application
 */
const loadEnv = () => {
  dotenv.config();

  const requiredVars = [
    'PORT',
    'MONGO_URI',
    'JWT_SECRET',
    'JWT_EXPIRES_IN',
    'MASTER_ADMIN_NAME',
    'MASTER_ADMIN_EMAIL',
    'MASTER_ADMIN_PHONE',
    'MASTER_ADMIN_PASSWORD',
    'MASTER_ADMIN_EMPLOYEE_ID',
    'CLOUDINARY_CLOUD_NAME',
    'CLOUDINARY_API_KEY',
    'CLOUDINARY_API_SECRET',
  ];

  const missing = requiredVars.filter((key) => !process.env[key]);

  if (missing.length > 0) {
    console.error(`❌ Missing environment variables: ${missing.join(', ')}`);
    process.exit(1);
  }

  console.log('✅ Environment variables loaded successfully');
};

module.exports = loadEnv;
