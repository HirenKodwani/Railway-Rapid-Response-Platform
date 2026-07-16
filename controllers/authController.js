const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { sanitizePhone } = require('../utils/validators');

/**
 * Login Controller
 * POST /api/auth/login
 * Body: { identifier: String, password: String }
 * identifier accepts either email or phone
 */
const login = async (req, res) => {
  try {
    const { identifier, password } = req.body;

    // Validate input
    if (!identifier || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email/phone and password',
      });
    }

    // Sanitize identifier
    let sanitizedIdentifier = identifier.toString().trim().toLowerCase();
    if (!sanitizedIdentifier.includes('@')) {
      sanitizedIdentifier = sanitizePhone(sanitizedIdentifier);
    }

    // Find user by email OR phone
    const user = await User.findOne({
      $or: [
        { email: sanitizedIdentifier },
        { phone: sanitizedIdentifier },
      ],
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. User not found.',
      });
    }

    // Check if user is active
    if (!user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Your account has been deactivated. Contact your administrator.',
      });
    }

    // Check user approval status
    if (user.status === 'pending') {
      return res.status(403).json({
        success: false,
        message: 'Your registration is pending approval from your division\'s Lead Supervisor.',
      });
    }

    if (user.status === 'rejected') {
      return res.status(403).json({
        success: false,
        message: 'Your registration has been rejected. Contact your division\'s Lead Supervisor for details.',
      });
    }

    // Compare password
    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. Wrong password.',
      });
    }

    // Generate JWT token
    const token = jwt.sign(
      {
        id: user._id,
        role: user.role,
        email: user.email,
      },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN }
    );

    // Return token and user data (exclude password)
    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        zone: user.zone,
        division: user.division,
        employee_id: user.employee_id,
        specialisation: user.specialisation,
        isActive: user.isActive,
      },
    });
  } catch (error) {
    console.error('Login error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error',
    });
  }
};

/**
 * Logout Controller
 * POST /api/auth/logout
 * Clears the user's FCM token from the database
 */
const logout = async (req, res) => {
  try {
    if (req.user && req.user._id) {
      await User.findByIdAndUpdate(req.user._id, { fcmToken: null });
    }
    
    res.status(200).json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    console.error('Logout error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error during logout',
    });
  }
};

module.exports = { login, logout };
