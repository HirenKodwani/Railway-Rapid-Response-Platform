const sanitizePhone = (value) => {
  if (!value) return value;
  let sanitized = value.toString().replace(/[\s-]/g, '');
  if (sanitized.startsWith('+91')) {
    sanitized = sanitized.substring(3);
  } else if (sanitized.startsWith('0') && sanitized.length === 11) {
    sanitized = sanitized.substring(1);
  }
  return sanitized;
};

module.exports = { sanitizePhone };
