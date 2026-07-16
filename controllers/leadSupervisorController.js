const User = require('../models/User');
const Notification = require('../models/Notification');
const Incident = require('../models/Incident');
const OperatorIncidentLog = require('../models/OperatorIncidentLog');
const ArtTrain = require('../models/ArtTrain');

/**
 * Get Pending Operators
 * GET /api/lead-supervisor/pending-operators
 * Returns operators with status 'pending' in the lead supervisor's division
 */
const getPendingOperators = async (req, res) => {
  try {
    const { division } = req.user;

    if (!division) {
      return res.status(400).json({
        success: false,
        message: 'Your account does not have a division assigned.',
      });
    }

    const pendingOperators = await User.find({
      role: 'operator',
      status: 'pending',
      division: division,
    })
      .select('-password')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: pendingOperators.length,
      operators: pendingOperators,
    });
  } catch (error) {
    console.error('Get pending operators error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching pending operators.',
    });
  }
};

/**
 * Approve Operator
 * PUT /api/lead-supervisor/approve-operator/:id
 * Sets operator status to 'approved'
 */
const approveOperator = async (req, res) => {
  try {
    const { id } = req.params;
    const operator = await User.findById(id);

    if (!operator) {
      return res.status(404).json({
        success: false,
        message: 'Operator not found.',
      });
    }

    // Verify same division
    if (operator.division !== req.user.division) {
      return res.status(403).json({
        success: false,
        message: 'You can only approve operators in your division.',
      });
    }

    if (operator.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: `Operator status is already '${operator.status}'.`,
      });
    }

    operator.status = 'approved';
    operator.createdBy = req.user._id; // Attach operator to this Lead Supervisor's hierarchy
    await operator.save();

    // Create notification for the operator
    await Notification.create({
      recipient_id: operator._id,
      type: 'operator_approved',
      reference_id: req.user._id,
      message: `Your registration has been approved by ${req.user.name}. You can now log in.`,
    });

    res.status(200).json({
      success: true,
      message: `Operator ${operator.name} has been approved.`,
      operator: {
        id: operator._id,
        name: operator.name,
        email: operator.email,
        status: operator.status,
      },
    });
  } catch (error) {
    console.error('Approve operator error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while approving operator.',
    });
  }
};

/**
 * Reject Operator
 * PUT /api/lead-supervisor/reject-operator/:id
 * Sets operator status to 'rejected' with optional reason
 */
const rejectOperator = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;
    const operator = await User.findById(id);

    if (!operator) {
      return res.status(404).json({
        success: false,
        message: 'Operator not found.',
      });
    }

    // Verify same division
    if (operator.division !== req.user.division) {
      return res.status(403).json({
        success: false,
        message: 'You can only reject operators in your division.',
      });
    }

    if (operator.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: `Operator status is already '${operator.status}'.`,
      });
    }

    operator.status = 'rejected';
    operator.rejectionReason = reason || undefined;
    await operator.save();

    // Create notification for the operator
    await Notification.create({
      recipient_id: operator._id,
      type: 'operator_rejected',
      reference_id: req.user._id,
      message: reason
        ? `Your registration has been rejected by ${req.user.name}. Reason: ${reason}`
        : `Your registration has been rejected by ${req.user.name}.`,
    });

    res.status(200).json({
      success: true,
      message: `Operator ${operator.name} has been rejected.`,
      operator: {
        id: operator._id,
        name: operator.name,
        email: operator.email,
        status: operator.status,
      },
    });
  } catch (error) {
    console.error('Reject operator error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while rejecting operator.',
    });
  }
};

/**
 * Get Notifications
 * GET /api/lead-supervisor/notifications
 * Returns all notifications for the logged-in lead supervisor
 */
const getNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({
      recipient_id: req.user._id,
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate('reference_id', 'name email employee_id role');

    res.status(200).json({
      success: true,
      count: notifications.length,
      notifications,
    });
  } catch (error) {
    console.error('Get notifications error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching notifications.',
    });
  }
};

/**
 * Mark Notification as Read
 * PUT /api/lead-supervisor/notifications/:id/read
 */
const markNotificationRead = async (req, res) => {
  try {
    const { id } = req.params;
    const notification = await Notification.findById(id);

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found.',
      });
    }

    if (notification.recipient_id.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'You can only mark your own notifications as read.',
      });
    }

    notification.is_read = true;
    await notification.save();

    res.status(200).json({
      success: true,
      message: 'Notification marked as read.',
    });
  } catch (error) {
    console.error('Mark notification read error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

/**
 * Get Unread Notification Count
 * GET /api/lead-supervisor/notifications/unread-count
 * Returns the count of unread notifications (for badge display)
 */
const getUnreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      recipient_id: req.user._id,
      is_read: false,
    });

    res.status(200).json({
      success: true,
      count,
    });
  } catch (error) {
    console.error('Get unread count error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error.',
    });
  }
};

/**
 * Get Reports for Lead Supervisor
 * GET /api/lead-supervisor/reports
 * Returns all incidents in the LS's division, grouped by supervisor
 * Supports query params: status, category, severity, fromDate, toDate, search, isMockDrill
 */
