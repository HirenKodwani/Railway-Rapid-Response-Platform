const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const loadEnv = require('./config/env');
const connectDB = require('./config/db');
const { initFirebase } = require('./config/firebase');
const seedMasterAdmin = require('./utils/seedMasterAdmin');

// Load environment variables first
loadEnv();

// Initialize Firebase Admin
initFirebase();

// Import routes
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const leadSupervisorRoutes = require('./routes/leadSupervisorRoutes');
const artTrainRoutes = require('./routes/artTrainRoutes');
const supervisorRoutes = require('./routes/supervisorRoutes');
const operatorRoutes = require('./routes/operatorRoutes');
const incidentRoutes = require('./routes/incidentRoutes');
const navigationRoutes = require('./routes/navigationRoutes');
const proofRoutes = require('./routes/proofRoutes');

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Initialize Socket.io
const io = new Server(server, {
    cors: {
        origin: '*',
        methods: ['GET', 'POST'],
    },
});

// Make io accessible in controllers via req.app.get('io')
app.set('io', io);

// Socket.io connection handling
io.on('connection', (socket) => {
    console.log(`🔌 Socket connected: ${socket.id}`);

    // User joins their personal room for targeted notifications
    socket.on('join_user', (userId) => {
        socket.join(`user_${userId}`);
        console.log(`   User ${userId} joined personal room`);
    });

    // Supervisor joins an incident room to receive operator location updates
    socket.on('join_incident', (incidentId) => {
        socket.join(`incident_${incidentId}`);
        console.log(`   Joined incident room: ${incidentId}`);
    });

    // Leave incident room
    socket.on('leave_incident', (incidentId) => {
        socket.leave(`incident_${incidentId}`);
        console.log(`   Left incident room: ${incidentId}`);
    });

    socket.on('disconnect', () => {
        console.log(`🔌 Socket disconnected: ${socket.id}`);
    });
});

// --- Middleware ---

// Enable CORS for all origins (dev) — restrict in production
app.use(cors());

// Parse JSON request bodies
app.use(express.json({ limit: '10mb' }));

// Parse URL-encoded request bodies
app.use(express.urlencoded({ extended: true }));

// Serve static assets
const path = require('path');
app.use('/public', express.static(path.join(__dirname, 'public')));

// --- Routes ---

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.status(200).json({
        success: true,
        message: 'Indian Railways RRS API is running',
        timestamp: new Date().toISOString(),
    });
});

// Auth routes — POST /api/auth/login, POST /api/auth/register-operator
app.use('/api/auth', authRoutes);

// User routes — POST /api/users/create, GET /api/users
app.use('/api/users', userRoutes);

// Lead Supervisor routes — approval queue, notifications
app.use('/api/lead-supervisor', leadSupervisorRoutes);

// ART Train routes — CRUD, supervisor swap, operator assignment
app.use('/api/art-trains', artTrainRoutes);

// Supervisor routes — read-only train and operators
app.use('/api/supervisor', supervisorRoutes);

// Operator routes — read-only assignment view
app.use('/api/operator', operatorRoutes);

// Incident routes — Module 3: Rapid Response
app.use('/api/incidents', incidentRoutes);

// Navigation routes
app.use('/api/navigation', navigationRoutes);

// Proof web view route
app.use('/proof', proofRoutes);

// --- 404 Handler ---
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: `Route ${req.method} ${req.originalUrl} not found`,
    });
});

// --- Global Error Handler ---
app.use((err, req, res, next) => {
    console.error('Unhandled error:', err.stack);
    res.status(500).json({
        success: false,
        message: 'Internal server error',
    });
});

// --- Start Server ---
const PORT = process.env.PORT || 5000;

const startServer = async () => {
    try {
        // Connect to MongoDB
        await connectDB();

        // Seed Master Admin
        await seedMasterAdmin();

        // Start listening (use 'server' instead of 'app' for Socket.io)
        server.listen(PORT, () => {
            console.log(`\n🚂 Indian Railways RRS API Server`);
            console.log(`   Running on port ${PORT}`);
            console.log(`   Socket.io: enabled`);
            console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`   Health: http://localhost:${PORT}/api/health\n`);
        });
    } catch (error) {
        console.error('❌ Failed to start server:', error.message);
        process.exit(1);
    }
};

startServer();
