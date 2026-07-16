const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const rbac = require('../middleware/rbac');
const { getOperatorToArtRoute } = require('../controllers/navigationController');

// GET /api/navigation/operator-to-art
router.get('/operator-to-art', auth, rbac(['supervisor']), getOperatorToArtRoute);

module.exports = router;
