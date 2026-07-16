const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const { createUser, getMyUsers, updateUser, deleteUser, getHierarchyTree, updateMyPassword, updateFcmToken } = require('../controllers/userController');

/**
 * User Routes
 * All routes require JWT authentication
 */

// PUT /api/users/profile/password - Any logged-in user can update their password
router.put('/profile/password', auth, updateMyPassword);

// PUT /api/users/fcm-token - Any logged-in user can update their FCM token
router.put('/fcm-token', auth, updateFcmToken);

// POST /api/users/create — Create a subordinate user (role-gated)
router.post(
  '/create',
  auth,
  rbac(['master_admin', 'super_admin', 'admin', 'lead_supervisor', 'supervisor']),
  createUser
);

// GET /api/users — Get users created by the logged-in user
router.get('/', auth, getMyUsers);

// GET /api/users/hierarchy — Get hierarchy tree based on requester's role scope
router.get('/hierarchy', auth, getHierarchyTree);

// PUT /api/users/:id — Update a user (only creator can update)
router.put(
  '/:id',
  auth,
  rbac(['master_admin', 'super_admin', 'admin', 'lead_supervisor', 'supervisor']),
  updateUser
);

// DELETE /api/users/:id — Delete a user (only creator can delete)
router.delete(
  '/:id',
  auth,
  rbac(['master_admin', 'super_admin', 'admin', 'lead_supervisor', 'supervisor']),
  deleteUser
);

module.exports = router;
