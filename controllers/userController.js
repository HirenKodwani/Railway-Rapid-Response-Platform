const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Counter = require('../models/Counter');
const ArtTrain = require('../models/ArtTrain');
const ArtTrainOperator = require('../models/ArtTrainOperator');

// Helper to get initials (e.g. "Central Railway" -> "CR")
const getInitials = (name) => {
  if (!name) return 'HQ';
  return name.split(' ').map(word => word[0].toUpperCase()).join('');
};

// Helper to get division code (e.g. "Mumbai CST" -> "MUM")
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
  'operator': 'OPR'
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
 * Role hierarchy — each role can only create the role one level below
 */
const ROLES = [
  'master_admin',
  'super_admin',
  'admin',
  'lead_supervisor',
  'supervisor',
  'operator',
];

const getRoleLevel = (role) => ROLES.indexOf(role);

/**
 * Create User Controller
 * POST /api/users/create
 * Creates users with a role strictly below the creator's role
 * Enforces zone/division propagation based on hierarchy
 */
const createUser = async (req, res) => {
  try {
    const creatorRole = req.user.role;
    const creatorLevel = getRoleLevel(creatorRole);

    const {
      name,
      email,
      phone,
      role: targetRole,
      zone,
      division,
      city,
      lat,
      lng,
      address,
      password,
    } = req.body;

    // Validate required fields
    if (!name || !email || !phone || !targetRole || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide all required fields: name, email, phone, role, password.',
      });
    }

    const targetLevel = getRoleLevel(targetRole);

    // Safety checks
    if (creatorLevel === -1 || targetLevel === -1) {
      return res.status(400).json({ success: false, message: 'Invalid role provided.' });
    }
    
    // Creator must be higher level than target (smaller index is higher)
    if (creatorLevel >= targetLevel) {
      return res.status(403).json({
        success: false,
        message: `As a ${creatorRole}, you cannot create a ${targetRole}.`,
      });
    }

    // --- Phone format validation ---
    const sanitizedPhone = phone.toString().trim();
    if (!/^[6-9]\d{9}$/.test(sanitizedPhone)) {
      return res.status(400).json({
        success: false,
        message: 'Phone must be exactly 10 digits starting with 6-9.',
      });
    }

    // --- Zone/Division/City enforcement based on hierarchy ---
    let resolvedZone = zone ? zone.toString().trim() : undefined;
    let resolvedDivision = division ? division.toString().trim() : undefined;
    let resolvedCity = city ? city.toString().trim() : undefined;

    // 1. Target Role is super_admin (Level 1, index 1)
    if (targetRole === 'super_admin') {
      if (!resolvedZone) {
        return res.status(400).json({ success: false, message: 'Zone is required when creating a Super Admin.' });
      }
      resolvedDivision = undefined; // super_admin has no division
    }

    // 2. Target Role is admin (Level 2)
    if (targetRole === 'admin') {
      if (creatorRole === 'master_admin') {
        if (!resolvedZone || !resolvedDivision) {
          return res.status(400).json({ success: false, message: 'Zone and Division are required when Master Admin creates an Admin.' });
        }
      } else {
        // creator is super_admin
        resolvedZone = req.user.zone;
        if (!resolvedDivision) {
          return res.status(400).json({ success: false, message: 'Division is required when creating an Admin.' });
        }
      }
    }

    // 3. Target Role is below admin (lead_supervisor, supervisor, operator)
    if (targetLevel > 2) {
      if (creatorRole === 'master_admin') {
        if (!resolvedZone || !resolvedDivision) {
          return res.status(400).json({ success: false, message: `Zone and Division are required when Master Admin creates a ${targetRole}.` });
        }
      } else if (creatorRole === 'super_admin') {
        resolvedZone = req.user.zone;
        if (!resolvedDivision) {
          return res.status(400).json({ success: false, message: `Division is required when Super Admin creates a ${targetRole}.` });
        }
      } else {
        // creator is admin, lead_supervisor, or supervisor
        resolvedZone = req.user.zone;
        resolvedDivision = req.user.division;
      }
    }

    // Verify creator has zone/division if they are supposed to propagate it
    if (creatorRole !== 'master_admin' && !req.user.zone) {
       return res.status(400).json({ success: false, message: 'Your account does not have a zone assigned. Cannot create subordinates.' });
    }
    if (['admin', 'lead_supervisor', 'supervisor'].includes(creatorRole) && !req.user.division) {
       return res.status(400).json({ success: false, message: 'Your account does not have a division assigned. Cannot create subordinates.' });
    }

    // Sanitize inputs
    const sanitizedEmail = email.toString().trim().toLowerCase();

    // Check for uniqueness — email
    const existingEmail = await User.findOne({ email: sanitizedEmail });
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message: 'A user with this email already exists.',
      });
    }

    // Check for uniqueness — phone
    const existingPhone = await User.findOne({ phone: sanitizedPhone });
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: 'A user with this phone number already exists.',
      });
    }

    // Generate smart employee ID
    const generatedEmployeeId = await generateEmployeeId(resolvedZone, resolvedDivision, targetRole);

    // Hash password with 12 salt rounds
    const hashedPassword = await bcrypt.hash(password, 12);

    // Create the user
    const newUser = await User.create({
      name: name.toString().trim(),
      email: sanitizedEmail,
      phone: sanitizedPhone,
      role: targetRole,
      employee_id: generatedEmployeeId,
      zone: resolvedZone || undefined,
      division: resolvedDivision || undefined,
      city: resolvedCity || undefined,
      lat: lat || undefined,
      lng: lng || undefined,
      address: address ? address.toString().trim() : undefined,
      password: hashedPassword,
      createdBy: req.user._id,
      isActive: true,
    });

    // Return created user without password
    const userResponse = newUser.toObject();
    delete userResponse.password;

    res.status(201).json({
      success: true,
      message: 'User created successfully.',
      user: userResponse,
    });
  } catch (error) {
    console.error('Create user error:', error.message);

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
      message: 'Internal server error while creating user.',
    });
  }
};

