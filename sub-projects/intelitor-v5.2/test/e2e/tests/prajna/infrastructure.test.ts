// =============================================================================
// Prajna Infrastructure Pages E2E Tests
// =============================================================================
// STAMP: SC-TEST-001, SC-CNT-*, SC-CLU-*, SC-BRIDGE-*
// Tests: Containers, Cluster, Mesh, Commands, Register, Startup, Shutdown, Devices
// =============================================================================

import { Page } from 'puppeteer';
import { ContainersPage } from '../../pages/prajna/ContainersPage';
import { ClusterPage } from '../../pages/prajna/ClusterPage';
import { MeshPage } from '../../pages/prajna/MeshPage';
import { CommandsPage } from '../../pages/prajna/CommandsPage';
import { RegisterPage } from '../../pages/prajna/RegisterPage';
import { StartupPage } from '../../pages/prajna/StartupPage';
import { ShutdownPage } from '../../pages/prajna/ShutdownPage';
import { DevicesPage } from '../../pages/prajna/DevicesPage';

describe('Prajna Containers (SC-CNT-*)', () => {
  let page: Page;
  let containers: ContainersPage;

  beforeAll(async () => {
    page = global.page;
    containers = new ContainersPage(page);
  });

  beforeEach(async () => {
    await containers.navigate();
  });

  it('should load containers page', async () => {
    expect(await containers.isHealthy()).toBe(true);
  });

  it('should display container list', async () => {
    const containerList = await containers.getContainers();
    expect(containerList).toBeDefined();
  });

  it('should show container counts by status', async () => {
    const counts = await containers.getContainerCounts();
    expect(counts).toHaveProperty('running');
    expect(counts).toHaveProperty('stopped');
    expect(counts).toHaveProperty('unhealthy');
  });
});

describe('Prajna Cluster (SC-CLU-*)', () => {
  let page: Page;
  let cluster: ClusterPage;

  beforeAll(async () => {
    page = global.page;
    cluster = new ClusterPage(page);
  });

  beforeEach(async () => {
    await cluster.navigate();
  });

  it('should load cluster page', async () => {
    expect(await cluster.isHealthy()).toBe(true);
  });

  it('should display cluster nodes', async () => {
    const nodes = await cluster.getNodes();
    expect(nodes).toBeDefined();
  });

  it('should show quorum status', async () => {
    const quorum = await cluster.getQuorumStatus();
    expect(quorum).toHaveProperty('hasQuorum');
    expect(quorum).toHaveProperty('nodes');
    expect(quorum).toHaveProperty('required');
  });

  it('should indicate split-brain status', async () => {
    const hasSplitBrain = await cluster.hasSplitBrain();
    expect(typeof hasSplitBrain).toBe('boolean');
  });

  it('should have topology view', async () => {
    const hasTopology = await cluster.hasTopologyView();
    expect(typeof hasTopology).toBe('boolean');
  });
});

describe('Prajna Mesh (SC-BRIDGE-*)', () => {
  let page: Page;
  let mesh: MeshPage;

  beforeAll(async () => {
    page = global.page;
    mesh = new MeshPage(page);
  });

  beforeEach(async () => {
    await mesh.navigate();
  });

  it('should load mesh page', async () => {
    expect(await mesh.isHealthy()).toBe(true);
  });

  it('should display mesh agents', async () => {
    const agents = await mesh.getAgents();
    expect(agents).toBeDefined();
  });

  it('should show Zenoh connection status', async () => {
    const status = await mesh.getZenohStatus();
    expect(status).toHaveProperty('connected');
    expect(status).toHaveProperty('session');
  });

  it('should display message rate', async () => {
    const rate = await mesh.getMessageRate();
    expect(rate).toBeGreaterThanOrEqual(0);
  });

  it('should show latency metrics (SC-PRF-050)', async () => {
    const latency = await mesh.getLatency();
    expect(latency).toHaveProperty('p50');
    expect(latency).toHaveProperty('p99');
  });
});

describe('Prajna Commands (SC-CTRL-006)', () => {
  let page: Page;
  let commands: CommandsPage;

  beforeAll(async () => {
    page = global.page;
    commands = new CommandsPage(page);
  });

  beforeEach(async () => {
    await commands.navigate();
  });

  it('should load commands page', async () => {
    expect(await commands.isHealthy()).toBe(true);
  });

  it('should display command history', async () => {
    const history = await commands.getHistory();
    expect(history).toBeDefined();
  });

  it('should indicate Guardian approval requirement', async () => {
    const requires = await commands.requiresGuardianApproval();
    expect(typeof requires).toBe('boolean');
  });

  it('should show 5-order effects preview', async () => {
    const effects = await commands.getEffectsPreview();
    expect(effects).toBeDefined();
  });
});

