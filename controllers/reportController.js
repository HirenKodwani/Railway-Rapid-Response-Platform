const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const cloudinary = require('cloudinary').v2;
const streamifier = require('streamifier');
const Incident = require('../models/Incident');
const OperatorIncidentLog = require('../models/OperatorIncidentLog');
const Proof = require('../models/Proof');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { generatePDF } = require('../utils/pdfGenerator');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});

const generateReport = async (req, res) => {
  try {
    const { id } = req.params;
    
    const incident = await Incident.findById(id).populate('created_by', 'name employee_id');
    if (!incident) {
      return res.status(404).json({ success: false, message: 'Incident not found' });
    }

    if (incident.status !== 'resolved') {
      return res.status(400).json({ success: false, message: 'Report can only be generated for resolved incidents' });
    }

    if (incident.reportUrl) {
      return res.status(200).json({ success: true, reportUrl: incident.reportUrl });
    }

    // Fetch Logs
    const logs = await OperatorIncidentLog.find({ incident_id: incident._id }).populate('operator_id', 'name');
    const proofs = await Proof.find({ incident_id: incident._id }).lean();

    const pdfBuffer = await generatePDF(incident, logs, proofs);

    // Save PDF directly to MongoDB
    const backendUrl = `https://r2p-aj2e.onrender.com/api/incidents/${incident._id}/download-report`;
    
    incident.reportUrl = backendUrl;
    incident.reportBuffer = pdfBuffer;
    incident.reportGeneratedAt = new Date();
    await incident.save();

    // Emit socket event
    const io = req.app.get('io');
    if (io) {
      io.to(`incident_${incident._id.toString()}`).emit('report:ready', {
        incidentId: incident._id,
        reportUrl: backendUrl,
      });
    }

    res.status(200).json({ success: true, reportUrl: backendUrl });

  } catch (error) {
    console.error('Error generating PDF report:', error);
    res.status(500).json({ success: false, message: 'Internal server error while generating report' });
  }
};

const downloadReport = async (req, res) => {
  try {
    const { id } = req.params;
    const incident = await Incident.findById(id).select('reportBuffer train_number');
    
    if (!incident || !incident.reportBuffer) {
      return res.status(404).json({ success: false, message: 'Report not found' });
    }

    res.set({
      'Content-Type': 'application/pdf',
      'Content-Disposition': `inline; filename="Incident_Report_${incident.train_number}.pdf"`
    });
    
    res.send(incident.reportBuffer);
  } catch (error) {
    console.error('Error downloading report:', error);
    res.status(500).json({ success: false, message: 'Server error downloading report' });
  }
};

const { v4: uuidv4 } = require('uuid');

const uploadProof = async (req, res) => {
  try {
    const { id } = req.params;
    const { proofType, textContent, timestamp, geostamp, deviceInfo, uploadId } = req.body;
    
    if (!req.user || !req.user.id) {
      return res.status(401).json({ success: false, message: 'Unauthorized' });
    }

    if (uploadId) {
      const existingProof = await Proof.findOne({ upload_id: uploadId });
      if (existingProof) {
        return res.status(200).json({ success: true, proof: existingProof, message: 'Proof already uploaded.' });
      }
    }

    const uuid = uuidv4();
    let downloadUrl = null;
    let storageRefPath = null;

    if (req.file) {
      const mime = req.file.mimetype;
      // MIME type checks removed to allow Flutter to upload various formats like .m4a smoothly

      let resourceType = 'auto';
      if (proofType === 'VIDEO' || proofType === 'AUDIO') {
        resourceType = 'video'; // Cloudinary treats audio as video
      } else if (proofType === 'IMAGE') {
        resourceType = 'image';
      }

      downloadUrl = await new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
          {
            folder: `RapidResponse/incidents/${id}/proofs/${req.user.id}`,
            resource_type: resourceType,
          },
          (error, result) => {
            if (error) return reject(error);
            storageRefPath = result.public_id; // Store Cloudinary public_id for future use
            resolve(result.secure_url);
          }
        );
        streamifier.createReadStream(req.file.buffer).pipe(uploadStream);
      });
    }

    let parsedGeostamp = geostamp;
    let parsedDeviceInfo = deviceInfo;
    if (typeof geostamp === 'string') parsedGeostamp = JSON.parse(geostamp);
    if (typeof deviceInfo === 'string') parsedDeviceInfo = JSON.parse(deviceInfo);

    const proofData = await Proof.create({
      incident_id: id,
      operator_id: req.user.id,
      operator_name: req.user.name || 'Operator',
      proof_type: proofType,
      url: downloadUrl,
      storage_ref: storageRefPath,
      text_content: textContent || null,
      timestamp,
      geostamp: parsedGeostamp,
      device_info: parsedDeviceInfo,
      upload_id: uploadId || null,
    });

    res.status(200).json({ success: true, proof: proofData });
  } catch (error) {
    console.error('Error uploading proof:', error);
    res.status(500).json({ success: false, message: 'Failed to upload proof' });
  }
};

const getProofs = async (req, res) => {
  try {
    const { id } = req.params;
    const proofs = await Proof.find({ incident_id: id }).sort({ timestamp: -1 }).lean();
    res.status(200).json({ success: true, proofs });
  } catch (error) {
    console.error('Error fetching proofs:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
};

module.exports = { generateReport, downloadReport, uploadProof, getProofs };
