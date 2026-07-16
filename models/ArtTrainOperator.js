const mongoose = require('mongoose');

/**
 * ART Train Operator Join Table
 * Links operators to their assigned ART trains
 * An operator can only be assigned to one train at a time (enforced by unique index on operator_id)
 */
const artTrainOperatorSchema = new mongoose.Schema(
  {
    art_train_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ArtTrain',
      required: [true, 'ART Train is required'],
    },
    operator_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Operator is required'],
    },
    assigned_at: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// Unique constraint: one operator can only be in one train
artTrainOperatorSchema.index({ operator_id: 1 }, { unique: true });
// Fast lookup by train
artTrainOperatorSchema.index({ art_train_id: 1 });

const ArtTrainOperator = mongoose.model('ArtTrainOperator', artTrainOperatorSchema);

module.exports = ArtTrainOperator;
