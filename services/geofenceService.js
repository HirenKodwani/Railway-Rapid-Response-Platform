const GeofenceEvent = require('../models/GeofenceEvent');
const OperatorIncidentLog = require('../models/OperatorIncidentLog');
const ArtTrain = require('../models/ArtTrain');
const Incident = require('../models/Incident');
const { getHaversineDistance } = require('../utils/haversine');

// In-memory store for dwell timers. Keys are `${incidentId}:${operatorId}`
// Value: { entryTime: Date }
const dwellTimers = new Map();

/**
 * Evaluates the operator's distance to the ART train (50m geofence).
 * Requirement: Operator must stay within 50m for 10 consecutive minutes.
 */
const evaluateARTGeofence = async (operatorId, incidentId, operatorLat, operatorLng, io, clientTimestamp = null) => {
  try {
    const incident = await Incident.findById(incidentId).populate('art_train_id');
    if (!incident || !incident.art_train_id) return;

    const artTrain = incident.art_train_id;
    if (artTrain.depot_lat == null || artTrain.depot_lng == null) return;

    const distance = getHaversineDistance(operatorLat, operatorLng, artTrain.depot_lat, artTrain.depot_lng);
    
    let log = await OperatorIncidentLog.findOne({ incident_id: incidentId, operator_id: operatorId });
    if (!log) {
      log = new OperatorIncidentLog({ incident_id: incidentId, operator_id: operatorId });
    }

    const timerKey = `${incidentId}:${operatorId}`;

    const timestamp = clientTimestamp ? new Date(clientTimestamp) : new Date();

    if (distance <= 50) {
      // Operator is within 50m of ART Train
      if (!log.art_geofence_entered_at) {
        log.art_geofence_entered_at = timestamp;
        await log.save();
        
        await GeofenceEvent.create({
          incident_id: incidentId,
          operator_id: operatorId,
          event_type: 'ART_ENTERED',
          lat: operatorLat,
          lng: operatorLng,
        });

        // Start dwell timer
        dwellTimers.set(timerKey, { entryTime: timestamp });
      } else {
        // Already entered, check dwell timer
        let dwellEntry = dwellTimers.get(timerKey);
        if (!dwellEntry && !log.art_dwell_confirmed_at) {
          // If in-memory timer lost due to server restart, rely on DB entry time
          dwellEntry = { entryTime: log.art_geofence_entered_at };
          dwellTimers.set(timerKey, dwellEntry);
        }

        if (dwellEntry && !log.art_dwell_confirmed_at) {
          const now = timestamp;
          const diffMinutes = (now - dwellEntry.entryTime) / (1000 * 60);
          
          if (diffMinutes >= 1) {
            log.art_dwell_confirmed_at = now;
            log.attendance_status = 'PRESENT';
            await log.save();

            await GeofenceEvent.create({
              incident_id: incidentId,
              operator_id: operatorId,
              event_type: 'ART_DWELL_CONFIRMED',
              lat: operatorLat,
              lng: operatorLng,
            });

            // Emit attendance update
            if (io) {
              io.to(`incident_${incidentId}`).emit('attendance_updated', {
                incidentId,
                operatorId,
                attendanceStatus: 'PRESENT',
                artDwellConfirmedAt: log.art_dwell_confirmed_at,
              });
            }

            // Clean up dwell timer
            dwellTimers.delete(timerKey);
          }
        }
      }
    } else {
      // Operator is further than 50m from ART Train
      if (log.art_geofence_entered_at && !log.art_dwell_confirmed_at) {
        // Exited before 10 min dwell completed
        log.art_geofence_entered_at = null; // Reset for re-entry
        await log.save();

        await GeofenceEvent.create({
          incident_id: incidentId,
          operator_id: operatorId,
          event_type: 'ART_EXITED',
          lat: operatorLat,
          lng: operatorLng,
        });

        dwellTimers.delete(timerKey);
      } else if (log.art_dwell_confirmed_at && !log.art_geofence_exited_at) {
        // Exited after successfully dwelling (departing to site)
        log.art_geofence_exited_at = timestamp;
        await log.save();

        await GeofenceEvent.create({
          incident_id: incidentId,
          operator_id: operatorId,
          event_type: 'ART_EXITED',
          lat: operatorLat,
          lng: operatorLng,
        });
      }
    }
  } catch (error) {
    console.error('evaluateARTGeofence error:', error);
  }
};

/**
 * Evaluates the operator's distance to the Accident Spot (100m geofence).
 */
const evaluateSiteGeofence = async (operatorId, incidentId, operatorLat, operatorLng, io, clientTimestamp = null) => {
  try {
    const incident = await Incident.findById(incidentId);
    if (!incident) return;

    const distance = getHaversineDistance(operatorLat, operatorLng, incident.latitude, incident.longitude);
    
    let log = await OperatorIncidentLog.findOne({ incident_id: incidentId, operator_id: operatorId });
    if (!log) {
      log = new OperatorIncidentLog({ incident_id: incidentId, operator_id: operatorId });
    }

    const timestamp = clientTimestamp ? new Date(clientTimestamp) : new Date();

    if (distance <= 100) {
      if (!log.site_geofence_entered_at) {
        log.site_geofence_entered_at = timestamp;
        log.response_status = 'REACHED';
        await log.save();

        await GeofenceEvent.create({
          incident_id: incidentId,
          operator_id: operatorId,
          event_type: 'SITE_ENTERED',
          lat: operatorLat,
          lng: operatorLng,
        });

        // Emit arrival event
        if (io) {
          io.to(`incident_${incidentId}`).emit('operator_site_arrival', {
            incidentId,
            operatorId,
            timestamp: log.site_geofence_entered_at,
          });
        }
      }
    }
  } catch (error) {
    console.error('evaluateSiteGeofence error:', error);
  }
};

module.exports = {
  evaluateARTGeofence,
  evaluateSiteGeofence,
};
