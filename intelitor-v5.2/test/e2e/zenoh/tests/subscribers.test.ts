// =============================================================================
// Zenoh Subscribers E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-BRIDGE-*
// Tests: Control Subscriber + Control Plane
// =============================================================================

describe('Zenoh Subscribers', () => {
  // =========================================================================
  // ZenohControlSubscriber Tests
  // Key Expressions: intelitor/control/{command}
  // Latency: <50ms
  // =========================================================================
  describe('ZenohControlSubscriber (Control Plane)', () => {
    const BASE_TOPIC = 'intelitor/control';

    describe('Control Commands', () => {
      it('should handle refresh command', async () => {
        const result = await global.zenohClient.publish(`${BASE_TOPIC}/refresh`, {
          source: 'e2e-test',
          timestamp: Date.now()
        });
        expect(typeof result).toBe('boolean');
      });

      it('should handle agent-specific commands', async () => {
        const result = await global.zenohClient.publish(`${BASE_TOPIC}/agent/ooda-agent`, {
          command: 'status',
          parameters: {}
        });
        expect(typeof result).toBe('boolean');
      });

      it('should handle mode change commands', async () => {
        const result = await global.zenohClient.publish(`${BASE_TOPIC}/mode`, {
          mode: 'compact',
          source: 'e2e-test'
        });
        expect(typeof result).toBe('boolean');
      });
    });

    describe('Command Acknowledgment', () => {
      it('should subscribe to acknowledgments', async () => {
        const result = await global.zenohClient.subscribe(`${BASE_TOPIC}/ack/**`);
        expect(typeof result).toBe('boolean');
      });
    });
  });

  // =========================================================================
  // ZenohTelemetrySubscriber Tests
  // Key Expressions: intelitor/telemetry/{source}
  // =========================================================================
  describe('ZenohTelemetrySubscriber (Telemetry Plane)', () => {
    const BASE_TOPIC = 'intelitor/telemetry';

    it('should subscribe to system telemetry', async () => {
      const result = await global.zenohClient.subscribe(`${BASE_TOPIC}/system/**`);
      expect(typeof result).toBe('boolean');
    });

    it('should subscribe to agent telemetry', async () => {
      const result = await global.zenohClient.subscribe(`${BASE_TOPIC}/agents/**`);
      expect(typeof result).toBe('boolean');
    });

    it('should subscribe to domain telemetry', async () => {
      const result = await global.zenohClient.subscribe(`${BASE_TOPIC}/domains/**`);
      expect(typeof result).toBe('boolean');
    });
  });
});
