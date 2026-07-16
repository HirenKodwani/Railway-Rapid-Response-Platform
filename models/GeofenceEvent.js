const mongoose = require('mongoose');

const geofenceEventSchema = new mongoose.Schema(
  {
    incident_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Incident',
      required: true,
    },
    operator_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    event_type: {
      type: String,
      enum: [
        'NOTIFICATION_DISPATCHED',
        'INCIDENT_ACCEPTED',
        'ART_ENTERED',
        'ART_EXITED',
        'ART_DWELL_CONFIRMED',
        'SITE_ENTERED',
        'SITE_EXITED',
      ],
      required: true,
    },
    lat: {
      type: Number,
      default: null,
    },
    lng: {
      type: Number,
      default: null,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      required: true,
    },
    device_accuracy_meters: {
      type: Number,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
geofenceEventSchema.index({ incident_id: 1, operator_id: 1, timestamp: 1 });

const GeofenceEvent = mongoose.model('GeofenceEvent', geofenceEventSchema);

module.exports = GeofenceEvent;
