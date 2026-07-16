const mongoose = require('mongoose');

/**
 * Operator Location Schema
 * Stores the latest GPS coordinates of an operator during an active incident.
 * Only one record per operator — upserted on each location update.
 */
const operatorLocationSchema = new mongoose.Schema(
  {
    operator_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Operator is required'],
    },
    incident_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Incident',
      required: [true, 'Incident is required'],
    },
    latitude: {
      type: Number,
      required: [true, 'Latitude is required'],
    },
    longitude: {
      type: Number,
      required: [true, 'Longitude is required'],
    },
    updated_at: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// One location record per operator per incident
operatorLocationSchema.index({ operator_id: 1, incident_id: 1 }, { unique: true });
// Fast lookup by incident (for supervisor map view)
operatorLocationSchema.index({ incident_id: 1 });

const OperatorLocation = mongoose.model('OperatorLocation', operatorLocationSchema);

module.exports = OperatorLocation;
