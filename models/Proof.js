const mongoose = require('mongoose');

const proofSchema = new mongoose.Schema({
  incident_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Incident',
    required: true
  },
  operator_id: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  operator_name: {
    type: String,
    required: true
  },
  proof_type: {
    type: String,
    enum: ['IMAGE', 'VIDEO', 'AUDIO', 'TEXT'],
    required: true
  },
  url: {
    type: String,
    default: null
  },
  storage_ref: {
    type: String,
    default: null
  },
  text_content: {
    type: String,
    default: null
  },
  timestamp: {
    type: Date,
    required: true
  },
  geostamp: {
    lat: { type: Number },
    lng: { type: Number }
  },
  device_info: {
    model: { type: String },
    os: { type: String }
  },
  upload_id: {
    type: String,
    unique: true,
    sparse: true
  }
}, { timestamps: true });

module.exports = mongoose.model('Proof', proofSchema);
