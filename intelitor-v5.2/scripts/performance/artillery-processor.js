/**
 * Artillery.io Processor for Intelitor Performance Testing
 *
 * Purpose: Provide helper functions for realistic test data generation
 *          and dynamic behavior during load testing.
 *
 * STAMP Compliance: SC-PRF-049, SC-PRF-050, SC-PRF-051
 * Version: 2.0.0 (Updated for 450 RPS target)
 * Updated: 2025-12-19
 */

'use strict';

const crypto = require('crypto');

// ============================================================================
// Test Data Pools for Realistic Scenarios
// ============================================================================

const eventTypes = [
  'intrusion', 'motion', 'door', 'fire', 'panic', 'tamper',
  'glass_break', 'duress', 'medical', 'environmental',
  'battery_low', 'communication_failure', 'supervision'
];

const severityLevels = ['low', 'medium', 'high', 'critical'];

const resolutionTypes = [
  'false_alarm', 'resolved', 'maintenance_required',
  'user_error', 'system_test', 'authorized_access',
  'automatic_restore', 'escalated'
];

// Simulated entity IDs for performance testing
const deviceIds = Array.from({ length: 500 }, (_, i) =>
  `device-${String(i + 1).padStart(6, '0')}-perf`
);

const siteIds = Array.from({ length: 100 }, (_, i) =>
  `site-${String(i + 1).padStart(4, '0')}-perf`
);

const userIds = Array.from({ length: 200 }, (_, i) =>
  `user-${String(i + 1).padStart(5, '0')}-perf`
);

const zoneIds = Array.from({ length: 50 }, (_, i) =>
  `zone-${String(i + 1).padStart(3, '0')}-perf`
);

// ============================================================================
// Random Data Generator Functions (for Artillery scenarios)
// ============================================================================

function randomEventType(context, events, done) {
  const eventType = eventTypes[Math.floor(Math.random() * eventTypes.length)];
  context.vars['eventType'] = eventType;
  return done();
}

function randomSeverity(context, events, done) {
  // Weighted distribution: more low/medium, fewer critical
  // Matches real-world alarm patterns
  const weights = [45, 35, 15, 5]; // low, medium, high, critical
  const random = Math.random() * 100;
  let cumulative = 0;

  for (let i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (random <= cumulative) {
      context.vars['severity'] = severityLevels[i];
      break;
    }
  }

  return done();
}

function randomDeviceId(context, events, done) {
  const deviceId = deviceIds[Math.floor(Math.random() * deviceIds.length)];
  context.vars['deviceId'] = deviceId;
  return done();
}

function randomSiteId(context, events, done) {
  const siteId = siteIds[Math.floor(Math.random() * siteIds.length)];
  context.vars['siteId'] = siteId;
  return done();
}

function randomUserId(context, events, done) {
  const userId = userIds[Math.floor(Math.random() * userIds.length)];
  context.vars['userId'] = userId;
  return done();
}

function randomZoneId(context, events, done) {
  const zoneId = zoneIds[Math.floor(Math.random() * zoneIds.length)];
  context.vars['zoneId'] = zoneId;
  return done();
}

// ============================================================================
// Decision Logic Functions (for realistic test behavior)
// ============================================================================

function shouldResolveAlarm(context, events, done) {
  // 30% chance to resolve an alarm during the test
  context.vars['shouldResolve'] = Math.random() < 0.3;
  return done();
}

function shouldUpdateDevice(context, events, done) {
  // 10% chance to update a device during the test
  context.vars['shouldUpdate'] = Math.random() < 0.1;
  return done();
}

function shouldEscalate(context, events, done) {
  // 5% chance to escalate an alarm
  context.vars['shouldEscalate'] = Math.random() < 0.05;
  return done();
}

// ============================================================================
// Performance Tracking Functions
// ============================================================================

function trackAlarmProcessingTime(requestParams, response, context, ee, next) {
  if (requestParams.url.includes('/alarms') && requestParams.method === 'POST') {
    const processingTime = Date.now() - (context.vars['$timestamp'] || Date.now());
    ee.emit('customStat', { stat: 'alarm_processing_time_ms', value: processingTime });

    // Log slow responses for debugging
    if (processingTime > 1000) {
      console.log(`[WARN] Slow alarm processing: ${processingTime}ms`);
    }
  }

  return next();
}

