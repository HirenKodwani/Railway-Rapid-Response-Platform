const mongoose = require('mongoose');
const ArtTrain = require('../models/ArtTrain');
const ArtTrainOperator = require('../models/ArtTrainOperator');
const User = require('../models/User');

/**
 * List ART Trains
 * GET /api/art-trains
 * Returns trains for the lead supervisor's division
 */
const listTrains = async (req, res) => {
  try {
    const { division } = req.user;

    if (!division) {
      return res.status(400).json({
        success: false,
        message: 'Your account does not have a division assigned.',
      });
    }

    const trains = await ArtTrain.find({ division })
      .populate('supervisor_id', 'name email phone employee_id')
      .sort({ createdAt: -1 });

    // Attach operator count to each train
    const trainsWithCounts = await Promise.all(
      trains.map(async (train) => {
        const operatorCount = await ArtTrainOperator.countDocuments({
          art_train_id: train._id,
        });
        return {
          ...train.toObject(),
          operatorCount,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: trainsWithCounts.length,
      trains: trainsWithCounts,
    });
  } catch (error) {
    console.error('List trains error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching trains.',
    });
  }
};

/**
 * Create ART Train
 * POST /api/art-trains
 */
const createTrain = async (req, res) => {
  try {
    const {
      name,
      depot_lat,
      depot_lng,
      gps_device_id,
      supervisor_id,
      zone_id,
    } = req.body;

    if (!name) {
      return res.status(400).json({
        success: false,
        message: 'Train name/number is required.',
      });
    }

    // Division is auto-filled from lead supervisor's division
    const division = req.user.division;
    const zone = req.user.zone;

    if (!division) {
      return res.status(400).json({
        success: false,
        message: 'Your account does not have a division assigned.',
      });
    }

    // Validate supervisor if provided
    if (supervisor_id) {
      const supervisor = await User.findById(supervisor_id);
      if (!supervisor || supervisor.role !== 'supervisor') {
        return res.status(400).json({
          success: false,
          message: 'Invalid supervisor selected.',
        });
      }
      if (supervisor.division !== division) {
        return res.status(400).json({
          success: false,
          message: 'Supervisor must be from the same division.',
        });
      }

      // Check if supervisor is already assigned
      const existingAssignment = await ArtTrain.findOne({ supervisor_id });
      if (existingAssignment) {
        return res.status(400).json({
          success: false,
          message: `This supervisor is already assigned to "${existingAssignment.name}". Use the swap endpoint to force reassign.`,
        });
      }
    }

    const newTrain = await ArtTrain.create({
      name: name.toString().trim(),
      division,
      zone,
      depot_lat,
      depot_lng,
      gps_device_id: gps_device_id ? gps_device_id.toString().trim() : undefined,
      supervisor_id: supervisor_id || null,
      zone_id: zone_id || undefined,
      created_by: req.user._id,
    });

    const populated = await ArtTrain.findById(newTrain._id)
      .populate('supervisor_id', 'name email phone employee_id');

    res.status(201).json({
      success: true,
      message: 'ART Train created successfully.',
      train: { ...populated.toObject(), operatorCount: 0 },
    });
  } catch (error) {
    console.error('Create train error:', error.message);
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'A train with this name already exists.',
      });
    }
    res.status(500).json({
      success: false,
      message: 'Internal server error while creating train.',
    });
  }
};

/**
 * Update ART Train
 * PUT /api/art-trains/:id
 */