const getReportsForLeadSupervisor = async (req, res) => {
  try {
    let targetDivision = req.user.division;

    if (['super_admin', 'master_admin'].includes(req.user.role)) {
      targetDivision = req.query.division || req.user.division;
    }

    if (!targetDivision) {
      return res.status(400).json({
        success: false,
        message: 'Division is required to fetch reports.',
      });
    }

    // 1. Find all supervisors in this division
    let supervisorQuery = {
      role: 'supervisor',
      division: targetDivision,
      status: 'approved',
    };

    // If search param provided, filter supervisors by name or assigned ART train name
    const { search, status, category, severity, fromDate, toDate, isMockDrill } = req.query;
    if (search && search.trim()) {
      const searchTerm = search.trim();
      
      // Find ART Trains matching the search term
      const matchingTrains = await ArtTrain.find({ name: { $regex: searchTerm, $options: 'i' } });
      const trainSupervisorIds = matchingTrains.map(t => t.supervisor_id).filter(id => id);

      supervisorQuery.$or = [
        { name: { $regex: searchTerm, $options: 'i' } },
        { _id: { $in: trainSupervisorIds } }
      ];
    }

    const supervisors = await User.find(supervisorQuery)
      .select('name email employee_id phone')
      .sort({ name: 1 });

    if (supervisors.length === 0) {
      return res.status(200).json({
        success: true,
        supervisors: [],
        summary: { totalIncidents: 0, active: 0, resolved: 0, cancelled: 0 },
      });
    }

    const supervisorIds = supervisors.map(s => s._id);

    // 2. Build incident query
    let incidentQuery = { created_by: { $in: supervisorIds } };

    if (status && ['active', 'resolved', 'cancelled'].includes(status)) {
      incidentQuery.status = status;
    }
    if (category) {
      incidentQuery.incident_category = category;
    }
    if (severity) {
      incidentQuery.severity = Number(severity);
    }
    if (isMockDrill === 'true') {
      incidentQuery.is_mock_drill = true;
    } else if (isMockDrill === 'false') {
      incidentQuery.is_mock_drill = false;
    }
    if (fromDate || toDate) {
      incidentQuery.createdAt = {};
      if (fromDate) incidentQuery.createdAt.$gte = new Date(fromDate);
      if (toDate) {
        const end = new Date(toDate);
        end.setHours(23, 59, 59, 999);
        incidentQuery.createdAt.$lte = end;
      }
    }

    // 3. Fetch all incidents matching filters
    const incidents = await Incident.find(incidentQuery)
      .populate('created_by', 'name email employee_id')
      .populate('art_train_id', 'name division zone')
      .select('-reportBuffer')
      .sort({ createdAt: -1 });

    // 4. Compute average response time per supervisor from OperatorIncidentLog
    const allIncidentIds = incidents.map(i => i._id);
    const allLogs = await OperatorIncidentLog.find({ incident_id: { $in: allIncidentIds } });

    // Build a map: incidentId -> logs
    const logsByIncident = {};
    for (const log of allLogs) {
      const iid = log.incident_id.toString();
      if (!logsByIncident[iid]) logsByIncident[iid] = [];
      logsByIncident[iid].push(log);
    }

    // 5. Group incidents by supervisor
    const supervisorMap = {};
    for (const sup of supervisors) {
      supervisorMap[sup._id.toString()] = {
        id: sup._id,
        name: sup.name,
        email: sup.email,
        employeeId: sup.employee_id,
        phone: sup.phone,
        incidents: [],
        totalIncidents: 0,
        active: 0,
        resolved: 0,
        cancelled: 0,
        avgResponseTimeMinutes: null,
        artTrain: null,
      };
    }

    // Fetch ART Trains for these supervisors
    const artTrains = await ArtTrain.find({ supervisor_id: { $in: supervisorIds } });
    for (const train of artTrains) {
      if (supervisorMap[train.supervisor_id.toString()]) {
        supervisorMap[train.supervisor_id.toString()].artTrain = {
          id: train._id,
          name: train.name,
          division: train.division
        };
      }
    }

    let globalTotal = 0, globalActive = 0, globalResolved = 0, globalCancelled = 0;

    for (const incident of incidents) {
      const supId = incident.created_by?._id?.toString() || incident.created_by?.toString();
      if (supervisorMap[supId]) {
        supervisorMap[supId].incidents.push(incident);
        supervisorMap[supId].totalIncidents++;
        if (incident.status === 'active') supervisorMap[supId].active++;
        else if (incident.status === 'resolved') supervisorMap[supId].resolved++;
        else if (incident.status === 'cancelled') supervisorMap[supId].cancelled++;

        globalTotal++;
        if (incident.status === 'active') globalActive++;
        else if (incident.status === 'resolved') globalResolved++;
        else if (incident.status === 'cancelled') globalCancelled++;
      }
    }

    // 6. Compute avg response time per supervisor
    for (const supId of Object.keys(supervisorMap)) {
      const supIncidents = supervisorMap[supId].incidents;
      let totalResponseTime = 0;
      let responseCount = 0;

      for (const inc of supIncidents) {
        const logs = logsByIncident[inc._id.toString()] || [];
        for (const log of logs) {
          if (log.response_status === 'REACHED' && log.site_geofence_entered_at && log.accepted_at) {
            const dur = (log.site_geofence_entered_at - log.accepted_at) / (1000 * 60);
            totalResponseTime += dur;
            responseCount++;
          }
        }
      }

      supervisorMap[supId].avgResponseTimeMinutes = responseCount > 0 ? (totalResponseTime / responseCount) : null;
    }

    // 7. Convert map to sorted array (by totalIncidents desc)
    const supervisorList = Object.values(supervisorMap)
      .sort((a, b) => b.totalIncidents - a.totalIncidents);

    res.status(200).json({
      success: true,
      supervisors: supervisorList,
      summary: {
        totalIncidents: globalTotal,
        active: globalActive,
        resolved: globalResolved,
        cancelled: globalCancelled,
      },
    });
  } catch (error) {
    console.error('Get reports for lead supervisor error:', error.message);
    res.status(500).json({
      success: false,
      message: 'Internal server error while fetching reports.',
    });
  }
};

module.exports = {
  getPendingOperators,
  approveOperator,
  rejectOperator,
  getNotifications,
  markNotificationRead,
  getUnreadCount,
  getReportsForLeadSupervisor,
};
