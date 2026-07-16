const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const { getMyAssignment } = require('../controllers/operatorController');

/**
 * Operator Routes
 * All routes require JWT auth + operator role
 */

// GET /api/operator/my-assignment
router.get('/my-assignment', auth, rbac(['operator']), getMyAssignment);

module.exports = router;
