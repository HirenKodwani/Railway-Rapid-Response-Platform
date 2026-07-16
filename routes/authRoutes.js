const express = require('express');
const router = express.Router();
const { login, logout } = require('../controllers/authController');
const { registerOperator } = require('../controllers/registrationController');
const auth = require('../middleware/auth');

/**
 * Auth Routes
 * POST /api/auth/login — No auth middleware required
 * POST /api/auth/register-operator — Public operator self-registration
 * POST /api/auth/logout - Protected, clears FCM token
 */
router.post('/login', login);
router.post('/register-operator', registerOperator);
router.post('/logout', auth, logout);

module.exports = router;
