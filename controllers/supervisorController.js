const ArtTrain = require('../models/ArtTrain');
const ArtTrainOperator = require('../models/ArtTrainOperator');

/**
 * Get My ART Train
 * GET /api/supervisor/my-art-train
 * Returns the ART train assigned to this supervisor (only one per supervisor)
 */
const getMyArtTrain = async (req, res) => {
  try {
    const train = await ArtTrain.findOne({ supervisor_id: req.user._id })
      .populate('supervisor_id', 'name email phone employee_id')
      .populate('created_by', 'name email');

    if (!train) {
      return res.status(200).json({
        success: true,
        train: null,
        message: 'No ART Train assigned yet.',
      });
    }

    const operatorCount = await ArtTrainOperator.countDocuments({
      art_train_id: train._id,
    });

    res.status(200).json({
      success: true,
      train: { ...train.toObject(), operatorCount },
    });
  } catch (error) {
    console.error('Get my ART train error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

/**
 * Get My ART Train Operators
 * GET /api/supervisor/my-art-train/operators
 * Returns full operator details for the supervisor's assigned train
 */
const getMyArtTrainOperators = async (req, res) => {
  try {
    const train = await ArtTrain.findOne({ supervisor_id: req.user._id });

    if (!train) {
      return res.status(200).json({
        success: true,
        operators: [],
        message: 'No ART Train assigned yet.',
      });
    }

    const assignments = await ArtTrainOperator.find({
      art_train_id: train._id,
    })
      .populate('operator_id', '-password')
      .sort({ assigned_at: -1 });

    const operators = assignments.map((a) => ({
      ...a.operator_id.toObject(),
      assigned_at: a.assigned_at,
    }));

    res.status(200).json({
      success: true,
      count: operators.length,
      operators,
    });
  } catch (error) {
    console.error('Get my train operators error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

/**
 * Update My ART Train Location
 * PUT /api/supervisor/my-art-train/location
 * Updates the depot_lat and depot_lng for the supervisor's assigned train
 */
const updateMyArtTrainLocation = async (req, res) => {
  try {
    const { lat, lng } = req.body;

    if (lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'Latitude and longitude are required.' });
    }

    const train = await ArtTrain.findOne({ supervisor_id: req.user._id });

    if (!train) {
      return res.status(404).json({ success: false, message: 'No ART Train assigned.' });
    }

    train.depot_lat = lat;
    train.depot_lng = lng;
    await train.save();

    res.status(200).json({
      success: true,
      message: 'Train location updated successfully.',
      train,
    });
  } catch (error) {
    console.error('Update train location error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

module.exports = { getMyArtTrain, getMyArtTrainOperators, updateMyArtTrainLocation };
