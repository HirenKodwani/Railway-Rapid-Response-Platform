const mongoose = require('mongoose');

/**
 * ART Train Schema
 * Represents an ART (Accident Relief Train) managed by a Lead Supervisor
 * Each train belongs to a division and can have one supervisor assigned
 */
const artTrainSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Train name/number is required'],
      trim: true,
    },
    division: {
      type: String,
      required: [true, 'Division is required'],
      trim: true,
    },
    zone: {
      type: String,
      trim: true,
    },
    depot_lat: {
      type: Number,
    },
    depot_lng: {
      type: Number,
    },
    gps_device_id: {
      type: String,
      trim: true,
    },
    supervisor_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    zone_id: {
      type: String,
      trim: true,
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Creator is required'],
    },
  },
  {
    timestamps: true,
  }
);

// Index for fast lookups by division
artTrainSchema.index({ division: 1 });
artTrainSchema.index({ supervisor_id: 1 });

const ArtTrain = mongoose.model('ArtTrain', artTrainSchema);

module.exports = ArtTrain;