/**
 * Get My Users Controller
 * GET /api/users
 * Returns all descendant users created under the logged-in user's hierarchy
 */
const getMyUsers = async (req, res) => {
  try {
    const descendants = await User.aggregate([
      { $match: { _id: req.user._id } },
      {
        $graphLookup: {
          from: 'users',
          startWith: '$_id',
          connectFromField: '_id',
          connectToField: 'createdBy',
          as: 'descendants',
        },
      },
    ]);

    let users = descendants[0]?.descendants || [];

    // Remove passwords and sort by creation date
    users = users.map(user => {
      delete user.password;
      return user;
    }).sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    res.status(200).json({
      success: true,
      count: users.length,
      users,
    });
  } catch (error) {
    console.error('Get users error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching users.',
      error: error.message,
      stack: error.stack
    });
  }
};

/**
 * Update User Controller
 * PUT /api/users/:id
 * Only the creator (createdBy) can update their created users
 * Enforces zone/division propagation rules
 */
const updateUser = async (req, res) => {
  try {
    const { id } = req.params;
    const targetUser = await User.findById(id);

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    // Only creator can update
    if (!targetUser.createdBy || targetUser.createdBy.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'You can only update users that you created.',
      });
    }

    const {
      name,
      email,
      phone,
      employee_id,
      zone,
      division,
      city,
      lat,
      lng,
      address,
      password,
    } = req.body;

    // --- Phone format validation (if provided) ---
    if (phone) {
      const sanitizedPhone = phone.toString().trim();
      if (!/^[6-9]\d{9}$/.test(sanitizedPhone)) {
        return res.status(400).json({
          success: false,
          message: 'Phone must be exactly 10 digits starting with 6-9.',
        });
      }

      // Check uniqueness (excluding self)
      const existingPhone = await User.findOne({ phone: sanitizedPhone, _id: { $ne: id } });
      if (existingPhone) {
        return res.status(409).json({
          success: false,
          message: 'A user with this phone number already exists.',
        });
      }
      targetUser.phone = sanitizedPhone;
    }

    // --- Email uniqueness (if provided) ---
    if (email) {
      const sanitizedEmail = email.toString().trim().toLowerCase();
      const existingEmail = await User.findOne({ email: sanitizedEmail, _id: { $ne: id } });
      if (existingEmail) {
        return res.status(409).json({
          success: false,
          message: 'A user with this email already exists.',
        });
      }
      targetUser.email = sanitizedEmail;
    }

    // --- Employee ID uniqueness (if provided) ---
    if (employee_id) {
      const sanitizedEmpId = employee_id.toString().trim();
      const existingEmpId = await User.findOne({ employee_id: sanitizedEmpId, _id: { $ne: id } });
      if (existingEmpId) {
        return res.status(409).json({
          success: false,
          message: 'A user with this Employee ID already exists.',
        });
      }
      targetUser.employee_id = sanitizedEmpId;
    }

    // --- Zone/Division enforcement ---
    const creatorRole = req.user.role;
    const targetRole = targetUser.role;

    if (creatorRole === 'master_admin') {
      if (zone) targetUser.zone = zone.toString().trim();
      if (division && targetRole !== 'super_admin') {
        targetUser.division = division.toString().trim();
      }
    } else if (creatorRole === 'super_admin') {
      targetUser.zone = req.user.zone;
      if (division) targetUser.division = division.toString().trim();
    } else {
      targetUser.zone = req.user.zone;
      targetUser.division = req.user.division;
    }

    // Update simple fields
    if (name) targetUser.name = name.toString().trim();
    if (city !== undefined) targetUser.city = city ? city.toString().trim() : undefined;
    if (address !== undefined) targetUser.address = address ? address.toString().trim() : undefined;
    if (lat !== undefined) targetUser.lat = lat;
    if (lng !== undefined) targetUser.lng = lng;

    // Password update (optional — only if provided)
    if (password && password.length >= 6) {
      targetUser.password = await bcrypt.hash(password, 12);
    }

    await targetUser.save();

    // Return updated user without password
    const userResponse = targetUser.toObject();
    delete userResponse.password;

    res.status(200).json({
      success: true,
      message: 'User updated successfully.',
      user: userResponse,
    });
  } catch (error) {
    console.error('Update user error:', error.message);

    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern)[0];
      return res.status(409).json({
        success: false,
        message: `A user with this ${field} already exists.`,
      });
    }

    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map((e) => e.message);
      return res.status(400).json({
        success: false,
        message: messages.join(', '),
      });
    }

    res.status(500).json({
      success: false,
      message: 'Internal server error while updating user.',
    });
  }
};

