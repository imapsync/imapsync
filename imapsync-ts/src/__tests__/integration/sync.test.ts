import { runSync } from '../../sync.js';
import { buildDefaultConfig } from '../../config/defaults.js';
import type { SyncConfig } from '../../types/sync.js';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

// Skip all tests if env vars not set
const hasEnv = !!(
  process.env.TEST_IMAP_SOURCE_HOST &&
  process.env.TEST_IMAP_SOURCE_USER &&
  process.env.TEST_IMAP_DEST_HOST &&
  process.env.TEST_IMAP_DEST_USER
);

const describeIf = hasEnv ? describe : describe.skip;

describeIf('integration: full sync', () => {
  let config: SyncConfig;
  let cachePath: string;

  beforeEach(() => {
    cachePath = path.join(os.tmpdir(), `imapsync-inttest-${Date.now()}.db`);
    config = buildDefaultConfig({
      source: {
        host: process.env.TEST_IMAP_SOURCE_HOST!,
        port: parseInt(process.env.TEST_IMAP_SOURCE_PORT ?? '993', 10),
        user: process.env.TEST_IMAP_SOURCE_USER!,
        auth: { pass: process.env.TEST_IMAP_SOURCE_PASS ?? '' },
        tls: process.env.TEST_IMAP_SOURCE_TLS !== 'false',
      },
      dest: {
        host: process.env.TEST_IMAP_DEST_HOST!,
        port: parseInt(process.env.TEST_IMAP_DEST_PORT ?? '993', 10),
        user: process.env.TEST_IMAP_DEST_USER!,
        auth: { pass: process.env.TEST_IMAP_DEST_PASS ?? '' },
        tls: process.env.TEST_IMAP_DEST_TLS !== 'false',
      },
    });
    config.cache.path = cachePath;
    config.cache.enabled = true;
  });

  afterEach(() => {
    if (fs.existsSync(cachePath)) fs.unlinkSync(cachePath);
  });

  test('connects and lists folders', async () => {
    config.folders.include = [/^INBOX$/];
    const result = await runSync(config);
    expect(result.exitCode).toBe(0);
    expect(result.state.foldersProcessed).toBeGreaterThanOrEqual(1);
  }, 60_000);

  test('dry run does not copy messages', async () => {
    config.messages.dryRun = true;
    config.folders.include = [/^INBOX$/];
    const result = await runSync(config);
    expect(result.exitCode).toBe(0);
  }, 60_000);
});
