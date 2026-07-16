const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const {
  listTrains,
  createTrain,
  updateTrain,
  deleteTrain,
  getAvailableSupervisors,
  swapSupervisor,
  listTrainOperators,
  addOperators,
  reassignOperator,
  removeOperator,
  getAvailableOperators,
  getArtTrain,
  getArtTrainLocation
} = require('../controllers/artTrainController');

/**
 * ART Train Routes
 * All routes require JWT auth + lead_supervisor role
 */

// --- Train CRUD ---
// GET /api/art-trains
router.get('/', auth, rbac(['lead_supervisor']), listTrains);

// GET /api/art-trains/available-supervisors (must be before /:id)
router.get('/available-supervisors', auth, rbac(['lead_supervisor']), getAvailableSupervisors);

// POST /api/art-trains
router.post('/', auth, rbac(['lead_supervisor']), createTrain);

// PUT /api/art-trains/:id
router.put('/:id', auth, rbac(['lead_supervisor']), updateTrain);

// GET /api/art-trains/:id — get single ART train
router.get('/:id', auth, rbac(['master_admin', 'admin', 'lead_supervisor', 'supervisor']), getArtTrain);

// GET /api/art-trains/:id/location — get latest ART train location
router.get('/:id/location', auth, rbac(['supervisor', 'operator', 'lead_supervisor', 'admin', 'master_admin']), getArtTrainLocation);

// PUT /api/art-trains/:id — update ART trainsor
router.put('/:id/swap-supervisor', auth, rbac(['lead_supervisor']), swapSupervisor);

// DELETE /api/art-trains/:id
router.delete('/:id', auth, rbac(['lead_supervisor']), deleteTrain);

// --- Operator Assignment ---
// GET /api/art-trains/:id/operators
router.get('/:id/operators', auth, rbac(['lead_supervisor']), listTrainOperators);

// GET /api/art-trains/:id/available-operators
router.get('/:id/available-operators', auth, rbac(['lead_supervisor']), getAvailableOperators);

// POST /api/art-trains/:id/operators
router.post('/:id/operators', auth, rbac(['lead_supervisor']), addOperators);

// PUT /api/art-trains/:id/operators/:opId/reassign
router.put('/:id/operators/:opId/reassign', auth, rbac(['lead_supervisor']), reassignOperator);

// DELETE /api/art-trains/:id/operators/:opId
router.delete('/:id/operators/:opId', auth, rbac(['lead_supervisor']), removeOperator);

module.exports = router;
