const fs = require('fs');
const path = require('path');

const image1Path = path.join(__dirname, '../public/images/image1.png');
const image2Path = path.join(__dirname, '../public/images/image2.png');

let image1Base64 = '';
let image2Base64 = '';
if (fs.existsSync(image1Path)) {
  image1Base64 = 'data:image/png;base64,' + fs.readFileSync(image1Path).toString('base64');
}
if (fs.existsSync(image2Path)) {
  image2Base64 = 'data:image/jpeg;base64,' + fs.readFileSync(image2Path).toString('base64');
}

function generateReportHtml(incident, logs, proofs, proofCounts, isWeb = false) {
  // Common styles to mimic docx
  let html = `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <title>Incident Report - ${incident.train_number}</title>
    <style>
      body {
        font-family: 'Times New Roman', Times, serif;
        margin: 0;
        padding: 40px;
        color: #000;
        background-color: #fff;
      }
      .header-container {
        display: flex;
        align-items: center;
        justify-content: space-between;
        border-bottom: 2px solid #000;
        padding-bottom: 10px;
        margin-bottom: 20px;
      }
      .logo {
        height: 80px;
        object-fit: contain;
      }
      .header-title {
        text-align: center;
      }
      .header-title h1, .header-title h2, .header-title h3 {
        margin: 0;
        padding: 0;
      }
      .header-title h1 {
        font-size: 24px;
        font-weight: bold;
      }
      .header-title h2 {
        font-size: 18px;
        margin-top: 5px;
      }
      .header-title h3 {
        font-size: 16px;
        text-decoration: underline;
        margin-top: 10px;
      }
      .top-table {
        width: 100%;
        margin-bottom: 20px;
        border: none;
      }
      .top-table td {
        padding: 5px;
        font-weight: bold;
      }
      .section {
        margin-bottom: 30px;
      }
      .section-title {
        font-weight: bold;
        font-size: 16px;
        background-color: #f0f0f0;
        padding: 5px;
        border: 1px solid #000;
        margin-bottom: 10px;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 15px;
      }
      th, td {
        border: 1px solid #000;
        padding: 8px;
        text-align: left;
        font-size: 14px;
      }
      th {
        background-color: #f9f9f9;
        font-weight: bold;
      }
      .media-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 20px;
      }
      .media-card {
        border: 1px solid #ccc;
        padding: 10px;
        text-align: center;
      }
      .media-card img, .media-card video {
        max-width: 100%;
        height: auto;
      }
      .media-card audio {
        width: 100%;
        margin-top: 10px;
      }
      .media-meta {
        margin-top: 10px;
        font-size: 12px;
        text-align: left;
      }
      .text-statement {
        font-style: italic;
        padding: 10px;
        border-left: 3px solid #000;
        margin-bottom: 10px;
        background-color: #fafafa;
      }
    </style>
  </head>
  <body>
    <div class="header-container">
      <img src="${image1Base64}" class="logo" />
      <div class="header-title">
        <h1>INDIAN RAILWAYS</h1>
        <h2>Rapid Response Platform (R3P)</h2>
        <h3>INCIDENT INVESTIGATION REPORT</h3>
      </div>
      <img src="${image2Base64}" class="logo" />
    </div>

    <table class="top-table">
      <tr>
        <td>Incident ID: ${incident._id}</td>
        <td>Report Status: ${incident.status ? incident.status.toUpperCase() : ''}</td>
      </tr>
      <tr>
        <td>Generated Date: ${new Date().toLocaleString()}</td>
        <td>Verification ID: ${incident.accessToken}</td>
      </tr>
    </table>

    <div style="text-align: center; font-weight: bold; margin-bottom: 20px; font-size: 16px;">
      INCIDENT: ${incident.incident_category} - ${incident.incident_subcategory} <br/>
      CLASSIFICATION: ${incident.affected_component}  |  SEVERITY: ${incident.severity}  |  STATUS: ${incident.status ? incident.status.toUpperCase() : ''}
    </div>

    <div class="section">
      <div class="section-title">SECTION 1: EXECUTIVE SUMMARY</div>
      <table>
        <tr><th>Incident ID</th><td>${incident._id}</td><th>Incident Type</th><td>${incident.incident_category}</td></tr>
        <tr><th>Sub-Category</th><td>${incident.incident_subcategory}</td><th>Severity Level</th><td>${incident.severity}</td></tr>
        <tr><th>Location</th><td>Lat: ${incident.latitude}, Lng: ${incident.longitude}</td><th>Created At</th><td>${new Date(incident.createdAt).toLocaleString()}</td></tr>
        <tr><th>Resolved At</th><td>${incident.resolved_at ? new Date(incident.resolved_at).toLocaleString() : 'N/A'}</td><th>Duration</th><td>${incident.resolved_at ? Math.floor((new Date(incident.resolved_at) - new Date(incident.createdAt)) / 60000) + ' mins' : 'N/A'}</td></tr>
      </table>
    </div>

    <div class="section">
      <div class="section-title">SECTION 2: RESOURCE DEPLOYMENT</div>
      <table>
        <tr>
          <th>Operator Name</th>
          <th>Designation</th>
          <th>Notified At</th>
          <th>Accepted At</th>
          <th>ART Arrived</th>
          <th>Site Arrived</th>
        </tr>
  `;

  logs.forEach(log => {
    html += `
        <tr>
          <td>${log.operator_id?.name || 'Unknown'}</td>
          <td>Operator</td>
          <td>${log.notified_at ? new Date(log.notified_at).toLocaleTimeString() : 'N/A'}</td>
          <td>${log.accepted_at ? new Date(log.accepted_at).toLocaleTimeString() : 'N/A'}</td>
          <td>${log.art_dwell_confirmed_at ? new Date(log.art_dwell_confirmed_at).toLocaleTimeString() : 'N/A'}</td>
          <td>${log.site_geofence_entered_at ? new Date(log.site_geofence_entered_at).toLocaleTimeString() : 'N/A'}</td>
        </tr>
    `;
  });

  html += `
      </table>
    </div>

    <div class="section">
      <div class="section-title">SECTION 3: EVIDENCE SUMMARY</div>
      <table>
        <tr><th>Evidence Type</th><th>Count</th></tr>
        <tr><td>Photographs</td><td>${proofCounts.images || 0}</td></tr>
        <tr><td>Videos</td><td>${proofCounts.videos || 0}</td></tr>
        <tr><td>Audio Recordings</td><td>${proofCounts.audios || 0}</td></tr>
        <tr><td>Text Statements</td><td>${proofCounts.texts ? proofCounts.texts.length : 0}</td></tr>
      </table>
    </div>
  `;

  const renderMeta = (p) => `
    <div class="media-meta">
      <strong>Operator:</strong> ${p.operator_name || 'Unknown'}<br/>
      <strong>Captured:</strong> ${new Date(p.timestamp).toLocaleString()}<br/>
      <strong>GPS:</strong> ${p.geostamp?.lat?.toFixed(5)}, ${p.geostamp?.lng?.toFixed(5)}<br/>
      <strong>Device:</strong> ${p.device_info?.model || 'N/A'}
    </div>
  `;

  const images = proofs.filter(p => p.proof_type === 'IMAGE');
  if (images.length > 0) {
    html += `
    <div class="section" style="page-break-before: always;">
      <div class="section-title">SECTION 4: PHOTOGRAPHIC EVIDENCE</div>
      <div class="media-grid">
    `;
    images.forEach(img => {
      html += `
        <div class="media-card">
          <img src="${img.url}" alt="Evidence" />
          ${renderMeta(img)}
        </div>
      `;
    });
    html += `</div></div>`;
  }

  const texts = proofs.filter(p => p.proof_type === 'TEXT');
  if (texts.length > 0) {
    html += `
    <div class="section">
      <div class="section-title">SECTION 5: TEXT STATEMENTS</div>
    `;
    texts.forEach(txt => {
      html += `
        <div class="text-statement">"${txt.text_content}"</div>
        ${renderMeta(txt)}
        <hr style="border: 0; border-top: 1px solid #ccc; margin: 15px 0;" />
      `;
    });
    html += `</div>`;
  }

  const videos = proofs.filter(p => p.proof_type === 'VIDEO');
  if (videos.length > 0) {
    html += `
    <div class="section" style="page-break-before: always;">
      <div class="section-title">SECTION 6: VIDEO EVIDENCE</div>
      <div class="media-grid">
    `;
    videos.forEach(vid => {
      html += `
        <div class="media-card">
      `;
      if (isWeb) {
        html += `<video controls><source src="${vid.url}" type="video/mp4"></video>`;
      } else {
        html += `<div style="padding: 40px; background: #eee; border: 1px dashed #999;">[Video Evidence: Scan QR or view on Web Report to watch]</div>`;
        html += `<div style="margin-top:10px;"><a href="${vid.url}" style="color: blue; text-decoration: underline;">Direct Link to Video</a></div>`;
      }
      html += `
          ${renderMeta(vid)}
        </div>
      `;
    });
    html += `</div></div>`;
  }

  const audios = proofs.filter(p => p.proof_type === 'AUDIO');
  if (audios.length > 0) {
    html += `
    <div class="section">
      <div class="section-title">SECTION 7: AUDIO EVIDENCE</div>
      <div class="media-grid">
    `;
    audios.forEach(aud => {
      html += `
        <div class="media-card">
      `;
      if (isWeb) {
        html += `<audio controls><source src="${aud.url}" type="audio/mp4"></audio>`;
      } else {
        html += `<div style="padding: 20px; background: #eee; border: 1px dashed #999;">[Audio Evidence: View on Web Report to listen]</div>`;
        html += `<div style="margin-top:10px;"><a href="${aud.url}" style="color: blue; text-decoration: underline;">Direct Link to Audio</a></div>`;
      }
      html += `
          ${renderMeta(aud)}
        </div>
      `;
    });
    html += `</div></div>`;
  }

  html += `
    <div class="section" style="margin-top: 50px;">
      <div class="section-title">APPROVALS & SIGN-OFF</div>
      <table style="border: none;">
        <tr style="border: none;">
          <td style="border: none; padding: 20px;">
            <strong>Prepared By:</strong><br/><br/><br/>
            ${incident.created_by?.name || 'Supervisor'}<br/>
            (Digital Signature)
          </td>
          <td style="border: none; padding: 20px; text-align: right;">
            <strong>System Verification:</strong><br/><br/><br/>
            ${incident.accessToken}<br/>
            R3P Automated Sign-off
          </td>
        </tr>
      </table>
    </div>
  </body>
  </html>
  `;

  return html;
}

module.exports = { generateReportHtml };