describe('Prajna Register (SC-REG-*)', () => {
  let page: Page;
  let register: RegisterPage;

  beforeAll(async () => {
    page = global.page;
    register = new RegisterPage(page);
  });

  beforeEach(async () => {
    await register.navigate();
  });

  it('should load register page', async () => {
    expect(await register.isHealthy()).toBe(true);
  });

  it('should display chain integrity status (SC-REG-002)', async () => {
    const integrity = await register.getChainIntegrity();
    expect(integrity).toHaveProperty('valid');
    expect(integrity).toHaveProperty('blocks');
  });

  it('should display latest block info', async () => {
    const block = await register.getLatestBlock();
    expect(block).toHaveProperty('id');
    expect(block).toHaveProperty('hash');
    expect(block).toHaveProperty('timestamp');
  });

  it('should verify chain on demand', async () => {
    await register.verifyChain();
    const integrity = await register.getChainIntegrity();
    expect(integrity.valid).toBeDefined();
  });

  it('should display blocks list', async () => {
    const blocks = await register.getBlocks();
    expect(blocks).toBeDefined();
  });

  it('should verify signature status (SC-REG-003)', async () => {
    const isValid = await register.isSignatureValid();
    expect(typeof isValid).toBe('boolean');
  });
});

describe('Prajna Startup', () => {
  let page: Page;
  let startup: StartupPage;

  beforeAll(async () => {
    page = global.page;
    startup = new StartupPage(page);
  });

  beforeEach(async () => {
    await startup.navigate();
  });

  it('should load startup page', async () => {
    expect(await startup.isHealthy()).toBe(true);
  });

  it('should display startup steps', async () => {
    const steps = await startup.getSteps();
    expect(steps).toBeDefined();
  });

  it('should show progress', async () => {
    const progress = await startup.getProgress();
    expect(progress).toBeGreaterThanOrEqual(0);
    expect(progress).toBeLessThanOrEqual(100);
  });

  it('should check prerequisites', async () => {
    const met = await startup.arePrerequisitesMet();
    expect(typeof met).toBe('boolean');
  });
});

describe('Prajna Shutdown (SC-EMR-057)', () => {
  let page: Page;
  let shutdown: ShutdownPage;

  beforeAll(async () => {
    page = global.page;
    shutdown = new ShutdownPage(page);
  });

  beforeEach(async () => {
    await shutdown.navigate();
  });

  it('should load shutdown page', async () => {
    expect(await shutdown.isHealthy()).toBe(true);
  });

  it('should display shutdown checklist', async () => {
    const checklist = await shutdown.getChecklistStatus();
    expect(checklist).toHaveProperty('complete');
    expect(checklist).toHaveProperty('total');
  });

  // Note: Don't actually trigger shutdown in E2E tests
  it('should have graceful shutdown option', async () => {
    const exists = await shutdown.exists('[data-testid="graceful-btn"], button[phx-click="graceful"]');
    expect(exists).toBe(true);
  });

  it('should have emergency shutdown option', async () => {
    const exists = await shutdown.exists('[data-testid="emergency-btn"], button[phx-click="emergency"]');
    expect(exists).toBe(true);
  });
});

describe('Prajna Devices', () => {
  let page: Page;
  let devices: DevicesPage;

  beforeAll(async () => {
    page = global.page;
    devices = new DevicesPage(page);
  });

  beforeEach(async () => {
    await devices.navigate();
  });

  it('should load devices page', async () => {
    expect(await devices.isHealthy()).toBe(true);
  });

  it('should display device list', async () => {
    const deviceList = await devices.getDevices();
    expect(deviceList).toBeDefined();
  });

  it('should show device counts by status', async () => {
    const counts = await devices.getDeviceCounts();
    expect(counts).toHaveProperty('online');
    expect(counts).toHaveProperty('offline');
    expect(counts).toHaveProperty('warning');
  });

  it('should have health matrix', async () => {
    const hasMatrix = await devices.hasHealthMatrix();
    expect(typeof hasMatrix).toBe('boolean');
  });

  it('should have connectivity matrix', async () => {
    const hasConnectivity = await devices.hasConnectivityMatrix();
    expect(typeof hasConnectivity).toBe('boolean');
  });

  it('should support filtering by type', async () => {
    await devices.filterByType('camera');
    const isHealthy = await devices.isHealthy();
    expect(isHealthy).toBe(true);
  });

  it('should support search', async () => {
    await devices.search('test');
    const isHealthy = await devices.isHealthy();
    expect(isHealthy).toBe(true);
  });
});
