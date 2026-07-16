const axios = require('axios');

async function downloadImageBuffer(url) {
  try {
    const response = await axios.get(url, { responseType: 'arraybuffer', timeout: 15000 });
    return Buffer.from(response.data);
  } catch (err) {
    console.error('[imageDownloader] Failed:', url, err.message);
    return null;
  }
}

function toPdfSafeUrl(url, width = 500) {
  if (!url) return url;
  const i = url.indexOf('/upload/');
  if (i !== -1) return url.slice(0, i + 8) + `w_${width},f_jpg,q_auto/` + url.slice(i + 8);
  return url;
}

module.exports = { downloadImageBuffer, toPdfSafeUrl };