const updateTrain = async (req, res) => {
  try {
    const { id } = req.params;
    const train = await ArtTrain.findById(id);

    if (!train) {
      return res.status(404).json({
        success: false,
        message: 'ART Train not found.',
      });
    }

    // Verify division ownership
    if (train.division !== req.user.division) {
      return res.status(403).json({
        success: false,
        message: 'You can only manage trains in your division.',
      });
    }

    const {
      name,
      depot_lat,
      depot_lng,
      gps_device_id,
      supervisor_id,
      zone_id,
    } = req.body;

    // Validate supervisor if changed
    if (supervisor_id !== undefined && supervisor_id !== (train.supervisor_id ? train.supervisor_id.toString() : null)) {
      if (supervisor_id) {
        const supervisor = await User.findById(supervisor_id);
        if (!supervisor || supervisor.role !== 'supervisor') {
          return res.status(400).json({
            success: false,
            message: 'Invalid supervisor selected.',
          });
        }
        if (supervisor.division !== req.user.division) {
          return res.status(400).json({
            success: false,
            message: 'Supervisor must be from the same division.',
          });
        }

        const existingAssignment = await ArtTrain.findOne({
          supervisor_id,
          _id: { $ne: id },
        });
        if (existingAssignment) {
          return res.status(400).json({
            success: false,
            message: `This supervisor is already assigned to "${existingAssignment.name}". Use the swap endpoint to force reassign.`,
          });
        }
      }
      train.supervisor_id = supervisor_id || null;
    }

    if (name) train.name = name.toString().trim();
    if (depot_lat !== undefined) train.depot_lat = depot_lat;
    if (depot_lng !== undefined) train.depot_lng = depot_lng;
    if (gps_device_id !== undefined) train.gps_device_id = gps_device_id ? gps_device_id.toString().trim() : undefined;
    if (zone_id !== undefined) train.zone_id = zone_id;

    await train.save();

    const populated = await ArtTrain.findById(train._id)
      .populate('supervisor_id', 'name email phone employee_id');

    const operatorCount = await ArtTrainOperator.countDocuments({ art_train_id: train._id });

    res.status(200).json({
      success: true,
      message: 'ART Train updated successfully.',
      train: { ...populated.toObject(), operatorCount },
    });
  } catch (error) {
    console.error('Update train error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while updating train.',
    });
  }
};

/**
 * Delete ART Train
 * DELETE /api/art-trains/:id
 * Hard delete — unlinks supervisor and all operator assignments
 */
const deleteTrain = async (req, res) => {
  try {
    const { id } = req.params;
    const train = await ArtTrain.findById(id);

    if (!train) {
      return res.status(404).json({
        success: false,
        message: 'ART Train not found.',
      });
    }

    if (train.division !== req.user.division) {
      return res.status(403).json({
        success: false,
        message: 'You can only manage trains in your division.',
      });
    }

    // Remove all operator assignments for this train
    await ArtTrainOperator.deleteMany({ art_train_id: id });

    // Delete the train
    await ArtTrain.findByIdAndDelete(id);

    res.status(200).json({
      success: true,
      message: 'ART Train deleted successfully. All operator assignments have been removed.',
    });
  } catch (error) {
    console.error('Delete train error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while deleting train.',
    });
  }
};

/**
 * Get Available Supervisors
 * GET /api/art-trains/available-supervisors
 * Returns supervisors in the division, annotated with assignment status
 */
