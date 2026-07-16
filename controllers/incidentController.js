const Incident = require('../models/Incident');
const OperatorLocation = require('../models/OperatorLocation');
const ArtTrain = require('../models/ArtTrain');
const ArtTrainOperator = require('../models/ArtTrainOperator');
const User = require('../models/User');
const turf = require('@turf/turf');
const OperatorIncidentLog = require('../models/OperatorIncidentLog');
const GeofenceEvent = require('../models/GeofenceEvent');
const { evaluateARTGeofence, evaluateSiteGeofence } = require('../services/geofenceService');
const { sendPushNotification } = require('../config/firebase');
const axios = require('axios');

/**
 * Create Incident
 * POST /api/incidents
 * Supervisor only — creates a new incident, auto-populates operators from ART train
 */
const createIncident = async (req, res) => {
  try {
    const {
      train_number,
      latitude,
      longitude,
      incident_category,
      incident_subcategory,
      affected_component,
      severity,
      requiredSpecialisations,
      is_mock_drill,
    } = req.body;

    // Validate required fields
    if (!train_number || latitude == null || longitude == null ||
        !incident_category || !incident_subcategory || !affected_component || !severity ||
        !Array.isArray(requiredSpecialisations) || requiredSpecialisations.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'All fields are required: train_number, latitude, longitude, incident_category, incident_subcategory, affected_component, severity, and at least one requiredSpecialisations.',
      });
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ success: false, message: 'Invalid GPS coordinates.' });
    }

    // Check if supervisor already has an active incident
    const existingActive = await Incident.findOne({
      created_by: req.user._id,
      status: 'active',
    });
    if (existingActive) {
      return res.status(400).json({
        success: false,
        message: 'You already have an active incident. Please resolve it before creating a new one.',
      });
    }

    // Find the supervisor's assigned ART train
    const artTrain = await ArtTrain.findOne({ supervisor_id: req.user._id });

    // Get operators assigned to this ART train
    let alertedOperators = [];
    if (artTrain) {
      const assignments = await ArtTrainOperator.find({ art_train_id: artTrain._id }).populate('operator_id');
      
      for (const a of assignments) {
        if (!a.operator_id) continue;
        
        // Filter by specialisation
        // Operator gets alerted if their specialisation is in requiredSpecialisations array
        // Fallback: If operator has no specialisation, they are skipped unless explicitly handled, but
        // for safety if requiredSpecialisations contains all 9, it's fine. Wait, prompt says:
        // "filter: operator.specialisation must exist in requiredSpecialisations[]"
        if (a.operator_id.specialisation && requiredSpecialisations.includes(a.operator_id.specialisation)) {
          alertedOperators.push({
            operator_id: a.operator_id._id,
            response: 'pending',
          });
        }
      }
    }

    const crypto = require('crypto');
    const accessToken = crypto.randomBytes(16).toString('hex');

    const incident = await Incident.create({
      train_number: train_number.toString().trim(),
      latitude,
      longitude,
      incident_category,
      incident_subcategory: incident_subcategory.toString().trim(),
      affected_component,
      severity: Number(severity),
      requiredSpecialisations,
      is_mock_drill: is_mock_drill === true,
      status: 'active',
      created_by: req.user._id,
      art_train_id: artTrain ? artTrain._id : null,
      zone: req.user.zone || null,
      division: req.user.division || null,
      alerted_operators: alertedOperators,
      accessToken,
    });

    // Populate for response
    const populated = await Incident.findById(incident._id)
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone')
      .populate('alerted_operators.operator_id', 'name email phone employee_id fcmToken');

    // Emit socket event if io is available
    const io = req.app.get('io');
    if (io) {
      // Notify each operator's personal room
      for (const op of alertedOperators) {
        io.to(`user_${op.operator_id.toString()}`).emit('incident_alert', {
          incident: populated,
        });
      }
    }

    // Module 3.2.1 - Broadcast FCM Push Notification to all registered operator tokens immediately
    let notificationCount = 0;
    for (const op of populated.alerted_operators) {
      if (op.operator_id && op.operator_id.fcmToken) {
        const payload = {
          type: "INCIDENT_ALERT",
          incidentId: incident._id.toString(),
          trainNumber: incident.train_number,
          severity: incident.severity.toString(),
          category: incident.incident_category,
        };
        // Fire and forget, don't wait for all to finish before responding
        sendPushNotification(op.operator_id.fcmToken, payload).catch(err => {
          console.error(`Failed to send FCM to ${op.operator_id.name}:`, err.message);
        });
        notificationCount++;
      }
    }
    console.log(`[FCM] Sent real push notifications to ${notificationCount} operators for incident ${incident._id}`);

    // Module 4: Record dispatch in OperatorIncidentLog and GeofenceEvent
    const now = new Date();
    for (const op of alertedOperators) {
      await OperatorIncidentLog.create({
        incident_id: incident._id,
        operator_id: op.operator_id,
        notified_at: now,
        acceptance_status: 'PENDING',
      });

      await GeofenceEvent.create({
        incident_id: incident._id,
        operator_id: op.operator_id,
        event_type: 'NOTIFICATION_DISPATCHED',
        timestamp: now,
      });
    }

    res.status(201).json({
      success: true,
      message: 'Incident created successfully. Operators have been alerted.',
      incident: populated,
    });
  } catch (error) {
    console.error('Create incident error:', error.message);
    if (error.name === 'ValidationError') {
      const messages = Object.values(error.errors).map(e => e.message);
      return res.status(400).json({ success: false, message: messages.join(', ') });
    }
    res.status(500).json({ success: false, message: 'Internal server error while creating incident.' });
  }
};

