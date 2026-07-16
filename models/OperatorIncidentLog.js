const mongoose = require('mongoose');

const operatorIncidentLogSchema = new mongoose.Schema(
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
    notified_at: {
      type: Date,
      default: null,
    },
    accepted_at: {
      type: Date,
      default: null,
    },
    art_geofence_entered_at: {
      type: Date,
      default: null,
    },
    art_dwell_confirmed_at: {
      type: Date,
      default: null,
    },
    art_geofence_exited_at: {
      type: Date,
      default: null,
    },
    site_geofence_entered_at: {
      type: Date,
      default: null,
    },
    attendance_status: {
      type: String,
      enum: ['PENDING', 'PRESENT', 'ABSENT'],
      default: 'PENDING',
    },
    response_status: {
      type: String,
      enum: ['PENDING', 'REACHED', 'NOT_REACHED'],
      default: 'PENDING',
    },
    acceptance_status: {
      type: String,
      enum: ['PENDING', 'ACCEPTED', 'NOT_RESPONDED'],
      default: 'PENDING',
    },
  },
  {
    timestamps: true,
  }
);

// Compound index for quick lookup of specific operator per incident
operatorIncidentLogSchema.index({ incident_id: 1, operator_id: 1 }, { unique: true });

const OperatorIncidentLog = mongoose.model('OperatorIncidentLog', operatorIncidentLogSchema);

module.exports = OperatorIncidentLog;
