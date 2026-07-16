const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
const axios = require('axios');
const path = require('path');
const fs = require('fs');

async function dlImg(url) {
  try { const r = await axios.get(url,{responseType:'arraybuffer',timeout:15000}); return Buffer.from(r.data); }
  catch(e) { return null; }
}

function safeImg(doc,buf,x,y,opts){ try{ if(buf) doc.image(buf,x,y,opts); } catch(e){} }

const e = (str) => {
  if (!str) return str;
  return String(str).replace(/[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F700}-\u{1F77F}\u{1F780}-\u{1F7FF}\u{1F800}-\u{1F8FF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]/gu, '');
};

async function generatePDF(incident, logs, proofs) {
  return new Promise(async (resolve, reject) => {
   try {
    const doc = new PDFDocument({size:'A4',margin:0,bufferPages:true});
    const bufs=[]; doc.on('data',b=>bufs.push(b)); doc.on('end',()=>resolve(Buffer.concat(bufs))); doc.on('error',reject);

    const mX=56.7, cW=481.88, pgH=841.89;
    const navy='#1B2A4A', blue='#2E5596', lblBg='#D6E4F7', altBg='#F5F8FD', bdr='#B8CCE4', red='#C0392B', grn='#27AE60';
    const logo1=path.join(__dirname,'../public/images/image1.png');
    const logo2=path.join(__dirname,'../public/images/image2.png');

    const images=proofs.filter(p=>p.proof_type==='IMAGE');
    const videos=proofs.filter(p=>p.proof_type==='VIDEO');
    const audios=proofs.filter(p=>p.proof_type==='AUDIO');
    const texts=proofs.filter(p=>p.proof_type==='TEXT');
    const seenTxt=new Map();
    texts.forEach(t=>{ const k=String(t.operator_id)+'_'+t.text_content; if(!seenTxt.has(k)) seenTxt.set(k,t); });
    const uTexts=Array.from(seenTxt.values());
    const accLogs=logs.filter(l=>l.acceptance_status==='ACCEPTED');

    const hdrFtr=()=>{
      const rng=doc.bufferedPageRange();
      for(let i=rng.start;i<rng.start+rng.count;i++){
        doc.switchToPage(i);
        doc.rect(0,0,595.28,72).fill(navy);
        try{ if(fs.existsSync(logo1)) doc.image(logo1,mX,12,{width:44,height:44}); else doc.rect(mX,12,44,44).fill(blue); } catch(e){ doc.rect(mX,12,44,44).fill(blue); }
        try{ if(fs.existsSync(logo2)) doc.image(logo2,595.28-mX-80,12,{width:80,height:44}); else doc.rect(595.28-mX-80,12,80,44).fill(blue); } catch(e){ doc.rect(595.28-mX-80,12,80,44).fill(blue); }
        doc.fillColor('#fff').font('Helvetica-Bold').fontSize(13).text('INDIAN RAILWAYS',120,16,{width:340,align:'center'});
        doc.font('Helvetica').fontSize(9).text('Rapid Response Platform (R3P)',120,33,{width:340,align:'center'});
        doc.font('Helvetica-Bold').fontSize(10).text('INCIDENT INVESTIGATION REPORT',120,48,{width:340,align:'center'});
        doc.rect(0,72,595.28,22).fill('#EAF0FB');
        doc.font('Helvetica-Bold').fontSize(7.5).fillColor(blue);
        const subLine='ID: '+incident._id+' | Status: '+incident.status.toUpperCase()+' | Generated: '+new Date().toLocaleDateString()+' | Auth: '+(incident.accessToken||'N/A');
        doc.text(subLine,mX,80,{width:cW,align:'center',lineBreak:false,ellipsis:true});
        doc.rect(0,94,595.28,1).fill(bdr);
        const fY=pgH-36;
        doc.rect(0,fY,595.28,36).fill(navy);
        doc.font('Helvetica-Bold').fontSize(7.5).fillColor(red).text('CONFIDENTIAL',mX,fY+12,{continued:true});
        doc.fillColor('#fff').text(' — INDIAN RAILWAYS RAPID RESPONSE PLATFORM (R3P)',{continued:true});
        doc.text('  Page '+(i+1)+' of '+rng.count,{align:'right'});
      }
    };

    doc.page.margins={top:105,bottom:50,left:mX,right:mX};
    doc.y=105;

    const secBand=(num,title)=>{
      if(doc.y>680) doc.addPage();
      const y=doc.y;
      doc.rect(mX,y,cW,22).fill(blue);
      doc.fillColor('#fff').font('Helvetica-Bold').fontSize(10);
      doc.text('SECTION '+num,mX+8,y+6,{width:75,lineBreak:false});
      doc.rect(mX+83,y,1,22).fill('rgba(255,255,255,0.5)');
      doc.text(e(title),mX+92,y+6,{width:cW-100,lineBreak:false});
      doc.y=y+22;
    };

    const row2=(label,value,alt)=>{
      if(doc.y>720) doc.addPage();
      const y=doc.y;
      doc.rect(mX,y,175,18).fill(lblBg).stroke(bdr);
      doc.rect(mX+175,y,cW-175,18).fill(alt?altBg:'#fff').stroke(bdr);
      doc.fillColor(blue).font('Helvetica-Bold').fontSize(8.5).text(label,mX+5,y+4,{width:165,lineBreak:false});
      doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8.5).text(e(String(value||'N/A')),mX+180,y+4,{width:cW-185,lineBreak:false,ellipsis:true});
      doc.y=y+18;
    };

    const tblHdr=(cols)=>{
      if(doc.y>710) doc.addPage();
      const y=doc.y; let cx=mX;
      doc.rect(mX,y,cW,18).fill(blue);
      doc.fillColor('#fff').font('Helvetica-Bold').fontSize(7.5);
      cols.forEach(c=>{ doc.text(c.h,cx+1,y+5,{width:c.w-2,align:'center',lineBreak:false}); cx+=c.w; });
      doc.y=y+18;
    };

    const tblRow=(cols,vals,idx)=>{
      if(doc.y>720) doc.addPage();
      const y=doc.y; let cx=mX;
      doc.rect(mX,y,cW,18).fill(idx%2===1?altBg:'#fff').stroke(bdr);
      doc.font('Helvetica').fontSize(7.5).fillColor('#1a1a1a');
      vals.forEach((v,i)=>{ doc.text(e(String(v||'N/A')),cx+2,y+5,{width:cols[i].w-4,align:'center',lineBreak:false,ellipsis:true}); cx+=cols[i].w; });
      doc.y=y+18;
    };

    const gap=(n=10)=>{ doc.y+=n; };

    let si=1;

    // Title Banner
    const dur=incident.resolved_at?Math.floor((new Date(incident.resolved_at)-new Date(incident.createdAt))/60000)+' min':'Ongoing';
    doc.rect(mX,doc.y,cW,32).fill(navy);
    doc.fillColor('#fff').font('Helvetica-Bold').fontSize(11).text('INCIDENT: '+e(incident.incident_category)+' — '+e(incident.incident_subcategory),mX+8,doc.y+4,{width:cW-16,lineBreak:false,ellipsis:true});
    doc.y+=16;
    doc.font('Helvetica').fontSize(8.5).text('CLASSIFICATION: '+e(incident.affected_component)+' | SEVERITY: '+e(incident.severity)+' | STATUS: '+incident.status.toUpperCase(),mX+8,doc.y+2,{width:cW-16,lineBreak:false});
    doc.y+=20; gap(8);

    // S1 EXECUTIVE SUMMARY
    secBand(si++,'EXECUTIVE SUMMARY');
    row2('Incident ID',String(incident._id),false);
    row2('Incident Type',incident.incident_category,true);
    row2('Sub-Category',incident.incident_subcategory,false);
    row2('Severity Level',incident.severity,true);
    row2('Location','Lat: '+incident.latitude+', Lng: '+incident.longitude,false);
    row2('Created At',new Date(incident.createdAt).toLocaleString(),true);
    row2('Resolved At',incident.resolved_at?new Date(incident.resolved_at).toLocaleString():'N/A',false);
    row2('Duration',dur,true);
    row2('Summary',incident.incident_subcategory+' reported at train '+incident.train_number,false);
    gap();

    // S2 INCIDENT DETAILS
    secBand(si++,'INCIDENT DETAILS');
    row2('Train Number',incident.train_number,true);
    row2('Zone',incident.zone||'N/A',false);
    row2('Division',incident.division||'N/A',true);
    row2('Latitude',incident.latitude,false);
    row2('Longitude',incident.longitude,true);
    row2('Severity',incident.severity,false);
    row2('Incident Category',incident.incident_category,true);
    row2('Incident Sub-Category',incident.incident_subcategory,false);
    row2('Affected Component',incident.affected_component,true);
    row2('Mock Drill',incident.is_mock_drill?'YES':'NO',false);
    row2('Status',incident.status.toUpperCase(),true);
    row2('Created At',new Date(incident.createdAt).toLocaleString(),false);
    row2('Resolved At',incident.resolved_at?new Date(incident.resolved_at).toLocaleString():'N/A',true);
    row2('Duration',dur,false);
    gap();

    // S3 TRAIN & CREW
    secBand(si++,'TRAIN & CREW DETAILS');
    row2('Train Number',incident.train_number,false);
    row2('Train Name',incident.train_name||'N/A',true);
    row2('Driver Name','N/A',false);
    row2('Driver Employee ID','N/A',true);
    row2('Assistant Driver','N/A',false);
    row2('Guard','N/A',true);
    row2('Train Speed (km/h)','N/A',false);
    row2('Train Direction','N/A',true);
    gap();

    // S4 SUPERVISION
    secBand(si++,'SUPERVISION DETAILS');
    row2('Lead Supervisor',incident.leadSupervisor?.name||'N/A',false);
    row2('Lead Supervisor Emp. ID',incident.leadSupervisor?.employee_id||'N/A',true);
    row2('Lead Supervisor Contact',incident.leadSupervisor?.phone||'N/A',false);
    row2('Supervisor',incident.created_by?.name||'N/A',true);
    row2('Supervisor Emp. ID',incident.created_by?.employee_id||'N/A',false);
    row2('Supervisor Contact',incident.created_by?.phone||'N/A',true);
    gap();

    // S5 RESOURCE DEPLOYMENT
    secBand(si++,'RESOURCE DEPLOYMENT');
    doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8.5).text('Total Operators Deployed: '+accLogs.length,mX,doc.y+3); doc.y+=16;
    const s5c=[{h:'#',w:28},{h:'Operator Name',w:105},{h:'Emp ID',w:65},{h:'Designation',w:80},{h:'Duty',w:55},{h:'Accepted',w:52},{h:'Arrived',w:52},{h:'Done',w:44.88}];
    tblHdr(s5c);
    if(accLogs.length===0){ const y=doc.y; doc.rect(mX,y,cW,18).fill('#fff').stroke(bdr); doc.font('Helvetica').fontSize(8).fillColor('#555').text('No operators deployed',mX,y+5,{width:cW,align:'center',lineBreak:false}); doc.y=y+18; }
    accLogs.forEach((l,i)=>tblRow(s5c,[(i+1).toString(),l.operator_id?.name||'Unknown',l.operator_id?.employee_id||'N/A','Operator','Response',l.accepted_at?new Date(l.accepted_at).toLocaleTimeString():'-',l.site_geofence_entered_at?new Date(l.site_geofence_entered_at).toLocaleTimeString():'-','-'],i));
    gap();

    // S6 CASUALTY
    secBand(si++,'CASUALTY & IMPACT REPORT');
    row2('People Injured','0',false); row2('People Deceased','0',true);
    row2('Passengers Affected','N/A',false); row2('Staff Injured','0',true);
    row2('Staff Deceased','0',false); row2('Track Block Duration','N/A',true);
    row2('Train Delays','N/A',false); row2('Property Damage','N/A',true);
    row2('Estimated Loss (Rs.)','N/A',false);
    gap();

    // S7 TIMELINE
    secBand(si++,'INCIDENT TIMELINE');
    doc.font('Helvetica').fontSize(8).fillColor('#555').text('Chronological sequence of events:',mX,doc.y+2); doc.y+=14;
    const s7c=[{h:'#',w:25},{h:'Event',w:130},{h:'Timestamp',w:95},{h:'Elapsed',w:75},{h:'Remarks',w:156.88}];
    tblHdr(s7c);
    const t0=new Date(incident.createdAt);
    const tlEvts=[];
    tlEvts.push({evt:'Incident Created',ts:incident.createdAt,rem:'Reported by supervisor'});
    if(logs.length>0 && logs[0].notified_at) tlEvts.push({evt:'Operators Notified',ts:logs[0].notified_at,rem:logs.length+' operators alerted'});
    if(accLogs.length>0 && accLogs[0].accepted_at) tlEvts.push({evt:'Operators Accepted',ts:accLogs[0].accepted_at,rem:accLogs.length+' accepted'});
    if(accLogs.length>0 && accLogs[0].art_dwell_confirmed_at) tlEvts.push({evt:'ART Arrived',ts:accLogs[0].art_dwell_confirmed_at,rem:'ART dwell confirmed'});
    if(accLogs.length>0 && accLogs[0].site_geofence_entered_at) tlEvts.push({evt:'Site Reached',ts:accLogs[0].site_geofence_entered_at,rem:'Geofence entered'});
    if(incident.resolved_at) tlEvts.push({evt:'Incident Resolved',ts:incident.resolved_at,rem:'Marked resolved'});
    tlEvts.forEach((t,i)=>{ if(!t.ts) return; const el=i===0?'0 min':Math.round((new Date(t.ts)-t0)/60000)+' min'; tblRow(s7c,[(i+1).toString(),t.evt,new Date(t.ts).toLocaleTimeString(),el,t.rem],i); });
    gap();

    // S7B OPERATOR RESPONSE LOGS
    secBand('7B','OPERATOR RESPONSE LOGS');
    // 7B.1 Acceptance
    const subH=(title)=>{ if(doc.y>710) doc.addPage(); const y=doc.y; doc.rect(mX,y,cW,18).fill('#4A72AA'); doc.fillColor('#fff').font('Helvetica-Bold').fontSize(9).text(e(title),mX+8,y+5,{lineBreak:false}); doc.y=y+18; };
    subH('7B.1 — Acceptance Log');
    const ac=[{h:'Operator',w:130},{h:'Notified At',w:90},{h:'Accepted At',w:90},{h:'Delay (min)',w:80},{h:'Status',w:91.88}];
    tblHdr(ac);
    if(logs.length===0){ const y=doc.y; doc.rect(mX,y,cW,18).fill('#fff').stroke(bdr); doc.font('Helvetica').fontSize(8).fillColor('#555').text('No log data',mX,y+5,{width:cW,align:'center',lineBreak:false}); doc.y=y+18; }
    logs.forEach((l,i)=>{
      if(doc.y>720) doc.addPage();
      const y=doc.y; let cx=mX; const delay=l.notified_at&&l.accepted_at?Math.round((new Date(l.accepted_at)-new Date(l.notified_at))/60000).toString():'-';
      doc.rect(mX,y,cW,18).fill(i%2===1?altBg:'#fff').stroke(bdr);
      const vals=[l.operator_id?.name||'Unknown',l.notified_at?new Date(l.notified_at).toLocaleTimeString():'-',l.accepted_at?new Date(l.accepted_at).toLocaleTimeString():'-',delay,l.acceptance_status||'PENDING'];
      vals.forEach((v,j)=>{
        if(j===4){ const c=v==='ACCEPTED'?grn:(v==='PENDING'?'#888':red); doc.fillColor(c).font('Helvetica-Bold').fontSize(7.5).text(v,cx+2,y+5,{width:ac[j].w-4,align:'center',lineBreak:false}); }
        else{ doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(e(v),cx+2,y+5,{width:ac[j].w-4,align:'center',lineBreak:false,ellipsis:true}); }
        cx+=ac[j].w;
      }); doc.y=y+18;
    });
    gap(6);

    // 7B.2 Attendance
    if (doc.y > 680) doc.addPage();
    subH('7B.2 — Attendance Log (ART)');
    const at=[{h:'Operator',w:130},{h:'Accepted At',w:90},{h:'ART Arrived',w:95},{h:'Duration (min)',w:80},{h:'Status',w:86.88}];
    tblHdr(at);
    if(accLogs.length===0){ const y=doc.y; doc.rect(mX,y,cW,18).fill('#fff').stroke(bdr); doc.font('Helvetica').fontSize(8).fillColor('#555').text('No attendance data',mX,y+5,{width:cW,align:'center',lineBreak:false}); doc.y=y+18; }
    accLogs.forEach((l,i)=>{
      if(doc.y>720) doc.addPage();
      const y=doc.y; let cx=mX; const dur=l.accepted_at&&l.art_dwell_confirmed_at?Math.round((new Date(l.art_dwell_confirmed_at)-new Date(l.accepted_at))/60000).toString():'-';
      const st=l.attendance_status==='PRESENT'?'PRESENT':'PENDING';
      doc.rect(mX,y,cW,18).fill(i%2===1?altBg:'#fff').stroke(bdr);
      const vals=[l.operator_id?.name||'Unknown',l.accepted_at?new Date(l.accepted_at).toLocaleTimeString():'-',l.art_dwell_confirmed_at?new Date(l.art_dwell_confirmed_at).toLocaleTimeString():'-',dur,st];
      vals.forEach((v,j)=>{
        if(j===4){ doc.fillColor(v==='PRESENT'?grn:'#888').font('Helvetica-Bold').fontSize(7.5).text(v,cx+2,y+5,{width:at[j].w-4,align:'center',lineBreak:false}); }
        else{ doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(e(v),cx+2,y+5,{width:at[j].w-4,align:'center',lineBreak:false,ellipsis:true}); }
        cx+=at[j].w;
      }); doc.y=y+18;
    });
    gap(6);

    // 7B.3 Response Time
    if (doc.y > 680) doc.addPage();
    subH('7B.3 — Response Time Log (Site)');
    const rt=[{h:'Operator',w:130},{h:'Accepted At',w:90},{h:'Site Arrived',w:95},{h:'Duration (min)',w:80},{h:'Status',w:86.88}];
    tblHdr(rt);
    if(accLogs.length===0){ const y=doc.y; doc.rect(mX,y,cW,18).fill('#fff').stroke(bdr); doc.font('Helvetica').fontSize(8).fillColor('#555').text('No response data',mX,y+5,{width:cW,align:'center',lineBreak:false}); doc.y=y+18; }
    accLogs.forEach((l,i)=>{
      if(doc.y>720) doc.addPage();
      const y=doc.y; let cx=mX; const dur=l.accepted_at&&l.site_geofence_entered_at?Math.round((new Date(l.site_geofence_entered_at)-new Date(l.accepted_at))/60000).toString():'-';
      const st=l.response_status==='REACHED'?'REACHED':'PENDING';
      doc.rect(mX,y,cW,18).fill(i%2===1?altBg:'#fff').stroke(bdr);
      const vals=[l.operator_id?.name||'Unknown',l.accepted_at?new Date(l.accepted_at).toLocaleTimeString():'-',l.site_geofence_entered_at?new Date(l.site_geofence_entered_at).toLocaleTimeString():'-',dur,st];
      vals.forEach((v,j)=>{
        if(j===4){ doc.fillColor(v==='REACHED'?grn:'#888').font('Helvetica-Bold').fontSize(7.5).text(v,cx+2,y+5,{width:rt[j].w-4,align:'center',lineBreak:false}); }
        else{ doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(e(v),cx+2,y+5,{width:rt[j].w-4,align:'center',lineBreak:false,ellipsis:true}); }
        cx+=rt[j].w;
      }); doc.y=y+18;
    });
    gap();

    // S8 LOCATION
    secBand(si++,'LOCATION & ROUTE ANALYSIS');
    row2('Incident Location','Lat: '+incident.latitude+', Lng: '+incident.longitude,false);
    row2('Incident GPS',incident.latitude+', '+incident.longitude,true);
    row2('ART Train Location','N/A',false); row2('ART Train GPS','N/A',true);
    row2('Distance Travelled','N/A',false); row2('Travel Time','N/A',true);
    gap(6);
    const mY = doc.y;
    doc.rect(mX,mY,cW,40).fill(lblBg).stroke(bdr);
    doc.fillColor('#555').font('Helvetica-Oblique').fontSize(9).text('Route map image not available — GPS coordinates recorded above.',mX+10,mY+14,{width:cW-20,align:'center',lineBreak:false});
    doc.y=mY+40; gap();

    // S9 EVIDENCE SUMMARY
    secBand(si++,'EVIDENCE SUMMARY');
    const ev9=[{h:'Evidence Type',w:160},{h:'Count',w:80},{h:'Integrity Status',w:241.88}];
    tblHdr(ev9);
    [['Photographs',images.length,'VERIFIED'],['Videos',videos.length,'VERIFIED'],['Audio Recordings',audios.length,'VERIFIED'],['Text Statements',uTexts.length,'VERIFIED']].forEach((r,i)=>{
      const y=doc.y; let cx=mX; doc.rect(mX,y,cW,18).fill(i%2===1?altBg:'#fff').stroke(bdr);
      doc.font('Helvetica').fontSize(8).fillColor('#1a1a1a');
      doc.text(r[0],cx+4,y+5,{width:ev9[0].w-8,lineBreak:false}); cx+=ev9[0].w;
      doc.text(String(r[1]),cx+4,y+5,{width:ev9[1].w-8,align:'center',lineBreak:false}); cx+=ev9[1].w;
      doc.fillColor(grn).font('Helvetica-Bold').text(r[2],cx+4,y+5,{width:ev9[2].w-8,lineBreak:false});
      doc.y=y+18;
    });
    gap(6);
    doc.font('Helvetica-Bold').fontSize(8).fillColor(blue).text('Overall Evidence Integrity: ',mX,doc.y,{continued:true}); doc.fillColor(grn).text('VERIFIED'); doc.y+=4; gap();

    // S10 TEXT STATEMENTS
    secBand(si++,'TEXT STATEMENTS');
    if(uTexts.length===0){ doc.font('Helvetica').fontSize(9).fillColor('#555').text('No text statements recorded.',mX,doc.y+4); doc.y+=18; }
    uTexts.forEach((txt,i)=>{
      if(doc.y>640) doc.addPage();
      const y=doc.y;
      doc.rect(mX,y,cW,18).fill(blue);
      doc.fillColor('#fff').font('Helvetica-Bold').fontSize(9).text('TEXT STATEMENT #'+(i+1),mX+8,y+5,{lineBreak:false});
      doc.rect(mX,y+18,95,18).fill(lblBg).stroke(bdr); doc.rect(mX+95,y+18,cW-95,18).fill('#fff').stroke(bdr);
      doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('Operator',mX+4,y+23,{lineBreak:false});
      doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8).text(e(txt.operator_name||'Unknown'),mX+100,y+23,{width:cW-104,lineBreak:false,ellipsis:true});
      doc.rect(mX,y+36,95,18).fill(lblBg).stroke(bdr); doc.rect(mX+95,y+36,cW-95,18).fill(altBg).stroke(bdr);
      doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('Timestamp',mX+4,y+41,{lineBreak:false});
      doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8).text(new Date(txt.timestamp).toLocaleString(),mX+100,y+41,{width:cW-104,lineBreak:false});
      doc.rect(mX,y+54,95,18).fill(lblBg).stroke(bdr); doc.rect(mX+95,y+54,cW-95,18).fill('#fff').stroke(bdr);
      doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('GPS',mX+4,y+59,{lineBreak:false});
      doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8).text((txt.geostamp?.lat||0)+', '+(txt.geostamp?.lng||0),mX+100,y+59,{width:cW-104,lineBreak:false});
      const content = e(txt.text_content);
      const stmtH=Math.max(36,doc.heightOfString('"'+content+'"',{width:cW-20,font:'Helvetica-Oblique',size:9})+14);
      doc.rect(mX,y+72,cW,stmtH).fill('#FAFDF5').stroke(bdr);
      doc.fillColor('#1a1a1a').font('Helvetica-Oblique').fontSize(9).text('"'+content+'"',mX+8,y+79,{width:cW-16});
      doc.y=y+72+stmtH+8;
    });
    gap();

    // S11 PHOTOGRAPHIC EVIDENCE
    secBand(si++,'PHOTOGRAPHIC EVIDENCE');
    if(images.length===0){ doc.font('Helvetica').fontSize(9).fillColor('#555').text('No photographic evidence recorded.',mX,doc.y+4); doc.y+=18; gap(); }
    else {
      for(let i=0;i<images.length;i++){
        const img=images[i];
        if(doc.y>620){ doc.addPage(); }
        const yS=doc.y; const imgW=220; const metaW=cW-imgW;
        doc.rect(mX,yS,imgW,170).fill('#ffffff').stroke(bdr);
        doc.rect(mX+imgW,yS,metaW,170).fill(lblBg).stroke(bdr);
        let buf=null;
        if(img.url){ try{ buf=await dlImg(img.url); } catch(e){} }
        if(buf){ try{ doc.image(buf,mX+4,yS+4,{fit:[imgW-8,162],align:'center',valign:'center'}); } catch(e){ doc.fillColor(red).fontSize(8).text('Image load error',mX+8,yS+80,{lineBreak:false}); } }
        else{ doc.rect(mX+4,yS+4,imgW-8,162).fill('#eee'); doc.fillColor('#999').font('Helvetica').fontSize(9).text('No Image Available',mX+8,yS+80,{lineBreak:false}); }
        const rx=mX+imgW+8; let ry=yS+14;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('Photo #'+(i+1),rx,ry,{lineBreak:false}); ry+=16;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5).text('Timestamp:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(img.timestamp?new Date(img.timestamp).toLocaleString():'N/A',rx+55,ry,{width:metaW-65,lineBreak:false,ellipsis:true}); ry+=16;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5).text('GPS:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text((img.geostamp?.lat||'N/A')+', '+(img.geostamp?.lng||'N/A'),rx+28,ry,{width:metaW-38,lineBreak:false,ellipsis:true}); ry+=16;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5).text('Device:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(e(img.device_info?.model||'N/A'),rx+42,ry,{width:metaW-52,lineBreak:false,ellipsis:true}); ry+=16;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5).text('Captured By:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7.5).text(e(img.operator_name||'N/A'),rx+62,ry,{width:metaW-72,lineBreak:false,ellipsis:true});
        doc.y=yS+170+10;
      }
    }
    gap();

    // S12 VIDEO EVIDENCE
    secBand(si++,'VIDEO EVIDENCE');
    if(videos.length===0){ doc.font('Helvetica').fontSize(9).fillColor('#555').text('No video evidence recorded.',mX,doc.y+4); doc.y+=18; gap(); }
    else{
      for(let i=0;i<videos.length;i++){
        const vid=videos[i]; if(doc.y>620) doc.addPage();
        const yS=doc.y;
        doc.rect(mX,yS,cW,22).fill(blue); doc.fillColor('#fff').font('Helvetica-Bold').fontSize(9).text('VIDEO EVIDENCE #'+(i+1),mX+8,yS+6,{lineBreak:false});
        const cY = yS+22;
        const thW=130; const metaW2=cW-thW; const blkH=160;
        doc.rect(mX,cY,thW,blkH).fill('#EAF0FB').stroke(bdr);
        doc.rect(mX+5,cY+5,thW-10,blkH-55).fill('#D0DCEE');
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(12).text('[PLAY]',mX+40,cY+45,{lineBreak:false});
        doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8).text('VIDEO #'+(i+1),mX+8,cY+110,{lineBreak:false});
        doc.rect(mX+thW,cY,metaW2,80).fill('#fff').stroke(bdr);
        doc.rect(mX+thW,cY+80,metaW2,blkH-80).fill(lblBg).stroke(bdr);
        const rx=mX+thW+8; let ry=cY+10;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5);
        doc.text('Duration:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text('N/A',rx+48,ry,{width:metaW2-56,lineBreak:false}); ry+=14;
        doc.fillColor(blue).font('Helvetica-Bold').text('Timestamp:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text(new Date(vid.timestamp).toLocaleString(),rx+55,ry,{width:metaW2-63,lineBreak:false}); ry+=14;
        doc.fillColor(blue).font('Helvetica-Bold').text('GPS:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text((vid.geostamp?.lat||0)+', '+(vid.geostamp?.lng||0),rx+28,ry,{width:metaW2-36,lineBreak:false}); ry+=14;
        doc.fillColor(blue).font('Helvetica-Bold').text('Captured By:',rx,ry,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text(e(vid.operator_name||'N/A'),rx+62,ry,{width:metaW2-70,lineBreak:false,ellipsis:true});
        if(vid.url){
          const qrBuf=await QRCode.toBuffer(vid.url,{type:'png',margin:1,width:70});
          const qrY=cY+85;
          doc.image(qrBuf,rx,qrY,{width:70}); 
          doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('SCAN TO VIEW',rx+75,qrY+12,{lineBreak:false});
          doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7).text('If QR not available:',rx+75,qrY+26,{lineBreak:false});
          doc.fillColor('blue').text(vid.url,rx+75,qrY+36,{width:metaW2-85,link:vid.url,lineBreak:false,ellipsis:true});
        }
        doc.y=cY+blkH+12;
      }
    }
    gap();

    // S13 AUDIO EVIDENCE
    secBand(si++,'AUDIO EVIDENCE');
    if(audios.length===0){ doc.font('Helvetica').fontSize(9).fillColor('#555').text('No audio evidence recorded.',mX,doc.y+4); doc.y+=18; gap(); }
    else{
      for(let i=0;i<audios.length;i++){
        const aud=audios[i]; if(doc.y>620) doc.addPage();
        const yS=doc.y;
        doc.rect(mX,yS,cW,22).fill('#4A72AA'); doc.fillColor('#fff').font('Helvetica-Bold').fontSize(9).text('AUDIO RECORDING #'+(i+1),mX+8,yS+6,{lineBreak:false});
        const cY = yS+22;
        doc.rect(mX,cY,cW,36).fill('#fff').stroke(bdr);
        let infoY=cY+6;
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(7.5).text('Duration:',mX+4,infoY,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text('N/A',mX+48,infoY,{lineBreak:false});
        doc.fillColor(blue).font('Helvetica-Bold').text('Timestamp:',mX+110,infoY,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text(new Date(aud.timestamp).toLocaleString(),mX+165,infoY,{lineBreak:false});
        infoY+=14;
        doc.fillColor(blue).font('Helvetica-Bold').text('Captured By:',mX+4,infoY,{lineBreak:false}); doc.fillColor('#1a1a1a').font('Helvetica').text(e(aud.operator_name||'N/A'),mX+65,infoY,{lineBreak:false,ellipsis:true,width:180});
        
        const bY=cY+36;
        doc.rect(mX,bY,cW,22).fill(lblBg).stroke(bdr);
        doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('Transcript:',mX+4,bY+6,{continued:true}); doc.fillColor('#1a1a1a').font('Helvetica-Oblique').text(' No transcript available',{lineBreak:false});
        
        const qrY = bY+22;
        const qrH=100;
        doc.rect(mX,qrY,150,qrH).fill('#ffffff').stroke(bdr); doc.rect(mX+150,qrY,cW-150,qrH).fill('#fff').stroke(bdr);
        if(aud.url){
          const qrBuf=await QRCode.toBuffer(aud.url,{type:'png',margin:1,width:80});
          doc.image(qrBuf,mX+10,qrY+10,{width:80});
          doc.fillColor(blue).font('Helvetica-Bold').fontSize(8).text('SCAN TO LISTEN',mX+160,qrY+20,{lineBreak:false});
          doc.fillColor('#1a1a1a').font('Helvetica').fontSize(7).text('If QR not available:',mX+160,qrY+35,{lineBreak:false});
          doc.fillColor('blue').fontSize(7).text(aud.url,mX+160,qrY+48,{width:cW-170,link:aud.url,lineBreak:false,ellipsis:true});
        }
        doc.y=qrY+qrH+10;
      }
    }
    gap();

    // S14 ROOT CAUSE
    secBand(si++,'ROOT CAUSE ANALYSIS');
    row2('Root Cause','Pending detailed analysis',false);
    row2('Contributing Factors','N/A',true);
    row2('Risk Assessment','N/A',false);
    gap();

    // S15 CORRECTIVE ACTIONS
    secBand(si++,'CORRECTIVE ACTIONS');
    row2('Immediate Actions','Site secured, response team deployed',false);
    row2('Temporary Actions','N/A',true);
    row2('Permanent Actions','N/A',false);
    gap();

    // S16 APPROVALS
    if(doc.y>630) doc.addPage();
    secBand(si++,'APPROVALS & SIGN-OFF');
    const cW3=cW/3;
    const hY=doc.y;
    [0,1,2].forEach(j=>{ doc.rect(mX+j*cW3,hY,cW3,18).fill(lblBg).stroke(bdr); });
    doc.fillColor(blue).font('Helvetica-Bold').fontSize(8);
    doc.text('Prepared By',mX+4,hY+5,{width:cW3-8,lineBreak:false});
    doc.text('Supervisor Approval',mX+cW3+4,hY+5,{width:cW3-8,lineBreak:false});
    doc.text('Lead Supervisor Approval',mX+cW3*2+4,hY+5,{width:cW3-8,lineBreak:false});
    doc.y=hY+18;
    const sY=doc.y;
    [0,1,2].forEach(j=>{ doc.rect(mX+j*cW3,sY,cW3,70).fill('#fff').stroke(bdr); });
    doc.fillColor('#1a1a1a').font('Helvetica').fontSize(8);
    doc.text('Name: '+e(incident.created_by?.name||'Unknown'),mX+6,sY+8,{width:cW3-12,lineBreak:false,ellipsis:true});
    doc.text('Digital Signature:',mX+6,sY+22,{lineBreak:false});
    doc.text('________________',mX+6,sY+36,{lineBreak:false});
    doc.text('Name: '+e(incident.created_by?.name||'Unknown'),mX+cW3+6,sY+8,{width:cW3-12,lineBreak:false,ellipsis:true});
    doc.text('Digital Signature:',mX+cW3+6,sY+22,{lineBreak:false});
    doc.text('________________',mX+cW3+6,sY+36,{lineBreak:false});
    doc.text('Name: '+e(incident.leadSupervisor?.name||'Pending'),mX+cW3*2+6,sY+8,{width:cW3-12,lineBreak:false,ellipsis:true});
    doc.text('Digital Signature:',mX+cW3*2+6,sY+22,{lineBreak:false});
    doc.text('________________',mX+cW3*2+6,sY+36,{lineBreak:false});
    doc.y=sY+80;
    doc.font('Helvetica').fontSize(8).fillColor('#555');
    doc.text('Report Generated: '+new Date().toLocaleString(),mX,doc.y,{align:'center',width:cW});
    doc.text('Digital Verification ID: '+(incident.accessToken||String(incident._id)),mX,doc.y+12,{align:'center',width:cW});

    hdrFtr();
    doc.end();
   } catch(e){ reject(e); }
  });
}

module.exports = { generatePDF };
