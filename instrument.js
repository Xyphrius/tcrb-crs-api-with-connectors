// Import with 'import * as Sentry from '@sentry/node' if you are using ESM
const Sentry = require('@sentry/node');

Sentry.init({
  dsn: 'https://fcfe63f681947515f9f00824e7986ef07e04509866365550592.ingest.us.sentry.io/4508986636555059',

  // Setting this option to true will send default PII data to Sentry.
  // For example, automatic IP address collection on events
  sendDefaultPii: true,
});
