const express = require('express');
const router = express.Router();
const Incident = require('../models/Incident');
const Proof = require('../models/Proof');
const OperatorIncidentLog = require('../models/OperatorIncidentLog');

router.get('/:incidentId/:verificationId', async (req, res) => {
  try {
    const { incidentId, verificationId } = req.params;

    // Verify incident and token
    const incident = await Incident.findById(incidentId).populate('created_by', 'name');
    if (!incident || incident.accessToken !== verificationId) {
      return res.status(404).send('<h1>Proof Page Not Found or Access Denied</h1>');
    }

    const proofs = await Proof.find({ incident_id: incidentId }).lean();
    const logs = await OperatorIncidentLog.find({ incident_id: incidentId }).populate('operator_id', 'name').lean();

    const images = proofs.filter(p => p.proof_type === 'IMAGE');
    const videos = proofs.filter(p => p.proof_type === 'VIDEO');
    const audios = proofs.filter(p => p.proof_type === 'AUDIO');
    const allTexts = proofs.filter(p => p.proof_type === 'TEXT');

    // Bug 1 Fix: Deduplicate text statements
    const uniqueTextsMap = new Map();
    for (const txt of allTexts) {
      const key = `${txt.operator_id}_${txt.timestamp}_${txt.text_content}`;
      uniqueTextsMap.set(key, txt);
    }
    const texts = Array.from(uniqueTextsMap.values());

    const acceptedLogs = logs.filter(l => l.acceptance_status === 'ACCEPTED');

    let html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Incident Report - ${incident.train_number}</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&family=Roboto+Mono:wght@400;500&display=swap" rel="stylesheet">
      <style>
        body { font-family: 'Inter', Arial, Helvetica, sans-serif; background-color: #f4f7f6; color: #1A1A1A; margin: 0; padding: 0; }
        .mono { font-family: 'Roboto Mono', monospace; }
        
        .header { background-color: #1B2A4A; color: #FFFFFF; width: 100%; }
        .header-top { padding: 20px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #2E5596; }
        .header-top h1 { font-size: 18px; letter-spacing: 2px; margin: 0; font-weight: 700; }
        .header-top .logos { font-size: 12px; }
        .header-bottom { background-color: #2E5596; padding: 8px 20px; font-size: 12px; display: flex; justify-content: center; gap: 20px; flex-wrap: wrap; }
        
        .container { max-width: 900px; margin: 24px auto; padding: 0 16px; }
        
        .card { background: #FFFFFF; border: 1px solid #B8CCE4; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); overflow: hidden; margin-bottom: 24px; }
        .card-header { background: #2E5596; color: #FFFFFF; padding: 12px 16px; font-weight: 700; font-size: 14px; }
        
        .table-kv { width: 100%; border-collapse: collapse; }
        .table-kv td { padding: 12px 16px; border-bottom: 1px solid #B8CCE4; font-size: 14px; }
        .table-kv tr:last-child td { border-bottom: none; }
        .table-kv .label-col { background: #D6E4F7; color: #2E5596; font-weight: 700; width: 140px; }
        
        .badge { padding: 4px 8px; border-radius: 12px; font-size: 12px; font-weight: 600; color: #FFFFFF; display: inline-block; }
        .badge.green { background: #27AE60; }
        .badge.red { background: #C0392B; }
        
        .table-data { width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; }
        .table-data th { background: #2E5596; color: #FFFFFF; padding: 10px; font-weight: 700; border: 1px solid #B8CCE4; }
        .table-data td { padding: 10px; border: 1px solid #B8CCE4; }
        .table-data tr:nth-child(even) { background: #F5F8FD; }
        .table-responsive { overflow-x: auto; }
        
        .sticky-nav { position: sticky; top: 0; z-index: 100; background: #1B2A4A; display: flex; justify-content: center; gap: 10px; padding: 10px; overflow-x: auto; margin-bottom: 24px; }
        .sticky-nav a { color: rgba(255,255,255,0.7); text-decoration: none; padding: 8px 16px; font-size: 14px; white-space: nowrap; }
        .sticky-nav a:hover { color: #FFFFFF; }
        
        .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
        @media (max-width: 600px) { .grid-2 { grid-template-columns: 1fr; } }
        
        .media-card { background: #FFFFFF; border: 1px solid #B8CCE4; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .media-card img { width: 100%; height: 200px; object-fit: cover; display: block; cursor: pointer; }
        .media-card video { width: 100%; display: block; }
        .media-card audio { width: 100%; display: block; margin: 10px 0; }
        .media-meta { background: #EAF0FB; padding: 12px; font-size: 13px; }
        .media-meta strong { color: #2E5596; }
        .media-meta a { color: #2E5596; text-decoration: none; }
        
        .statement-card { background: #FFFFFF; border-left: 4px solid #2E5596; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); margin-bottom: 16px; padding: 16px; }
        .statement-text { font-style: italic; font-size: 15px; color: #1A1A1A; margin-bottom: 12px; }
        .statement-meta { font-size: 12px; color: #555; border-top: 1px solid #EEE; padding-top: 8px; }
        
        .footer { background: #1B2A4A; color: #FFFFFF; text-align: center; padding: 32px 16px; font-size: 12px; margin-top: 40px; }
        .footer .confidential { color: #C0392B; font-weight: 700; font-size: 14px; margin-bottom: 8px; }
      </style>
    </head>
    <body>

      <div class="header">
        <div class="header-top container" style="margin:0 auto; padding-left:16px; padding-right:16px;">
          <img src="/public/images/image1.png" alt="INDIAN RAILWAYS" style="height:48px; object-fit:contain;" onerror="this.style.display='none';">
          <h1>INCIDENT MEDIA & EVIDENCE ANNEX</h1>
          <img src="/public/images/image2.png" alt="VASP SYSTEMIC" style="height:48px; object-fit:contain;" onerror="this.style.display='none';">
        </div>
        <div class="header-bottom mono">
          <span>Incident ID: ${incident._id}</span>
          <span>Status: ${incident.status.toUpperCase()}</span>
          <span>Verification: ${verificationId}</span>
        </div>
      </div>

      <div class="container">
        
        <!-- SUMMARY CARD -->
        <div class="card">
          <div class="card-header">INCIDENT OVERVIEW</div>
          <table class="table-kv">
            <tr>
              <td class="label-col">Type</td>
              <td>${incident.incident_category} - ${incident.incident_subcategory}</td>
            </tr>
            <tr>
              <td class="label-col">Location</td>
              <td><a href="https://maps.google.com/?q=${incident.latitude},${incident.longitude}" target="_blank">${incident.latitude}, ${incident.longitude}</a></td>
            </tr>
            <tr>
              <td class="label-col">Created</td>
              <td>${new Date(incident.createdAt).toLocaleString()}</td>
            </tr>
            <tr>
              <td class="label-col">Supervisor</td>
              <td>${incident.created_by?.name || 'Unknown'}</td>
            </tr>
            <tr>
              <td class="label-col">Status</td>
              <td><span class="badge ${incident.status === 'resolved' ? 'green' : 'red'}">● ${incident.status.toUpperCase()}</span></td>
            </tr>
          </table>
        </div>

        <!-- OPERATOR RESPONSE LOGS -->
        <div class="card-header" style="border-radius:8px 8px 0 0; margin-bottom: 0;">OPERATOR RESPONSE LOGS</div>
        <div class="card" style="border-radius:0 0 8px 8px; padding: 16px;">
          
          <h4 style="color:#2E5596; margin-top:0;">Acceptance Log</h4>
          <div class="table-responsive">
            <table class="table-data">
              <tr><th>Operator</th><th>Notified At</th><th>Accepted At</th><th>Delay (min)</th><th>Status</th></tr>`;
              
              logs.forEach(log => {
                const delay = (log.notified_at && log.accepted_at) ? Math.round((new Date(log.accepted_at) - new Date(log.notified_at))/60000) : '-';
                const statusBadge = log.acceptance_status === 'ACCEPTED' ? '<span class="badge green">ACCEPTED</span>' : 
                                    (log.acceptance_status === 'PENDING' ? '<span class="badge" style="background:#555;">PENDING</span>' : 
                                    '<span class="badge red">' + log.acceptance_status + '</span>');
                html += `<tr>
                  <td>${log.operator_id?.name || 'Unknown'}</td>
                  <td>${log.notified_at ? new Date(log.notified_at).toLocaleTimeString() : '-'}</td>
                  <td>${log.accepted_at ? new Date(log.accepted_at).toLocaleTimeString() : '-'}</td>
                  <td>${delay}</td>
                  <td>${statusBadge}</td>
                </tr>`;
              });

          html += `
            </table>
          </div>

          <h4 style="color:#2E5596;">Attendance Log (ART)</h4>
          <div class="table-responsive">
            <table class="table-data">
              <tr><th>Operator</th><th>Accepted At</th><th>ART Arrived</th><th>Duration (min)</th><th>Status</th></tr>`;
              
              acceptedLogs.forEach(log => {
                const dur = (log.accepted_at && log.art_dwell_confirmed_at) ? Math.round((new Date(log.art_dwell_confirmed_at) - new Date(log.accepted_at))/60000) : '-';
                const statusStr = log.attendance_status === 'PRESENT' ? 'PRESENT' : 'PENDING';
                const statusBadge = statusStr === 'PRESENT' ? '<span class="badge green">PRESENT</span>' : '<span class="badge red">PENDING</span>';
                
                html += `<tr>
                  <td>${log.operator_id?.name || 'Unknown'}</td>
                  <td>${log.accepted_at ? new Date(log.accepted_at).toLocaleTimeString() : '-'}</td>
                  <td>${log.art_dwell_confirmed_at ? new Date(log.art_dwell_confirmed_at).toLocaleTimeString() : '-'}</td>
                  <td>${dur}</td>
                  <td>${statusBadge}</td>
                </tr>`;
              });

          html += `
            </table>
          </div>

          <h4 style="color:#2E5596;">Response Time Log (Site)</h4>
          <div class="table-responsive">
            <table class="table-data">
              <tr><th>Operator</th><th>Accepted At</th><th>Site Arrived</th><th>Duration (min)</th><th>Status</th></tr>`;
              
              acceptedLogs.forEach(log => {
                const dur = (log.accepted_at && log.site_geofence_entered_at) ? Math.round((new Date(log.site_geofence_entered_at) - new Date(log.accepted_at))/60000) : '-';
                const statusStr = log.response_status === 'REACHED' ? 'REACHED' : 'PENDING';
                const statusBadge = statusStr === 'REACHED' ? '<span class="badge green">REACHED</span>' : '<span class="badge red">PENDING</span>';
                
                html += `<tr>
                  <td>${log.operator_id?.name || 'Unknown'}</td>
                  <td>${log.accepted_at ? new Date(log.accepted_at).toLocaleTimeString() : '-'}</td>
                  <td>${log.site_geofence_entered_at ? new Date(log.site_geofence_entered_at).toLocaleTimeString() : '-'}</td>
                  <td>${dur}</td>
                  <td>${statusBadge}</td>
                </tr>`;
              });

          html += `
            </table>
          </div>
        </div>
      </div>

      <!-- STICKY NAV -->
      <div class="sticky-nav">
        <a href="#images" onclick="document.querySelectorAll('.sticky-nav a').forEach(a=>a.style.color=''); this.style.color='#FFF'; this.style.borderBottom='2px solid #2E5596';">📷 Images (${images.length})</a>
        <a href="#videos" onclick="document.querySelectorAll('.sticky-nav a').forEach(a=>a.style.color=''); this.style.color='#FFF'; this.style.borderBottom='2px solid #2E5596';">🎬 Videos (${videos.length})</a>
        <a href="#audios" onclick="document.querySelectorAll('.sticky-nav a').forEach(a=>a.style.color=''); this.style.color='#FFF'; this.style.borderBottom='2px solid #2E5596';">🎙 Audio (${audios.length})</a>
        <a href="#statements" onclick="document.querySelectorAll('.sticky-nav a').forEach(a=>a.style.color=''); this.style.color='#FFF'; this.style.borderBottom='2px solid #2E5596';">📝 Statements (${texts.length})</a>
      </div>

      <div class="container">
        
        <!-- IMAGES -->
        <div id="images">
          <div class="card-header" style="margin-bottom:16px; border-radius:4px;">PHOTOGRAPHIC EVIDENCE</div>
          <div class="grid-2">`;
          
          images.forEach(img => {
            html += `
            <div class="media-card">
              <a href="${img.url}" target="_blank">
                <img src="${img.url}" alt="Evidence" loading="lazy" />
              </a>
              <div class="media-meta">
                <div><strong>📅 Timestamp:</strong> ${new Date(img.timestamp).toLocaleString()}</div>
                <div><strong>📍 Location:</strong> <a href="https://maps.google.com/?q=${img.geostamp?.lat || 0},${img.geostamp?.lng || 0}" target="_blank">${img.geostamp?.lat || 0}, ${img.geostamp?.lng || 0}</a></div>
                <div><strong>📱 Device:</strong> ${img.device_info?.model || 'Unknown'}</div>
                <div><strong>👤 Captured By:</strong> ${img.operator_name}</div>
              </div>
            </div>`;
          });
          
          if (images.length === 0) html += `<p>No photographic evidence available.</p>`;
          
          html += `</div>
        </div>

        <div style="height: 40px;"></div>

        <!-- VIDEOS -->
        <div id="videos">
          <div class="card-header" style="margin-bottom:16px; border-radius:4px;">VIDEO EVIDENCE</div>
          <div class="grid-2">`;
          
          videos.forEach(vid => {
            html += `
            <div class="media-card">
              <video controls preload="metadata">
                <source src="${vid.url}" type="video/mp4">
              </video>
              <div class="media-meta">
                <div><strong>📅 Timestamp:</strong> ${new Date(vid.timestamp).toLocaleString()}</div>
                <div><strong>📍 Location:</strong> <a href="https://maps.google.com/?q=${vid.geostamp?.lat || 0},${vid.geostamp?.lng || 0}" target="_blank">${vid.geostamp?.lat || 0}, ${vid.geostamp?.lng || 0}</a></div>
                <div><strong>📱 Device:</strong> ${vid.device_info?.model || 'Unknown'}</div>
                <div><strong>👤 Captured By:</strong> ${vid.operator_name}</div>
                <div style="margin-top:8px;">🔗 <a href="${vid.url}" target="_blank">Direct Link (Download)</a></div>
              </div>
            </div>`;
          });

          if (videos.length === 0) html += `<p>No video evidence available.</p>`;

          html += `</div>
        </div>

        <div style="height: 40px;"></div>

        <!-- AUDIOS -->
        <div id="audios">
          <div class="card-header" style="margin-bottom:16px; border-radius:4px;">AUDIO RECORDINGS</div>
          <div class="grid-2">`;
          
          audios.forEach((aud, i) => {
            html += `
            <div class="media-card">
              <div style="padding: 12px; background: #EAF0FB; color: #2E5596; font-weight: 700;">🎙 AUDIO RECORDING #${i+1}</div>
              <div style="padding: 0 12px;">
                <audio controls>
                  <source src="${aud.url}">
                </audio>
              </div>
              <div class="media-meta">
                <div><strong>📅 Timestamp:</strong> ${new Date(aud.timestamp).toLocaleString()}</div>
                <div><strong>📍 Location:</strong> <a href="https://maps.google.com/?q=${aud.geostamp?.lat || 0},${aud.geostamp?.lng || 0}" target="_blank">${aud.geostamp?.lat || 0}, ${aud.geostamp?.lng || 0}</a></div>
                <div><strong>📱 Device:</strong> ${aud.device_info?.model || 'Unknown'}</div>
                <div><strong>👤 Captured By:</strong> ${aud.operator_name}</div>
                <div style="font-style:italic; margin-top:8px; color:#555;">Transcript: "No transcript available"</div>
              </div>
            </div>`;
          });

          if (audios.length === 0) html += `<p>No audio evidence available.</p>`;

          html += `</div>
        </div>

        <div style="height: 40px;"></div>

        <!-- STATEMENTS -->
        <div id="statements">
          <div class="card-header" style="margin-bottom:16px; border-radius:4px;">TEXT STATEMENTS</div>
          <div>`;
          
          texts.forEach((txt, i) => {
            html += `
            <div class="statement-card">
              <div style="background: #EAF0FB; padding: 4px 8px; font-size: 12px; font-weight: bold; color: #2E5596; display: inline-block; margin-bottom: 8px; border-radius: 4px;">💬 Statement #${i+1}</div>
              <div class="statement-text">"${txt.text_content}"</div>
              <div class="statement-meta">
                👤 <strong>${txt.operator_name}</strong> &nbsp;|&nbsp; 📅 ${new Date(txt.timestamp).toLocaleString()} &nbsp;|&nbsp; 📍 <a href="https://maps.google.com/?q=${txt.geostamp?.lat || 0},${txt.geostamp?.lng || 0}" target="_blank" style="color:#555; text-decoration:none;">${txt.geostamp?.lat || 0}, ${txt.geostamp?.lng || 0}</a>
              </div>
            </div>`;
          });

          if (texts.length === 0) html += `<p>No text statements available.</p>`;

          html += `</div>
        </div>

      </div>

      <!-- FOOTER -->
      <div class="footer">
        <div class="confidential">CONFIDENTIAL — INDIAN RAILWAYS — RAPID RESPONSE PLATFORM (R3P)</div>
        <div style="margin-bottom:8px;">This page is an official evidence annex. Unauthorized access or distribution is prohibited.</div>
        <div class="mono">Report Generated: ${new Date().toLocaleString()} &nbsp;|&nbsp; Verification ID: ${verificationId}</div>
      </div>

    </body>
    </html>
    `;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.send(html);
  } catch (error) {
    console.error('Error rendering proof page:', error);
    res.status(500).send('<h1>Internal Server Error</h1>');
  }
});

module.exports = router;
