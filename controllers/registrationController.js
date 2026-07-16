const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Counter = require('../models/Counter');
const Notification = require('../models/Notification');
const { sanitizePhone } = require('../utils/validators');

// --- Employee ID generation (shared logic from userController) ---

const getInitials = (name) => {
  if (!name) return 'HQ';
  return name.split(' ').map(word => word[0].toUpperCase()).join('');
};

const getDivCode = (name) => {
  if (!name) return 'HQ';
  return name.replace(/[^a-zA-Z]/g, '').substring(0, 3).toUpperCase();
};

const ROLE_CODES = {
  'master_admin': 'MA',
  'super_admin': 'SA',
  'admin': 'ADM',
  'lead_supervisor': 'LSV',
  'supervisor': 'SUP',
  'operator': 'OPR',
};

const generateEmployeeId = async (zone, division, role) => {
  const zCode = getInitials(zone);
  const dCode = getDivCode(division);
  const rCode = ROLE_CODES[role] || 'EMP';
  const prefix = `IR${zCode}${dCode}${rCode}`;

  const counter = await Counter.findByIdAndUpdate(
    { _id: prefix },
    { $inc: { seq: 1 } },
    { new: true, upsert: true }
  );

  const suffix = String(counter.seq).padStart(4, '0');
  return prefix + suffix;
};

/**
 * Operator Self-Registration Controller
 * POST /api/auth/register-operator
 * Public — no auth required
 */
const registerOperator = async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      division,
      zone,
      city,
      address,
      lat,
      lng,
      password,
      specialisation,
    } = req.body;

    // --- Validate required fields ---
    if (!name || !email || !phone || !division || !zone || !city || !password || !specialisation) {
      return res.status(400).json({
        success: false,
        message: 'Please provide all required fields: name, email, phone, zone, division, city, password, specialisation.',
      });
    }

    // --- Validate name ---
    if (name.trim().length < 2) {
      return res.status(400).json({
        success: false,
        message: 'Name must be at least 2 characters.',
      });
    }
    if (!/^[a-zA-Z\s\-]+$/.test(name.trim())) {
      return res.status(400).json({
        success: false,
        message: 'Name can only contain alphabetic characters, spaces, and hyphens.',
      });
    }

    // --- Validate email format ---
    const sanitizedEmail = email.toString().trim().toLowerCase();
    const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    if (!emailRegex.test(sanitizedEmail)) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid email address.',
      });
    }

    // --- Validate phone format (Indian 10-digit) ---
    const sanitizedPhone = sanitizePhone(phone.toString().trim());
    if (!/^[6-9]\d{9}$/.test(sanitizedPhone)) {
      return res.status(400).json({
        success: false,
        message: 'Phone must be exactly 10 digits starting with 6-9.',
      });
    }

    // --- Validate password ---
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters.',
      });
    }
    if (!/(?=.*[a-z])/.test(password) || !/(?=.*\d)/.test(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must contain at least one lowercase letter and one number.',
      });
    }

    // --- Check uniqueness: email ---
    const existingEmail = await User.findOne({ email: sanitizedEmail });
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message: 'A user with this email already exists.',
      });
    }

    // --- Check uniqueness: phone ---
    const existingPhone = await User.findOne({ phone: sanitizedPhone });
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: 'A user with this phone number already exists.',
      });
    }

    // --- Resolve lead supervisor for the division ---
    const leadSupervisor = await User.findOne({
      role: 'lead_supervisor',
      division: division.toString().trim(),
      status: 'approved',
      isActive: true,
    });

    // --- Generate employee ID ---
    const generatedEmployeeId = await generateEmployeeId(zone, division, 'operator');

    // --- Hash password ---
    const hashedPassword = await bcrypt.hash(password, 12);

    // --- Create user with status: pending ---
    const newUser = await User.create({
      name: name.toString().trim(),
      email: sanitizedEmail,
      phone: sanitizedPhone,
      role: 'operator',
      employee_id: generatedEmployeeId,
      zone: zone.toString().trim(),
      division: division.toString().trim(),
      city: city.toString().trim(),
      lat: lat || undefined,
      lng: lng || undefined,
      address: address ? address.toString().trim() : undefined,
      password: hashedPassword,
      specialisation: specialisation.toString().trim(),
      createdBy: null,
      isActive: true,
      status: 'pending',
    });

    // --- Create notification for lead supervisor (if found) ---
    if (leadSupervisor) {
      await Notification.create({
        recipient_id: leadSupervisor._id,
        type: 'operator_registration',
        reference_id: newUser._id,
        message: `New operator registration: ${newUser.name} (${newUser.employee_id}) is awaiting your approval.`,
      });
    }

    // --- Return success ---
    res.status(201).json({
      success: true,
      message: 'Registration submitted successfully. Awaiting approval from your division\'s Lead Supervisor.',
      user: {
        id: newUser._id,
        name: newUser.name,
        email: newUser.email,
        employee_id: newUser.employee_id,
        status: newUser.status,
      },
    });
  } catch (error) {
    console.error('Registration error:', error.message);

    // Handle Mongoose duplicate key errors
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern)[0];
      return res.status(409).json({
        success: false,
        message: `A user with this ${field} already exists.`,
      });
    }

    // Handle Mongoose validation errors
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map((e) => e.message);
      return res.status(400).json({
        success: false,
        message: messages.join(', '),
      });
    }

    res.status(500).json({
      success: false,
      message: 'Internal server error during registration.',
    });
  }
};

module.exports = { registerOperator };
