const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const {
  createIncident,
  listIncidents,
  getIncident,
  getActiveIncident,
  resolveIncident,
  respondToIncident,
  postLocation,
  bulkPostLocation,
  getOperatorLocations,
  getPendingIncidentsForOperator,
  getArtEta,
  getAcceptanceLog,
  getAttendanceLog,
  getResponseLog,
} = require('../controllers/incidentController');

/**
 * Incident Routes — Module 3: Rapid Response Incident Management
 */

// GET /api/incidents/active — must be before /:id to avoid route conflict
router.get('/active', auth, rbac(['supervisor', 'operator']), getActiveIncident);

// POST /api/incidents — create incident (supervisor only)
router.post('/', auth, rbac(['supervisor']), createIncident);

// GET /api/incidents — list incidents
router.get('/', auth, rbac(['supervisor', 'operator']), listIncidents);

// GET /api/incidents/:id — get single incident
router.get('/:id', auth, rbac(['supervisor', 'operator', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), getIncident);

// GET /api/incidents/pending-for-operator/:operatorId — get pending incidents for a specific operator
router.get('/pending-for-operator/:operatorId', auth, rbac(['operator', 'admin', 'master_admin']), getPendingIncidentsForOperator);

// PUT /api/incidents/:id/resolve — resolve incident (supervisor only)
router.put('/:id/resolve', auth, rbac(['supervisor']), resolveIncident);

// PUT /api/incidents/:id/respond — operator responds (accept/decline)
router.put('/:id/respond', auth, rbac(['operator']), respondToIncident);

// POST /api/incidents/:id/location — operator posts live location
router.post('/:id/location', auth, rbac(['operator']), postLocation);

// POST /api/incidents/:id/bulk-location — operator bulk syncs offline locations
router.post('/:id/bulk-location', auth, rbac(['operator']), bulkPostLocation);

// GET /api/incidents/:id/locations — supervisor fetches operator locations
router.get('/:id/locations', auth, rbac(['supervisor', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), getOperatorLocations);

// GET /api/incidents/:id/art-eta — fetch ART ETA to incident location
router.get('/:id/art-eta', auth, rbac(['supervisor']), getArtEta);

// GET /api/incidents/:id/acceptance-log
router.get('/:id/acceptance-log', auth, rbac(['supervisor', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), getAcceptanceLog);

// GET /api/incidents/:id/attendance-log
router.get('/:id/attendance-log', auth, rbac(['supervisor', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), getAttendanceLog);

// GET /api/incidents/:id/response-log
router.get('/:id/response-log', auth, rbac(['supervisor', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), getResponseLog);

const multer = require('multer');
const upload = multer({ storage: multer.memoryStorage() });

const { generateReport, downloadReport, uploadProof, getProofs } = require('../controllers/reportController');

// POST /api/incidents/:id/generate-report
router.post('/:id/generate-report', auth, rbac(['supervisor', 'lead_supervisor', 'admin', 'super_admin', 'master_admin']), generateReport);

// GET /api/incidents/:id/download-report
// Must be a GET request and we might not use auth if it's opened in browser via url_launcher
router.get('/:id/download-report', downloadReport);

// POST /api/incidents/:id/proofs
router.post('/:id/proofs', auth, rbac(['operator']), upload.single('file'), uploadProof);

// GET /api/incidents/:id/proofs
router.get('/:id/proofs', auth, getProofs);

module.exports = router;
