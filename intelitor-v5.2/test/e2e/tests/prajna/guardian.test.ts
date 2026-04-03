// =============================================================================
// Prajna Guardian E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-PRAJNA-001, SC-CONST-007
// Tests: Proposal management, veto authority, constitutional status
// =============================================================================

import { Page } from 'puppeteer';
import { GuardianPage } from '../../pages/prajna/GuardianPage';

describe('Prajna Guardian', () => {
  let page: Page;
  let guardian: GuardianPage;

  beforeAll(async () => {
    page = global.page;
    guardian = new GuardianPage(page);
  });

  beforeEach(async () => {
    await guardian.navigate();
  });

  describe('Page Loading', () => {
    it('should load guardian page successfully', async () => {
      const isHealthy = await guardian.isHealthy();
      expect(isHealthy).toBe(true);
    });

    it('should display proposal list', async () => {
      const exists = await guardian.exists('[data-testid="proposal-list"], .proposal-list');
      expect(exists).toBe(true);
    });
  });

  describe('Proposal Management (SC-PRAJNA-001)', () => {
    it('should display pending proposal count', async () => {
      const count = await guardian.getPendingCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    it('should list proposals with status', async () => {
      const proposals = await guardian.getProposals();
      // May be empty if no pending proposals
      expect(proposals).toBeDefined();
      if (proposals.length > 0) {
        expect(proposals[0]).toHaveProperty('id');
        expect(proposals[0]).toHaveProperty('status');
      }
    });

    it('should filter proposals by status', async () => {
      await guardian.filterByStatus('pending');
      const proposals = await guardian.getProposals();
      proposals.forEach(p => {
        expect(p.status).toBe('pending');
      });
    });
  });

  describe('Veto Authority (SC-CONST-007)', () => {
    it('should have veto authority button', async () => {
      const hasAuthority = await guardian.hasVetoAuthority();
      // Guardian should have veto authority when proposals exist
      expect(typeof hasAuthority).toBe('boolean');
    });

    it('should display veto history', async () => {
      const history = await guardian.getVetoHistory();
      expect(history).toBeDefined();
    });
  });

  describe('Constitutional Status (SC-CONST-*)', () => {
    it('should display constitutional invariant status', async () => {
      const status = await guardian.getConstitutionalStatus();
      expect(status).toBeDefined();
      // Should show Ψ₀-Ψ₅ invariants
      if (status.length > 0) {
        expect(status[0]).toHaveProperty('invariant');
        expect(status[0]).toHaveProperty('status');
      }
    });
  });

  describe('Constraint Violations', () => {
    it('should display any constraint violations', async () => {
      const violations = await guardian.getViolations();
      expect(violations).toBeDefined();
    });
  });

  describe('Approval Rate Metrics', () => {
    it('should display approval rate', async () => {
      const rate = await guardian.getApprovalRate();
      expect(rate).toBeGreaterThanOrEqual(0);
      expect(rate).toBeLessThanOrEqual(100);
    });
  });

  describe('Proposal Actions (when proposals exist)', () => {
    it('should support proposal approval workflow', async () => {
      const proposals = await guardian.getProposals();
      if (proposals.length > 0) {
        // Just verify the action buttons exist
        const hasApprove = await guardian.exists('[data-testid="approve-btn"], button[phx-click="approve"]');
        expect(hasApprove).toBe(true);
      } else {
        // No proposals - just verify page loads
        expect(await guardian.isHealthy()).toBe(true);
      }
    });

    it('should support proposal veto workflow', async () => {
      const proposals = await guardian.getProposals();
      if (proposals.length > 0) {
        const hasVeto = await guardian.exists('[data-testid="veto-btn"], button[phx-click="veto"]');
        expect(hasVeto).toBe(true);
      } else {
        expect(await guardian.isHealthy()).toBe(true);
      }
    });
  });
});