/**
 * Delete User Controller
 * DELETE /api/users/:id
 * Only the creator (createdBy) can delete their created users
 * Orphans sub-users by setting their createdBy to null
 */
const deleteUser = async (req, res) => {
  try {
    const { id } = req.params;
    const targetUser = await User.findById(id);

    if (!targetUser) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    // Only creator can delete
    if (!targetUser.createdBy || targetUser.createdBy.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'You can only delete users that you created.',
      });
    }

    // Orphan sub-users: set their createdBy to null
    await User.updateMany({ createdBy: id }, { $set: { createdBy: null } });

    // Delete the user
    await User.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'User deleted successfully.',
    });
  } catch (error) {
    console.error('Delete user error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while deleting user.',
    });
  }
};

/**
 * Update My Password (Profile)
 * PUT /api/users/profile/password
 * Any logged-in user can update their own password
 */
const updateMyPassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Please provide both current and new password.',
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'New password must be at least 6 characters long.',
      });
    }

    const user = await User.findById(req.user._id).select('+password');
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Incorrect current password.',
      });
    }

    user.password = await bcrypt.hash(newPassword, 12);
    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password updated successfully.',
    });
  } catch (error) {
    console.error('Update password error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while updating password.',
    });
  }
};

/**
 * Get Hierarchy Tree Controller
 * GET /api/users/hierarchy
 * Returns a nested tree of users based on the requester's role scope
 */
