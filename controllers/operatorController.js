const ArtTrain = require('../models/ArtTrain');
const ArtTrainOperator = require('../models/ArtTrainOperator');

/**
 * Get My Assignment
 * GET /api/operator/my-assignment
 * Returns the ART train and supervisor details for the logged-in operator
 */
const getMyAssignment = async (req, res) => {
  try {
    // Find the operator's train assignment
    const assignment = await ArtTrainOperator.findOne({
      operator_id: req.user._id,
    });

    if (!assignment) {
      return res.status(200).json({
        success: true,
        assignment: null,
        message: 'You have not been assigned to an ART Train yet.',
      });
    }

    // Get the train details with supervisor populated
    const train = await ArtTrain.findById(assignment.art_train_id)
      .populate('supervisor_id', 'name email phone employee_id zone division');

    if (!train) {
      return res.status(200).json({
        success: true,
        assignment: null,
        message: 'Your assigned ART Train no longer exists.',
      });
    }

    // Count fellow operators
    const operatorCount = await ArtTrainOperator.countDocuments({
      art_train_id: train._id,
    });

    res.status(200).json({
      success: true,
      assignment: {
        train: {
          id: train._id,
          name: train.name,
          division: train.division,
          zone: train.zone,
          depot_lat: train.depot_lat,
          depot_lng: train.depot_lng,
          gps_device_id: train.gps_device_id,
          zone_id: train.zone_id,
          operatorCount,
        },
        supervisor: train.supervisor_id
          ? {
              id: train.supervisor_id._id,
              name: train.supervisor_id.name,
              email: train.supervisor_id.email,
              phone: train.supervisor_id.phone,
              employee_id: train.supervisor_id.employee_id,
            }
          : null,
        assigned_at: assignment.assigned_at,
      },
    });
  } catch (error) {
    console.error('Get my assignment error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

module.exports = { getMyAssignment };
