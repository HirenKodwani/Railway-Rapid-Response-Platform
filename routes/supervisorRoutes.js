const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const { getMyArtTrain, getMyArtTrainOperators, updateMyArtTrainLocation } = require('../controllers/supervisorController');

/**
 * Supervisor Routes
 * All routes require JWT auth + supervisor role
 */

// GET /api/supervisor/my-art-train
router.get('/my-art-train', auth, rbac(['supervisor']), getMyArtTrain);

// GET /api/supervisor/my-art-train/operators
router.get('/my-art-train/operators', auth, rbac(['supervisor']), getMyArtTrainOperators);

// PUT /api/supervisor/my-art-train/location
router.put('/my-art-train/location', auth, rbac(['supervisor']), updateMyArtTrainLocation);

module.exports = router;