const getHierarchyTree = async (req, res) => {
  try {
    const currentUser = req.user;

    /**
     * Recursively build tree for a given parent user
     */
    const buildSubtree = async (parentUser) => {
      let children = [];

      if (parentUser.role === 'master_admin') {
        children = await User.find({ role: 'super_admin' }).select('-password').sort({ name: 1 });
      } else if (parentUser.role === 'super_admin') {
        children = await User.find({ role: 'admin', zone: parentUser.zone }).select('-password').sort({ name: 1 });
      } else if (parentUser.role === 'admin') {
        children = await User.find({ role: 'lead_supervisor', zone: parentUser.zone, division: parentUser.division }).select('-password').sort({ name: 1 });
      } else if (parentUser.role === 'lead_supervisor') {
        children = await User.find({ role: 'supervisor', createdBy: parentUser._id }).select('-password').sort({ name: 1 });
      } else if (parentUser.role === 'supervisor') {
        const train = await ArtTrain.findOne({ supervisor_id: parentUser._id });
        if (train) {
          const assignments = await ArtTrainOperator.find({ art_train_id: train._id }).populate('operator_id', '-password');
          children = assignments.map(a => a.operator_id).filter(op => op);
          children.sort((a, b) => a.name.localeCompare(b.name));
        }
      }

      const childNodes = [];
      for (const child of children) {
        const subtree = await buildSubtree(child);
        childNodes.push(subtree);
      }

      return {
        user: {
          id: parentUser._id,
          name: parentUser.name,
          role: parentUser.role,
          email: parentUser.email,
          phone: parentUser.phone,
          employeeId: parentUser.employee_id,
          zone: parentUser.zone || null,
          division: parentUser.division || null,
          city: parentUser.city || null,
          isActive: parentUser.isActive,
        },
        children: childNodes,
      };
    };

    // Master Admin: build tree starting from all master admins
    if (currentUser.role === 'master_admin') {
      // Find all master admins as root nodes
      const masterAdmins = await User.find({ role: 'master_admin' }).select('-password');
      const roots = [];
      for (const ma of masterAdmins) {
        const tree = await buildSubtree(ma);
        roots.push(tree);
      }

      return res.status(200).json({
        success: true,
        hierarchy: roots.length === 1 ? roots[0] : { user: { name: 'Indian Railways', role: 'organization' }, children: roots },
      });
    }

    // All other roles: build tree starting from themselves
    const tree = await buildSubtree(currentUser);

    res.status(200).json({
      success: true,
      hierarchy: tree,
    });
  } catch (error) {
    console.error('Hierarchy tree error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching hierarchy.',
      error: error.message,
      stack: error.stack
    });
  }
};

/**
 * Update FCM Token
 * PUT /api/users/fcm-token
 * Allows any authenticated user to update their FCM token for push notifications
 */
const updateFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required.',
      });
    }

    // Clear this FCM token from any other users to prevent cross-account notifications on the same device
    await User.updateMany(
      { fcmToken: fcmToken, _id: { $ne: req.user._id } },
      { $set: { fcmToken: null } }
    );

    // Clear this FCM token from any other users to prevent cross-account notifications on the same device
    await User.updateMany(
      { fcmToken: fcmToken, _id: { $ne: req.user._id } },
      { $set: { fcmToken: null } }
    );

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { fcmToken },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'FCM token updated successfully.',
    });
  } catch (error) {
    console.error('Update FCM token error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while updating FCM token.',
    });
  }
};

module.exports = { createUser, getMyUsers, updateUser, deleteUser, getHierarchyTree, updateMyPassword, updateFcmToken };