const getAvailableSupervisors = async (req, res) => {
  try {
    const { division } = req.user;

    const supervisors = await User.find({
      role: 'supervisor',
      division,
      status: 'approved',
      isActive: true,
    }).select('-password');

    // Annotate with assignment info
    const annotated = await Promise.all(
      supervisors.map(async (sup) => {
        const assignedTrain = await ArtTrain.findOne({ supervisor_id: sup._id });
        return {
          ...sup.toObject(),
          isAssigned: !!assignedTrain,
          assignedTrainName: assignedTrain ? assignedTrain.name : null,
          assignedTrainId: assignedTrain ? assignedTrain._id : null,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: annotated.length,
      supervisors: annotated,
    });
  } catch (error) {
    console.error('Get available supervisors error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

/**
 * Swap Supervisor
 * PUT /api/art-trains/:id/swap-supervisor
 * Force-assigns a supervisor to this train, un-assigning them from their current train
 */
const swapSupervisor = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { id } = req.params;
    const { supervisor_id } = req.body;

    if (!supervisor_id) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: 'supervisor_id is required.',
      });
    }

    const train = await ArtTrain.findById(id).session(session);
    if (!train) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: 'ART Train not found.',
      });
    }

    if (train.division !== req.user.division) {
      await session.abortTransaction();
      return res.status(403).json({
        success: false,
        message: 'You can only manage trains in your division.',
      });
    }

    const supervisor = await User.findById(supervisor_id).session(session);
    if (!supervisor || supervisor.role !== 'supervisor') {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: 'Invalid supervisor.',
      });
    }

    // Unset the supervisor from any other train
    await ArtTrain.updateMany(
      { supervisor_id, _id: { $ne: id } },
      { $set: { supervisor_id: null } },
      { session }
    );

    // Assign to this train
    train.supervisor_id = supervisor_id;
    await train.save({ session });

    await session.commitTransaction();

    const populated = await ArtTrain.findById(train._id)
      .populate('supervisor_id', 'name email phone employee_id');

    res.status(200).json({
      success: true,
      message: `Supervisor ${supervisor.name} has been swapped to "${train.name}".`,
      train: populated,
    });
  } catch (error) {
    await session.abortTransaction();
    console.error('Swap supervisor error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error during supervisor swap.',
    });
  } finally {
    session.endSession();
  }
};

// --- Operator Assignment Endpoints ---

/**
 * List Operators in Train
 * GET /api/art-trains/:id/operators
 */
const listTrainOperators = async (req, res) => {
  try {
    const { id } = req.params;
    const train = await ArtTrain.findById(id);

    if (!train) {
      return res.status(404).json({ success: false, message: 'ART Train not found.' });
    }

    if (train.division !== req.user.division) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const assignments = await ArtTrainOperator.find({ art_train_id: id })
      .populate('operator_id', '-password')
      .sort({ assigned_at: -1 });

    const operators = assignments.map((a) => ({
      ...a.operator_id.toObject(),
      assigned_at: a.assigned_at,
      assignment_id: a._id,
    }));

    res.status(200).json({
      success: true,
      count: operators.length,
      operators,
    });
  } catch (error) {
    console.error('List train operators error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Add Operators to Train
 * POST /api/art-trains/:id/operators
 * Body: { operatorIds: [id1, id2, ...] }
 */
const addOperators = async (req, res) => {
  try {
    const { id } = req.params;
    const { operatorIds } = req.body;

    if (!operatorIds || !Array.isArray(operatorIds) || operatorIds.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Please provide an array of operator IDs.',
      });
    }

    const train = await ArtTrain.findById(id);
    if (!train) {
      return res.status(404).json({ success: false, message: 'ART Train not found.' });
    }

    if (train.division !== req.user.division) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    // Validate all operators exist, are approved, and belong to same division
    const operators = await User.find({
      _id: { $in: operatorIds },
      role: 'operator',
      status: 'approved',
      division: req.user.division,
    });

    if (operators.length !== operatorIds.length) {
      return res.status(400).json({
        success: false,
        message: 'Some operator IDs are invalid, not approved, or not in your division.',
      });
    }

    // Check if any are already assigned
    const existingAssignments = await ArtTrainOperator.find({
      operator_id: { $in: operatorIds },
    });

    if (existingAssignments.length > 0) {
      const assignedNames = await Promise.all(
        existingAssignments.map(async (a) => {
          const op = await User.findById(a.operator_id).select('name');
          return op ? op.name : 'Unknown';
        })
      );
      return res.status(400).json({
        success: false,
        message: `These operators are already assigned to a train: ${assignedNames.join(', ')}`,
      });
    }

    // Create assignments
    const assignments = operatorIds.map((opId) => ({
      art_train_id: id,
      operator_id: opId,
    }));

    await ArtTrainOperator.insertMany(assignments);

    res.status(201).json({
      success: true,
      message: `${operatorIds.length} operator(s) assigned to "${train.name}".`,
    });
  } catch (error) {
    console.error('Add operators error:', error.message);
    if (error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'One or more operators are already assigned to a train.',
      });
    }
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Reassign Operator to Another Train
 * PUT /api/art-trains/:id/operators/:opId/reassign
 * Body: { newTrainId }
 */
const reassignOperator = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { id, opId } = req.params;
    const { newTrainId } = req.body;

    if (!newTrainId) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: 'newTrainId is required.',
      });
    }

    // Verify current train
    const currentTrain = await ArtTrain.findById(id).session(session);
    if (!currentTrain || currentTrain.division !== req.user.division) {
      await session.abortTransaction();
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    // Verify new train
    const newTrain = await ArtTrain.findById(newTrainId).session(session);
    if (!newTrain || newTrain.division !== req.user.division) {
      await session.abortTransaction();
      return res.status(400).json({
        success: false,
        message: 'Destination train not found or not in your division.',
      });
    }

    // Update the assignment
    const assignment = await ArtTrainOperator.findOneAndUpdate(
      { art_train_id: id, operator_id: opId },
      { art_train_id: newTrainId, assigned_at: new Date() },
      { session, new: true }
    );

    if (!assignment) {
      await session.abortTransaction();
      return res.status(404).json({
        success: false,
        message: 'Operator assignment not found.',
      });
    }

    await session.commitTransaction();

    res.status(200).json({
      success: true,
      message: `Operator reassigned from "${currentTrain.name}" to "${newTrain.name}".`,
    });
  } catch (error) {
    await session.abortTransaction();
    console.error('Reassign operator error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  } finally {
    session.endSession();
  }
};

