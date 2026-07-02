function parseAllowedOrigins(value) {
  return (value ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function createCorsOptions(allowedOriginsValue) {
  const allowedOrigins = parseAllowedOrigins(allowedOriginsValue);

  if (allowedOrigins.length === 0) {
    return {};
  }

  return {
    origin(origin, callback) {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error('Origem nao permitida pelo CORS.'));
    },
  };
}

module.exports = {
  createCorsOptions,
  parseAllowedOrigins,
};
