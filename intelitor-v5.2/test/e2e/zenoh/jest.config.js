// =============================================================================
// Zenoh Interface E2E Test Configuration
// =============================================================================
// STAMP: SC-TEST-001, SC-BRIDGE-*, SC-SYNC-*
// 19 Zenoh Publishers + Subscribers + Bridges
// =============================================================================

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['**/*.test.ts'],
  setupFilesAfterEnv: ['./helpers/setup.ts'],
  testTimeout: 60000, // Longer timeout for Zenoh operations
  verbose: true,
  collectCoverage: true,
  coverageDirectory: '../../../data/coverage/zenoh',
  coverageReporters: ['text', 'lcov', 'html'],
  reporters: [
    'default',
    ['jest-html-reporter', {
      pageTitle: 'Indrajaal Zenoh E2E Test Report',
      outputPath: '../../../data/reports/zenoh-e2e-report.html',
      includeFailureMsg: true,
      includeSuiteFailure: true
    }]
  ],
  globals: {
    'ts-jest': {
      tsconfig: '../tsconfig.json'
    }
  }
};
