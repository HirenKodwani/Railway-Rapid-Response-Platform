const QRCode = require('qrcode');

async function generateQRBuffer(url) {
  try {
    return await QRCode.toBuffer(url, {
      type: 'png', width: 200, margin: 1,
      color: { dark: '#1B2A4A', light: '#FFFFFF' },
    });
  } catch (err) {
    console.error('[qrGenerator] Failed:', err.message);
    return null;
  }
}

module.exports = { generateQRBuffer };
