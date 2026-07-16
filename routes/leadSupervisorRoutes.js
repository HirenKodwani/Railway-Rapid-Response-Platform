const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const {
  getPendingOperators,
  approveOperator,
  rejectOperator,
  getNotifications,
  markNotificationRead,
  getUnreadCount,
  getReportsForLeadSupervisor,
} = require('../controllers/leadSupervisorController');

/**
 * Lead Supervisor Routes
 * All routes require JWT auth + lead_supervisor role
 */

// GET /api/lead-supervisor/pending-operators
router.get('/pending-operators', auth, rbac(['lead_supervisor']), getPendingOperators);

// PUT /api/lead-supervisor/approve-operator/:id
router.put('/approve-operator/:id', auth, rbac(['lead_supervisor']), approveOperator);

// PUT /api/lead-supervisor/reject-operator/:id
router.put('/reject-operator/:id', auth, rbac(['lead_supervisor']), rejectOperator);

// GET /api/lead-supervisor/notifications
router.get('/notifications', auth, rbac(['lead_supervisor']), getNotifications);

// GET /api/lead-supervisor/notifications/unread-count
router.get('/notifications/unread-count', auth, rbac(['lead_supervisor']), getUnreadCount);

// PUT /api/lead-supervisor/notifications/:id/read
router.put('/notifications/:id/read', auth, rbac(['lead_supervisor']), markNotificationRead);

// GET /api/lead-supervisor/reports
router.get('/reports', auth, rbac(['lead_supervisor', 'admin', 'super_admin', 'master_admin']), getReportsForLeadSupervisor);

module.exports = router;
