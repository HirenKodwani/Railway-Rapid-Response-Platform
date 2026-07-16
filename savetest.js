const mongoose = require('mongoose');
const dotenv = require('dotenv');
const { generatePDF } = require('./utils/pdfGenerator');
const User = require('./models/User');
const Incident = require('./models/Incident');
const OperatorIncidentLog = require('./models/OperatorIncidentLog');
const Proof = require('./models/Proof');
const fs = require('fs');
dotenv.config({ path: './.env' });
async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  const incident = await Incident.findOne({ status: 'resolved' }).populate('created_by');
  const logs = await OperatorIncidentLog.find({ incident_id: incident._id }).populate('operator_id');
  const proofs = await Proof.find({ incident_id: incident._id }).lean();
  const buf = await generatePDF(incident, logs, proofs);
  fs.writeFileSync('test_output.pdf', buf);
  console.log('Saved test_output.pdf, size:', buf.length);
  process.exit(0);
}
run().catch(e => { console.error(e); process.exit(1); });
