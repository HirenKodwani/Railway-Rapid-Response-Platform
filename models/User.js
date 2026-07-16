const mongoose = require('mongoose');
const { SPECIALISATION_IDS } = require('../constants/specialisations');

/**
 * User Schema for Indian Railways RRS
 * Supports 6-level role hierarchy: master_admin > super_admin > admin > lead_supervisor > supervisor > operator
 */
const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
    },
    phone: {
      type: String,
      required: [true, 'Phone number is required'],
      unique: true,
      trim: true,
      validate: {
        validator: function (v) {
          return /^[6-9]\d{9}$/.test(v);
        },
        message: 'Phone must be exactly 10 digits starting with 6-9',
      },
    },
    role: {
      type: String,
      enum: {
        values: [
          'master_admin',
          'super_admin',
          'admin',
          'lead_supervisor',
          'supervisor',
          'operator',
        ],
        message: '{VALUE} is not a valid role',
      },
      required: [true, 'Role is required'],
    },
    specialisation: {
      type: String,
      enum: {
        values: [...SPECIALISATION_IDS, null],
        message: '{VALUE} is not a valid specialisation'
      },
      default: null,
    },
    employee_id: {
      type: String,
      required: [true, 'Employee ID is required'],
      unique: true,
      trim: true,
    },
    zone: {
      type: String,
      trim: true,
    },
    division: {
      type: String,
      trim: true,
    },
    city: {
      type: String,
      trim: true,
    },
    lat: {
      type: Number,
    },
    lng: {
      type: Number,
    },
    address: {
      type: String,
      trim: true,
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    status: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'rejected'],
        message: '{VALUE} is not a valid status',
      },
      default: 'approved',
    },
    rejectionReason: {
      type: String,
      trim: true,
    },
    fcmToken: {
      type: String,
      trim: true,
      default: null,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt automatically
  }
);

// Index for faster lookups on login
userSchema.index({ email: 1 });
userSchema.index({ phone: 1 });
userSchema.index({ createdBy: 1 });
userSchema.index({ division: 1, status: 1 });

const User = mongoose.model('User', userSchema);

module.exports = User;