/**
 * List Incidents
 * GET /api/incidents
 * Supervisor sees their created incidents; Operator sees incidents they were alerted for
 */
const listIncidents = async (req, res) => {
  try {
    let query = {};

    if (req.user.role === 'supervisor') {
      query = { created_by: req.user._id };
    } else if (req.user.role === 'operator') {
      query = { 'alerted_operators.operator_id': req.user._id };
    } else {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const incidents = await Incident.find(query)
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: incidents.length,
      incidents,
    });
  } catch (error) {
    console.error('List incidents error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Single Incident
 * GET /api/incidents/:id
 */
const getIncident = async (req, res) => {
  try {
    const incident = await Incident.findById(req.params.id)
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone depot_lat depot_lng')
      .populate('alerted_operators.operator_id', 'name email phone employee_id');

    if (!incident) {
      return res.status(404).json({ success: false, message: 'Incident not found.' });
    }

    res.status(200).json({ success: true, incident });
  } catch (error) {
    console.error('Get incident error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Active Incident
 * GET /api/incidents/active
 * Returns the currently active incident for the user (if any)
 */
const getActiveIncident = async (req, res) => {
  try {
    let query = {};

    if (req.user.role === 'supervisor') {
      query = { created_by: req.user._id, status: 'active' };
    } else if (req.user.role === 'operator') {
      query = { 'alerted_operators.operator_id': req.user._id, status: 'active' };
    } else {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const incident = await Incident.findOne(query)
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone depot_lat depot_lng')
      .populate('alerted_operators.operator_id', 'name email phone employee_id');

    res.status(200).json({
      success: true,
      incident: incident || null,
    });
  } catch (error) {
    console.error('Get active incident error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Resolve Incident
 * PUT /api/incidents/:id/resolve
 * Supervisor only — marks incident as resolved
 */
const resolveIncident = async (req, res) => {
  try {
    const incident = await Incident.findById(req.params.id);

    if (!incident) {
      return res.status(404).json({ success: false, message: 'Incident not found.' });
    }

    if (incident.created_by.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Only the creator can resolve this incident.' });
    }

    if (incident.status !== 'active') {
      return res.status(400).json({ success: false, message: 'Incident is not active.' });
    }

    incident.status = 'resolved';
    incident.resolved_at = new Date();
    await incident.save();

    // Clean up operator locations for this incident
    await OperatorLocation.deleteMany({ incident_id: incident._id });

    // Emit socket event
    const io = req.app.get('io');
    if (io) {
      for (const op of incident.alerted_operators) {
        io.to(`user_${op.operator_id.toString()}`).emit('incident_resolved', {
          incident_id: incident._id,
        });
      }
    }

    const populated = await Incident.findById(incident._id)
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone')
      .populate('alerted_operators.operator_id', 'name email phone employee_id');

    res.status(200).json({
      success: true,
      message: 'Incident resolved successfully.',
      incident: populated,
    });
  } catch (error) {
    console.error('Resolve incident error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Respond to Incident
 * PUT /api/incidents/:id/respond
 * Operator only — accept or decline with optional reason
 */
const respondToIncident = async (req, res) => {
  try {
    const { action, reason } = req.body;

    if (!action || !['accept', 'decline'].includes(action)) {
      return res.status(400).json({ success: false, message: 'Action must be "accept" or "decline".' });
    }

    if (action === 'decline' && (!reason || reason.trim().length === 0)) {
      return res.status(400).json({ success: false, message: 'A reason is required when declining.' });
    }

    const incident = await Incident.findById(req.params.id);

    if (!incident) {
      return res.status(404).json({ success: false, message: 'Incident not found.' });
    }

    if (incident.status !== 'active') {
      return res.status(400).json({ success: false, message: 'Incident is no longer active.' });
    }

    // Find this operator in the alerted list
    const opEntry = incident.alerted_operators.find(
      op => op.operator_id.toString() === req.user._id.toString()
    );

    if (!opEntry) {
      return res.status(403).json({ success: false, message: 'You are not alerted for this incident.' });
    }

    opEntry.response = action === 'accept' ? 'accepted' : 'declined';
    opEntry.decline_reason = action === 'decline' ? reason.trim() : null;
    opEntry.responded_at = new Date();

    await incident.save();

    // Notify supervisor via socket
    const io = req.app.get('io');
    if (io) {
      io.to(`user_${incident.created_by.toString()}`).emit('operator_response', {
        incident_id: incident._id,
        operator_id: req.user._id,
        operator_name: req.user.name,
        action: opEntry.response,
        reason: opEntry.decline_reason,
      });
    }

    if (action === 'accept') {
      const now = new Date();
      
      const log = await OperatorIncidentLog.findOneAndUpdate(
        { incident_id: incident._id, operator_id: req.user._id },
        { 
          accepted_at: now,
          acceptance_status: 'ACCEPTED'
        },
        { new: true, upsert: true }
      );

      await GeofenceEvent.create({
        incident_id: incident._id,
        operator_id: req.user._id,
        event_type: 'INCIDENT_ACCEPTED',
        timestamp: now,
      });

      if (io) {
        io.to(`incident_${incident._id.toString()}`).emit('operator_accepted', {
          incidentId: incident._id,
          operatorId: req.user._id,
          acceptedAt: now,
          notifiedAt: log.notified_at,
        });
      }
    } else if (action === 'decline') {
      await OperatorIncidentLog.findOneAndUpdate(
        { incident_id: incident._id, operator_id: req.user._id },
        { 
          acceptance_status: 'DECLINED'
        },
        { new: true, upsert: true }
      );
    }

    res.status(200).json({
      success: true,
      message: action === 'accept' ? 'Incident accepted. Please proceed to the ART train.' : 'Incident declined.',
    });
  } catch (error) {
    console.error('Respond to incident error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Post Operator Location
 * POST /api/incidents/:id/location
 * Operator posts their live GPS during active incident
 */
const postLocation = async (req, res) => {
  try {
    const { latitude, longitude } = req.body;

    if (latitude == null || longitude == null) {
      return res.status(400).json({ success: false, message: 'Latitude and longitude are required.' });
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return res.status(400).json({ success: false, message: 'Invalid GPS coordinates.' });
    }

    const incident = await Incident.findById(req.params.id);
    if (!incident || incident.status !== 'active') {
      return res.status(400).json({ success: false, message: 'No active incident found.' });
    }

    const timestamp = req.body.client_timestamp ? new Date(req.body.client_timestamp) : new Date();

    // Upsert operator location
    await OperatorLocation.findOneAndUpdate(
      { operator_id: req.user._id, incident_id: incident._id },
      {
        latitude,
        longitude,
        updated_at: timestamp,
      },
      { upsert: true, new: true }
    );

    // Emit via socket for real-time map updates
    const io = req.app.get('io');
    
    // Evaluate Geofences if required
    if (req.body.geofenceCheckRequired === true || req.body.geofenceCheckRequired === 'true') {
      await evaluateARTGeofence(req.user._id, incident._id, latitude, longitude, io, req.body.client_timestamp);
      await evaluateSiteGeofence(req.user._id, incident._id, latitude, longitude, io, req.body.client_timestamp);
    }

    const opLog = await OperatorIncidentLog.findOne({ incident_id: incident._id, operator_id: req.user._id });

    if (io) {
      io.to(`incident_${incident._id.toString()}`).emit('location_update', {
        operator_id: req.user._id,
        operator_name: req.user.name,
        latitude,
        longitude,
        updated_at: new Date(),
        attendanceStatus: opLog ? opLog.attendance_status : 'PENDING',
        responseStatus: opLog ? opLog.response_status : 'PENDING',
        acceptanceStatus: opLog ? opLog.acceptance_status : 'PENDING',
      });
    }

    res.status(200).json({ 
      success: true, 
      message: 'Location updated.',
      attendanceStatus: opLog ? opLog.attendance_status : 'PENDING',
      responseStatus: opLog ? opLog.response_status : 'PENDING',
      acceptanceStatus: opLog ? opLog.acceptance_status : 'PENDING',
    });
  } catch (error) {
    console.error('Post location error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Bulk Post Operator Locations
 * POST /api/incidents/:id/bulk-location
 * Operator syncs queued offline GPS locations
 */
const bulkPostLocation = async (req, res) => {
  try {
    const { locations } = req.body;
    if (!Array.isArray(locations) || locations.length === 0) {
      return res.status(400).json({ success: false, message: 'Locations array is required.' });
    }

    const incident = await Incident.findById(req.params.id);
    if (!incident || incident.status !== 'active') {
      return res.status(400).json({ success: false, message: 'No active incident found.' });
    }

    const io = req.app.get('io');
    
    // Process sequentially to simulate movement and geofence evaluation
    for (const loc of locations) {
       const timestamp = loc.client_timestamp ? new Date(loc.client_timestamp) : new Date();
       
       await OperatorLocation.findOneAndUpdate(
         { operator_id: req.user._id, incident_id: incident._id },
         { latitude: loc.latitude, longitude: loc.longitude, updated_at: timestamp },
         { upsert: true, new: true }
       );
       
       if (loc.geofenceCheckRequired === true || loc.geofenceCheckRequired === 1) {
         await evaluateARTGeofence(req.user._id, incident._id, loc.latitude, loc.longitude, io, timestamp);
         await evaluateSiteGeofence(req.user._id, incident._id, loc.latitude, loc.longitude, io, timestamp);
       }
    }

    // Get final status
    const opLog = await OperatorIncidentLog.findOne({ incident_id: incident._id, operator_id: req.user._id });
    const latestLoc = locations[locations.length - 1];

    if (io) {
      io.to(`incident_${incident._id.toString()}`).emit('location_update', {
        operator_id: req.user._id,
        operator_name: req.user.name,
        latitude: latestLoc.latitude,
        longitude: latestLoc.longitude,
        updated_at: new Date(),
        attendanceStatus: opLog ? opLog.attendance_status : 'PENDING',
        responseStatus: opLog ? opLog.response_status : 'PENDING',
        acceptanceStatus: opLog ? opLog.acceptance_status : 'PENDING',
      });
    }

    res.status(200).json({ 
      success: true, 
      message: 'Bulk locations updated.',
      attendanceStatus: opLog ? opLog.attendance_status : 'PENDING',
      responseStatus: opLog ? opLog.response_status : 'PENDING',
      acceptanceStatus: opLog ? opLog.acceptance_status : 'PENDING',
    });
  } catch (error) {
    console.error('Bulk post location error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Operator Locations for Incident
 * GET /api/incidents/:id/locations
 * Supervisor fetches all operator positions for map view
 */
const getOperatorLocations = async (req, res) => {
  try {
    const locations = await OperatorLocation.find({ incident_id: req.params.id })
      .populate('operator_id', 'name email phone employee_id');

    const logs = await OperatorIncidentLog.find({ incident_id: req.params.id });
    const logMap = {};
    for (const log of logs) {
      logMap[log.operator_id.toString()] = log;
    }

    res.status(200).json({
      success: true,
      count: locations.length,
      locations: locations.map(loc => {
        const opId = loc.operator_id?._id?.toString() || loc.operator_id?.toString();
        const opLog = logMap[opId];
        return {
          operator_id: loc.operator_id?._id || loc.operator_id,
          operator_name: loc.operator_id?.name || 'Unknown',
          operator_employee_id: loc.operator_id?.employee_id || '',
          latitude: loc.latitude,
          longitude: loc.longitude,
          updated_at: loc.updated_at,
          attendanceStatus: opLog ? opLog.attendance_status : 'PENDING',
          responseStatus: opLog ? opLog.response_status : 'PENDING',
          acceptanceStatus: opLog ? opLog.acceptance_status : 'PENDING',
        };
      }),
    });
  } catch (error) {
    console.error('Get operator locations error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get Pending Incidents for Operator
 * GET /api/incidents/pending-for-operator/:operatorId
 * Fetches active incidents where the operator was alerted but has not yet responded (pending)
 */
const getPendingIncidentsForOperator = async (req, res) => {
  try {
    const operatorId = req.params.operatorId;
    
    // Check if the requesting user is either the operator themselves or an admin
    if (req.user._id.toString() !== operatorId && req.user.role !== 'admin' && req.user.role !== 'master_admin') {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const incidents = await Incident.find({
      status: 'active',
      'alerted_operators': {
        $elemMatch: {
          operator_id: operatorId,
          response: 'pending'
        }
      }
    })
      .populate('created_by', 'name email phone employee_id')
      .populate('art_train_id', 'name division zone depot_lat depot_lng')
      .populate('alerted_operators.operator_id', 'name email phone employee_id');

    res.status(200).json({
      success: true,
      count: incidents.length,
      incidents,
    });
  } catch (error) {
    console.error('Get pending incidents error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

/**
 * Get ART Train ETA to Incident
 * GET /api/incidents/:id/art-eta
 * Computes exact rail track distance using BRouter API, falling back to Haversine with curve factor
 */
const getArtEta = async (req, res) => {
  try {
    const { artLat, artLng } = req.query;
    
    if (!artLat || !artLng) {
      return res.status(400).json({ success: false, message: 'artLat and artLng are required in query params.' });
    }

    const incident = await Incident.findById(req.params.id);
    if (!incident) {
      return res.status(404).json({ success: false, message: 'Incident not found.' });
    }

    const assumedSpeedKmh = 60;
    let distanceKm = 0;
    let routeGeoJSON = null;

    try {
      // BRouter expects: lonlats=lon,lat|lon,lat
      const brouterUrl = `https://brouter.de/brouter?lonlats=${artLng},${artLat}|${incident.longitude},${incident.latitude}&profile=rail&alternativeidx=0&format=geojson`;
      const response = await axios.get(brouterUrl, { timeout: 10000 });
      
      if (response.data && response.data.features && response.data.features.length > 0) {
        const feature = response.data.features[0];
        if (feature.properties && feature.properties['track-length']) {
          // track-length is in meters
          distanceKm = parseInt(feature.properties['track-length']) / 1000.0;
          routeGeoJSON = feature.geometry; // This is a LineString
        }
      }
    } catch (apiError) {
      console.warn('BRouter API failed or timed out. Falling back to Haversine:', apiError.message);
    }

    // Fallback if BRouter failed or returned no distance
    if (!distanceKm || distanceKm <= 0) {
      const from = turf.point([Number(artLng), Number(artLat)]);
      const to = turf.point([Number(incident.longitude), Number(incident.latitude)]);
      
      // Haversine distance in km
      const straightDistance = turf.distance(from, to, { units: 'kilometers' });
      
      // Add a curve factor (1.2x) to estimate rail network distance
      distanceKm = straightDistance * 1.2;
    }

    const etaMinutes = Math.ceil((distanceKm / assumedSpeedKmh) * 60);

    res.status(200).json({
      success: true,
      distanceKm,
      etaMinutes,
      assumedSpeedKmh,
      routeGeoJSON, // Will be null if fallback used
    });
  } catch (error) {
    console.error('Get ART ETA error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

const getAcceptanceLog = async (req, res) => {
  try {
    const logs = await OperatorIncidentLog.find({ incident_id: req.params.id })
      .populate('operator_id', 'name email phone employee_id');

    let totalDelay = 0;
    let acceptedCount = 0;

    const formattedLogs = logs.map(log => {
      let delayMinutes = null;
      if (log.acceptance_status === 'ACCEPTED' && log.accepted_at && log.notified_at) {
        delayMinutes = (log.accepted_at - log.notified_at) / (1000 * 60);
        totalDelay += delayMinutes;
        acceptedCount++;
      }

      return {
        operatorId: log.operator_id ? log.operator_id._id : null,
        operatorName: log.operator_id ? log.operator_id.name : 'Unknown',
        notifiedAt: log.notified_at,
        acceptedAt: log.accepted_at,
        acceptanceDelayMinutes: delayMinutes,
        acceptanceStatus: log.acceptance_status,
      };
    });

    const averageAcceptanceDelayMinutes = acceptedCount > 0 ? (totalDelay / acceptedCount) : null;

    res.status(200).json({
      success: true,
      logs: formattedLogs,
      averageAcceptanceDelayMinutes,
    });
  } catch (error) {
    console.error('getAcceptanceLog error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

const getAttendanceLog = async (req, res) => {
  try {
    const logs = await OperatorIncidentLog.find({ incident_id: req.params.id })
      .populate('operator_id', 'name');

    const formattedLogs = logs.map(log => {
      let timeToArtMinutes = null;
      if (log.art_dwell_confirmed_at && log.accepted_at) {
        timeToArtMinutes = (log.art_dwell_confirmed_at - log.accepted_at) / (1000 * 60);
      }

      return {
        operatorId: log.operator_id ? log.operator_id._id : null,
        operatorName: log.operator_id ? log.operator_id.name : 'Unknown',
        acceptedAt: log.accepted_at,
        artDwellConfirmedAt: log.art_dwell_confirmed_at,
        timeToArtMinutes,
        attendanceStatus: log.attendance_status,
      };
    });

    res.status(200).json({
      success: true,
      logs: formattedLogs,
    });
  } catch (error) {
    console.error('getAttendanceLog error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

const getResponseLog = async (req, res) => {
  try {
    const logs = await OperatorIncidentLog.find({ incident_id: req.params.id })
      .populate('operator_id', 'name');

    let totalDuration = 0;
    let reachedCount = 0;

    const formattedLogs = logs.map(log => {
      let responseDurationMinutes = null;
      if (log.response_status === 'REACHED' && log.site_geofence_entered_at && log.accepted_at) {
        responseDurationMinutes = (log.site_geofence_entered_at - log.accepted_at) / (1000 * 60);
        totalDuration += responseDurationMinutes;
        reachedCount++;
      }

      return {
        operatorId: log.operator_id ? log.operator_id._id : null,
        operatorName: log.operator_id ? log.operator_id.name : 'Unknown',
        acceptedAt: log.accepted_at,
        siteArrivedAt: log.site_geofence_entered_at,
        responseDurationMinutes,
        responseStatus: log.response_status,
      };
    });

    const averageResponseTimeMinutes = reachedCount > 0 ? (totalDuration / reachedCount) : null;

    res.status(200).json({
      success: true,
      logs: formattedLogs,
      averageResponseTimeMinutes,
    });
  } catch (error) {
    console.error('getResponseLog error:', error.message);
    res.status(500).json({ success: false, message: 'Internal server error.' });
  }
};

module.exports = {
  createIncident,
  listIncidents,
  getIncident,
  getActiveIncident,
  resolveIncident,
  respondToIncident,
  postLocation,
  bulkPostLocation,
  getOperatorLocations,
  getPendingIncidentsForOperator,
  getArtEta,
  getAcceptanceLog,
  getAttendanceLog,
  getResponseLog,
};