/**
 * Remove Operator from Train
 * DELETE /api/art-trains/:id/operators/:opId
 */
const removeOperator = async (req, res) => {
  try {
    const { id, opId } = req.params;

    const train = await ArtTrain.findById(id);
    if (!train || train.division !== req.user.division) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const result = await ArtTrainOperator.findOneAndDelete({
      art_train_id: id,
      operator_id: opId,
    });

    if (!result) {
      return res.status(404).json({
        success: false,
        message: 'Operator assignment not found.',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Operator removed from train.',
    });
  } catch (error) {
    console.error('Remove operator error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Available Operators
 * GET /api/art-trains/:id/available-operators
 * Returns approved operators in division not assigned to any train
 */
const getAvailableOperators = async (req, res) => {
  try {
    const { division } = req.user;

    // Get IDs of all assigned operators
    const assignedOps = await ArtTrainOperator.find().select('operator_id');
    const assignedIds = assignedOps.map((a) => a.operator_id);

    const availableOperators = await User.find({
      role: 'operator',
      status: 'approved',
      division,
      isActive: true,
      _id: { $nin: assignedIds },
    }).select('-password');

    res.status(200).json({
      success: true,
      count: availableOperators.length,
      operators: availableOperators,
    });
  } catch (error) {
    console.error('Get available operators error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Single ART Train
 * GET /api/art-trains/:id
 */
const getArtTrain = async (req, res) => {
  try {
    const train = await ArtTrain.findById(req.params.id)
      .populate('supervisor_id', 'name email phone employee_id');
      
    if (!train) {
      return res.status(404).json({ success: false, message: 'ART Train not found.' });
    }

    res.status(200).json({ success: true, train });
  } catch (error) {
    console.error('Get ART Train error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get ART Train Location
 * GET /api/art-trains/:id/location
 */
const getArtTrainLocation = async (req, res) => {
  try {
    const train = await ArtTrain.findById(req.params.id);
    if (!train) {
      return res.status(404).json({ success: false, message: 'ART Train not found.' });
    }

    // Since we don't have a live tracking device yet, we simulate live location
    // around its depot or simply return the depot coords
    const latitude = train.depot_lat || 20.5937;
    const longitude = train.depot_lng || 78.9629;
    const heading = Math.floor(Math.random() * 360);
    const speed = 60; // 60 km/h mock speed

    res.status(200).json({
      success: true,
      latitude,
      longitude,
      heading,
      speed,
      updated_at: new Date()
    });
  } catch (error) {
    console.error('Get ART Train location error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

module.exports = {
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
};
