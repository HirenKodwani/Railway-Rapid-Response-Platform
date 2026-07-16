const mongoose = require('mongoose');
const dotenv = require('dotenv');
const { generatePDF } = require('./utils/pdfGenerator');
const User = require('./models/User');
const Incident = require('./models/Incident');
const OperatorIncidentLog = require('./models/OperatorIncidentLog');
const Proof = require('./models/Proof');

dotenv.config({ path: './.env' });

async function run() {
  await mongoose.connect(process.env.MONGO_URI, { useNewUrlParser: true, useUnifiedTopology: true });
  console.log('Connected to DB');
  
  // Find a resolved incident
  const incident = await Incident.findOne({ status: 'resolved' }).populate('created_by');
  if (!incident) {
    console.log('No resolved incident found');
    process.exit(0);
  }
  
  console.log('Testing PDF generation for incident:', incident._id);
  const logs = await OperatorIncidentLog.find({ incident_id: incident._id }).populate('operator_id');
  const proofs = await Proof.find({ incident_id: incident._id }).lean();
  
  const pdfBuffer = await generatePDF(incident, logs, proofs);
  console.log('PDF generated successfully. Size:', pdfBuffer.length);
  
  process.exit(0);
}

run().catch(console.error);
