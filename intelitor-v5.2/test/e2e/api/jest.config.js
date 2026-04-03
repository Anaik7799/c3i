// =============================================================================
// REST API E2E Test Configuration
// =============================================================================
// STAMP: SC-TEST-001
// 302+ REST API Endpoints Coverage
// =============================================================================

module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['**/*.test.ts'],
  setupFilesAfterEnv: ['./helpers/setup.ts'],
  testTimeout: 30000,
  verbose: true,
  collectCoverage: true,
  coverageDirectory: '../../../data/coverage/api',
  coverageReporters: ['text', 'lcov', 'html'],
  reporters: [
    'default',
    ['jest-html-reporter', {
      pageTitle: 'Indrajaal REST API E2E Test Report',
      outputPath: '../../../data/reports/api-e2e-report.html',
      includeFailureMsg: true,
      includeSuiteFailure: true
    }]
  ],
  globals: {
    'ts-jest': {
      tsconfig: '../tsconfig.json'
    }
  },
  moduleNameMapper: {
    '@helpers/(.*)': '<rootDir>/helpers/$1',
    '@tests/(.*)': '<rootDir>/tests/$1'
  }
};