function trackEndpointPerformance(requestParams, response, context, ee, next) {
  const endpoint = requestParams.url.split('?')[0].replace(/\/api\/v1\//, '');
  const endpointKey = endpoint.replace(/\//g, '_').replace(/-/g, '_');

  if (response.timings && response.timings.response) {
    ee.emit('customStat', {
      stat: `endpoint_${endpointKey}_ms`,
      value: response.timings.response
    });
  }

  return next();
}

// ============================================================================
// Error Handling and Logging Functions
// ============================================================================

function logErrors(requestParams, response, context, ee, next) {
  if (response.statusCode >= 400) {
    console.log(`[ERROR] ${response.statusCode} on ${requestParams.method} ${requestParams.url}`);

    if (response.statusCode >= 500) {
      ee.emit('customStat', { stat: 'server_errors', value: 1 });
    } else {
      ee.emit('customStat', { stat: 'client_errors', value: 1 });
    }
  }

  return next();
}

function validateResponse(requestParams, response, context, ee, next) {
  try {
    if (response.headers['content-type']?.includes('application/json')) {
      const data = JSON.parse(response.body);

      // Validate alarm creation response
      if (requestParams.url.includes('/alarms') && requestParams.method === 'POST') {
        if (!data.id) {
          ee.emit('customStat', { stat: 'invalid_alarm_response', value: 1 });
          console.log('[WARN] Invalid alarm response: missing id');
        }
      }

      ee.emit('customStat', { stat: 'valid_responses', value: 1 });
    }
  } catch (error) {
    ee.emit('customStat', { stat: 'json_parse_errors', value: 1 });
  }

  return next();
}

// ============================================================================
// Metrics Collection Functions
// ============================================================================

function collectResponseMetrics(requestParams, response, context, ee, next) {
  // Track response sizes
  const contentLength = response.headers['content-length'];
  if (contentLength) {
    ee.emit('customStat', { stat: 'response_size_bytes', value: parseInt(contentLength) });
  }

  // Track successful vs failed requests
  if (response.statusCode >= 200 && response.statusCode < 300) {
    ee.emit('customStat', { stat: 'successful_requests', value: 1 });
  }

  return next();
}

// ============================================================================
// Realistic Behavior Simulation Functions
// ============================================================================

function calculateThinkTime(context, events, done) {
  // Realistic think times based on operation type
  let baseThinkTime = Math.random() * 3000 + 500; // 0.5-3.5 seconds

  if (context.vars.lastOperation === 'alarm_creation') {
    baseThinkTime *= 1.5; // More time after creating an alarm
  } else if (context.vars.lastOperation === 'dashboard_view') {
    baseThinkTime *= 0.5; // Quick navigation between dashboard views
  }

  context.vars['thinkTime'] = Math.floor(baseThinkTime);
  return done();
}

function generateRealisticAlarmData(context, events, done) {
  const now = new Date();
  const hour = now.getHours();

  let eventType, severity;

  if (hour >= 9 && hour <= 17) {
    // Business hours: more door/access events
    eventType = Math.random() < 0.6 ? 'door' :
               Math.random() < 0.8 ? 'motion' : 'intrusion';
    severity = Math.random() < 0.7 ? 'low' :
              Math.random() < 0.9 ? 'medium' : 'high';
  } else {
    // After hours: more security-focused events
    eventType = Math.random() < 0.4 ? 'intrusion' :
               Math.random() < 0.7 ? 'motion' : 'door';
    severity = Math.random() < 0.4 ? 'low' :
              Math.random() < 0.7 ? 'medium' :
              Math.random() < 0.9 ? 'high' : 'critical';
  }

  context.vars['realisticEventType'] = eventType;
  context.vars['realisticSeverity'] = severity;

  return done();
}

function initializeUserSession(context, events, done) {
  context.vars['sessionId'] = crypto.randomUUID();
  context.vars['userRole'] = ['admin', 'operator', 'viewer'][Math.floor(Math.random() * 3)];
  context.vars['sessionStartTime'] = Date.now();

  return done();
}

// ============================================================================
// Load Pattern Generation Functions
// ============================================================================

function generateLoadPattern(context, events, done) {
  const now = new Date();
  const hour = now.getHours();
  const dayOfWeek = now.getDay();

  let arrivalRateMultiplier = 1.0;

  // Weekend reduction
  if (dayOfWeek === 0 || dayOfWeek === 6) {
    arrivalRateMultiplier *= 0.3;
  }

  // Time of day patterns
  if (hour >= 8 && hour <= 18) {
    arrivalRateMultiplier *= 1.5; // Peak business hours
  } else if (hour >= 19 && hour <= 22) {
    arrivalRateMultiplier *= 0.8; // Evening
  } else {
    arrivalRateMultiplier *= 0.2; // Night/early morning
  }

  context.vars['arrivalRateMultiplier'] = arrivalRateMultiplier;
  return done();
}

// ============================================================================
// Template Helper Functions
// ============================================================================

function randomString() {
  return crypto.randomBytes(8).toString('hex');
}

function timestamp() {
  return Date.now();
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function uuid() {
  return crypto.randomUUID();
}

// ============================================================================
// Module Exports
// ============================================================================

module.exports = {
  // Random data generators
  randomEventType,
  randomSeverity,
  randomDeviceId,
  randomSiteId,
  randomUserId,
  randomZoneId,

  // Decision logic
  shouldResolveAlarm,
  shouldUpdateDevice,
  shouldEscalate,

  // Performance tracking
  trackAlarmProcessingTime,
  trackEndpointPerformance,

  // Error handling
  logErrors,
  validateResponse,

  // Metrics collection
  collectResponseMetrics,

  // Realistic behavior
  calculateThinkTime,
  generateRealisticAlarmData,
  initializeUserSession,
  generateLoadPattern,

  // Template helpers
  randomString,
  timestamp,
  randomInt,
  uuid,

  // Artillery template-accessible helpers
  $randomString: randomString,
  $timestamp: timestamp,
  $randomInt: randomInt,
  $uuid: uuid
};
