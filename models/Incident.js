const mongoose = require('mongoose');

/**
 * Incident Schema
 * Represents a rapid-response incident created by a Supervisor
 * Tracks the full lifecycle: creation → operator alerts → responses → resolution
 */
const incidentSchema = new mongoose.Schema(
  {
    train_number: {
      type: String,
      required: [true, 'Train number is required'],
      trim: true,
    },
    latitude: {
      type: Number,
      required: [true, 'Latitude is required'],
    },
    longitude: {
      type: Number,
      required: [true, 'Longitude is required'],
    },
    incident_category: {
      type: String,
      enum: {
        values: [
          'Accident',
          'Infrastructure Failure',
          'Natural Disaster',
          'Security Incident',
          'Passenger Emergency',
          'Operational Incident',
          'Hazardous Material',
        ],
        message: '{VALUE} is not a valid incident category',
      },
      required: [true, 'Incident category is required'],
    },
    incident_subcategory: {
      type: String,
      required: [true, 'Incident sub-category is required'],
      trim: true,
    },
    affected_component: {
      type: String,
      enum: {
        values: [
          'Entire Train',
          'Multiple Coaches',
          'Front Section of Train',
          'Rear Section of Train',
          'Middle Section of Train',
        ],
        message: '{VALUE} is not a valid affected component',
      },
      required: [true, 'Affected component is required'],
    },
    severity: {
      type: Number,
      min: 1,
      max: 6,
      required: [true, 'Severity level is required'],
    },
    requiredSpecialisations: {
      type: [String],
      default: [],
    },
    is_mock_drill: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: {
        values: ['active', 'resolved', 'cancelled'],
        message: '{VALUE} is not a valid status',
      },
      default: 'active',
    },
    created_by: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Creator (Supervisor) is required'],
    },
    art_train_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'ArtTrain',
      default: null,
    },
    zone: {
      type: String,
      trim: true,
    },
    division: {
      type: String,
      trim: true,
    },
    alerted_operators: [
      {
        operator_id: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'User',
        },
        response: {
          type: String,
          enum: ['pending', 'accepted', 'declined'],
          default: 'pending',
        },
        decline_reason: {
          type: String,
          trim: true,
          default: null,
        },
        responded_at: {
          type: Date,
          default: null,
        },
      },
    ],
    resolved_at: {
      type: Date,
      default: null,
    },
    reportUrl: {
      type: String,
      default: null,
    },
    reportBuffer: {
      type: Buffer,
      default: null,
    },
    reportGeneratedAt: {
      type: Date,
      default: null,
    },
    accessToken: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for fast lookups
incidentSchema.index({ created_by: 1, status: 1 });
incidentSchema.index({ status: 1 });
incidentSchema.index({ art_train_id: 1 });
incidentSchema.index({ 'alerted_operators.operator_id': 1, status: 1 });

const Incident = mongoose.model('Incident', incidentSchema);

module.exports = Incident;
