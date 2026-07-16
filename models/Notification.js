const mongoose = require('mongoose');

/**
 * Notification Schema
 * Used for in-app notifications (operator registration approvals, etc.)
 */
const notificationSchema = new mongoose.Schema(
  {
    recipient_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Recipient is required'],
    },
    type: {
      type: String,
      enum: {
        values: [
          'operator_registration',
          'operator_approved',
          'operator_rejected',
          'incident_created',
          'incident_resolved',
        ],
        message: '{VALUE} is not a valid notification type',
      },
      required: [true, 'Notification type is required'],
    },
    reference_id: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    message: {
      type: String,
      required: [true, 'Message is required'],
      trim: true,
    },
    is_read: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true, // createdAt, updatedAt
  }
);

// Index for fast lookups by recipient and read status
notificationSchema.index({ recipient_id: 1, is_read: 1 });
notificationSchema.index({ recipient_id: 1, createdAt: -1 });

const Notification = mongoose.model('Notification', notificationSchema);

module.exports = Notification;
