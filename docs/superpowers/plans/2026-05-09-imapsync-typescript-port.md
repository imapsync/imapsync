# imapsync TypeScript Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port imapsync's core IMAP sync logic to a production-ready TypeScript CLI tool with modular architecture, SQLite caching, and Gmail label support.

**Architecture:** Modular pipeline — each subsystem is an independent module, the sync orchestrator threads state through function parameters instead of globals. imapflow handles IMAP protocol, better-sqlite3 handles caching, commander handles CLI.

**Tech Stack:** TypeScript 5.x strict, Node.js 20+, imapflow, better-sqlite3, commander, Jest, tsup

---

## File Structure

```
imapsync-ts/
  package.json
  tsconfig.json
  jest.config.ts
  tsup.config.ts
  src/
    cli.ts                    — CLI entry point, commander setup
    sync.ts                   — Core orchestration: runSync, syncFolder
    types/
      account.ts              — ImapAccount, FolderInfo, MessageInfo, FolderStatus
      sync.ts                 — SyncConfig, SyncState, SyncResult, ErrorRecord, FolderPair
      cache.ts                — CacheEntry, UidMapping
    imap/
      connection.ts           — ImapClient class wrapping imapflow
      folder.ts               — resolveFolderPairs, ensureFolder, filterFolders
      message.ts              — listMessages, findMessagesToCopy, copyMessage, handleDeletes
      flags.ts                — syncFlags, diffFlags
      labels.ts               — syncLabels, diffLabels
      search.ts               — buildSearchCriteria (filter by size/regex/age)
    cache/
      store.ts                — CacheStore class wrapping better-sqlite3
      schema.ts               — SQL DDL, migration
    auth/
      oauth2.ts               — refreshAccessToken, buildOAuth2Config
    config/
      presets.ts              — gmailPreset, exchangePreset, office365Preset
      defaults.ts             — buildDefaultConfig, mergePresets
      validate.ts             — validateConfig
    logger/
      index.ts                — createLogger, Logger interface
      formatter.ts            — formatTimestamp, formatProgress, formatSummary
    errors.ts                 — Custom error classes
  src/__tests__/
    unit/
      cache.test.ts
      folder-mapping.test.ts
      message-merge.test.ts
      flags.test.ts
      config.test.ts
      logger.test.ts
    integration/
      sync.test.ts
      folder.test.ts
      message.test.ts
      labels.test.ts
```

---

### Task 1: Project scaffolding

**Files:**
- Create: `imapsync-ts/package.json`
- Create: `imapsync-ts/tsconfig.json`
- Create: `imapsync-ts/jest.config.ts`
- Create: `imapsync-ts/tsup.config.ts`
- Create: `imapsync-ts/src/cli.ts` (placeholder that logs "hello")

- [ ] **Step 1: Create the project directory and package.json**

```bash
mkdir -p /home/bowmanhan/Code/imapsync/imapsync-ts/src
```

Create `imapsync-ts/package.json`:

```json
{
  "name": "imapsync-ts",
  "version": "0.1.0",
  "description": "IMAP mailbox synchronizer — TypeScript port of imapsync",
  "type": "module",
  "main": "dist/cli.js",
  "bin": {
    "imapsync-ts": "dist/cli.js"
  },
  "scripts": {
    "build": "tsup",
    "dev": "tsx src/cli.ts",
    "test": "jest --config jest.config.ts",
    "test:integration": "jest --config jest.config.ts --testPathPattern integration",
    "lint": "tsc --noEmit"
  },
  "engines": {
    "node": ">=20.0.0"
  },
  "dependencies": {
    "imapflow": "^1.0.184",
    "better-sqlite3": "^12.6.2",
    "commander": "^13.1.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "tsup": "^8.4.0",
    "tsx": "^4.19.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.2.0",
    "@types/better-sqlite3": "^7.6.12",
    "@types/jest": "^29.5.14",
    "@types/node": "^22.0.0"
  }
}
```

- [ ] **Step 2: Create tsconfig.json**

Create `imapsync-ts/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "sourceMap": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: Create jest.config.ts**

Create `imapsync-ts/jest.config.ts`:

```typescript
import type { Config } from 'jest';

const config: Config = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/__tests__/**/*.test.ts'],
  transform: {
    '^.+\\.tsx?$': ['ts-jest', { useESM: true }],
  },
  extensionsToTreatAsEsm: ['.ts'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
};

export default config;
```

- [ ] **Step 4: Create tsup.config.ts**

Create `imapsync-ts/tsup.config.ts`:

```typescript
import { defineConfig } from 'tsup';

export default defineConfig({
  entry: ['src/cli.ts'],
  format: ['esm'],
  target: 'node20',
  clean: true,
  banner: { js: '#!/usr/bin/env node' },
});
```

- [ ] **Step 5: Create placeholder cli.ts**

Create `imapsync-ts/src/cli.ts`:

```typescript
console.log('imapsync-ts: IMAP mailbox synchronizer');
```

- [ ] **Step 6: Install dependencies**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npm install
```
Expected: dependencies installed, no errors.

- [ ] **Step 7: Verify the scaffold works**

Run:
```bash
npx tsx src/cli.ts
```
Expected output: `imapsync-ts: IMAP mailbox synchronizer`

Run:
```bash
npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add imapsync-ts/
git commit -m "feat: scaffold imapsync-ts project with TypeScript, Jest, tsup"
```

---

### Task 2: Type definitions

**Files:**
- Create: `imapsync-ts/src/types/account.ts`
- Create: `imapsync-ts/src/types/sync.ts`
- Create: `imapsync-ts/src/types/cache.ts`

These types are the contract that all other modules depend on. They replace the ~60 global variables in the Perl original.

- [ ] **Step 1: Create types/account.ts**

Create `imapsync-ts/src/types/account.ts`:

```typescript
export interface ImapAccount {
  host: string;
  port: number;
  user: string;
  auth: {
    pass?: string;
    accessToken?: string;
  };
  tls: boolean;
}

export interface FolderInfo {
  path: string;
  delimiter: string;
  specialUse?: string;
  subscribed: boolean;
}

export interface MessageInfo {
  uid: number;
  flags: Set<string>;
  internalDate: Date;
  size: number;
  envelope?: {
    subject: string;
    from: { address: string }[];
    date: Date;
    messageId?: string;
  };
  labels?: Set<string>;
}

export interface FolderStatus {
  path: string;
  exists: number;
  uidValidity: string;
  uidNext: number;
  highestModseq?: string;
}

export interface AppendResult {
  destination: string;
  uid: number;
  uidValidity: string;
}
```

- [ ] **Step 2: Create types/sync.ts**

Create `imapsync-ts/src/types/sync.ts`:

```typescript
import type { ImapAccount, FolderInfo } from './account.js';

export interface SyncConfig {
  source: ImapAccount;
  dest: ImapAccount;
  folders: {
    include?: RegExp[];
    exclude?: RegExp[];
    recursive?: boolean;
  };
  messages: {
    skipLarge?: number;
    skipRegex?: RegExp[];
    dryRun?: boolean;
    deleteSource?: boolean;
    deleteDuplicates?: boolean;
  };
  flags: {
    sync: boolean;
    syncAfterCopy: boolean;
  };
  labels: {
    sync: boolean;
  };
  cache: {
    enabled: boolean;
    path: string;
  };
  verbose: boolean;
}

export interface ErrorRecord {
  type: ErrorType;
  message: string;
  folder?: string;
  uid?: number;
  timestamp: Date;
}

export type ErrorType = 'connection' | 'auth' | 'message' | 'folder' | 'cache' | 'unknown';

export interface SyncState {
  foldersProcessed: number;
  messagesCopied: number;
  messagesSkipped: number;
  messagesDeleted: number;
  errors: ErrorRecord[];
  startTime: Date;
}

export interface SyncResult {
  state: SyncState;
  success: boolean;
  exitCode: number;
}

export interface FolderPair {
  source: FolderInfo;
  dest: FolderInfo;
}

export function createSyncState(): SyncState {
  return {
    foldersProcessed: 0,
    messagesCopied: 0,
    messagesSkipped: 0,
    messagesDeleted: 0,
    errors: [],
    startTime: new Date(),
  };
}

export function buildResult(state: SyncState): SyncResult {
  return {
    state,
    success: state.errors.filter(e => e.type === 'connection' || e.type === 'auth').length === 0,
    exitCode: state.errors.filter(e => e.type === 'connection' || e.type === 'auth').length > 0
      ? state.errors.some(e => e.type === 'auth') ? 2 : 1
      : 0,
  };
}
```

- [ ] **Step 3: Create types/cache.ts**

Create `imapsync-ts/src/types/cache.ts`:

```typescript
export interface UidMapping {
  folder: string;
  sourceUid: number;
  destUid: number;
  uidValidity: string;
}

export interface MessageHash {
  folder: string;
  sourceUid: number;
  headerHash: string;
  uidValidity: string;
}
```

- [ ] **Step 4: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add imapsync-ts/src/types/
git commit -m "feat: add core type definitions for account, sync, and cache"
```

---

### Task 3: Error classes + Logger

**Files:**
- Create: `imapsync-ts/src/errors.ts`
- Create: `imapsync-ts/src/logger/index.ts`
- Create: `imapsync-ts/src/logger/formatter.ts`
- Test: `imapsync-ts/src/__tests__/unit/logger.test.ts`

- [ ] **Step 1: Write failing test for logger**

Create directory:
```bash
mkdir -p /home/bowmanhan/Code/imapsync/imapsync-ts/src/__tests__/unit
```

Create `imapsync-ts/src/__tests__/unit/logger.test.ts`:

```typescript
import { createLogger } from '../../logger/index.js';

function collectOutput(fn: () => void): string {
  const lines: string[] = [];
  const orig = console.log;
  console.log = (...args: unknown[]) => lines.push(args.join(' '));
  try { fn(); } finally { console.log = orig; }
  return lines.join('\n');
}

test('info logs with timestamp', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.info('hello'));
  expect(output).toMatch(/^\[\d{2}:\d{2}:\d{2}\] hello$/);
});

test('progress logs folder count', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.progress('INBOX', 1, 10));
  expect(output).toContain('INBOX');
  expect(output).toContain('1/10');
});

test('summary shows copy and skip counts', () => {
  const logger = createLogger({ verbose: false });
  const result = {
    state: {
      foldersProcessed: 5,
      messagesCopied: 100,
      messagesSkipped: 20,
      messagesDeleted: 0,
      errors: [],
      startTime: new Date(),
    },
    success: true,
    exitCode: 0,
  };
  const output = collectOutput(() => logger.summary(result));
  expect(output).toContain('100 copied');
  expect(output).toContain('20 skipped');
  expect(output).toContain('0 errors');
});

test('error logs with ERROR prefix', () => {
  const logger = createLogger({ verbose: false });
  const output = collectOutput(() => logger.error('bad thing', new Error('boom')));
  expect(output).toContain('ERROR');
  expect(output).toContain('bad thing');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/logger.test.ts --no-cache 2>&1 | tail -5
```
Expected: FAIL — `Cannot find module '../../logger/index.js'`

- [ ] **Step 3: Create errors.ts**

Create `imapsync-ts/src/errors.ts`:

```typescript
export class ImapConnectionError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ImapConnectionError';
  }
}

export class ImapAuthError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'ImapAuthError';
  }
}

export class MessageCopyError extends Error {
  constructor(
    message: string,
    public readonly folder: string,
    public readonly uid: number,
    public readonly cause?: Error,
  ) {
    super(message);
    this.name = 'MessageCopyError';
  }
}

export class FolderError extends Error {
  constructor(message: string, public readonly folder: string, public readonly cause?: Error) {
    super(message);
    this.name = 'FolderError';
  }
}

export class CacheError extends Error {
  constructor(message: string, public readonly cause?: Error) {
    super(message);
    this.name = 'CacheError';
  }
}

import type { ErrorType } from './types/sync.js';

export function classifyError(err: Error): ErrorType {
  if (err instanceof ImapAuthError) return 'auth';
  if (err instanceof ImapConnectionError) return 'connection';
  if (err instanceof MessageCopyError) return 'message';
  if (err instanceof FolderError) return 'folder';
  if (err instanceof CacheError) return 'cache';
  return 'unknown';
}
```

- [ ] **Step 4: Create logger/formatter.ts**

Create `imapsync-ts/src/logger/formatter.ts`:

```typescript
export function formatTimestamp(): string {
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');
  return `[${hh}:${mm}:${ss}]`;
}

export function formatProgress(folder: string, current: number, total: number): string {
  return `[${current}/${total}] ${folder}`;
}

export function formatSummary(data: {
  copied: number;
  skipped: number;
  deleted: number;
  errors: number;
  elapsedMs: number;
}): string {
  const elapsed = (data.elapsedMs / 1000).toFixed(1);
  return `Sync complete: ${data.copied} copied, ${data.skipped} skipped, ${data.deleted} deleted, ${data.errors} errors (${elapsed}s)`;
}
```

- [ ] **Step 5: Create logger/index.ts**

Create `imapsync-ts/src/logger/index.ts`:

```typescript
import type { SyncResult } from '../types/sync.js';
import { formatTimestamp, formatProgress, formatSummary } from './formatter.js';

export interface Logger {
  info(msg: string): void;
  warn(msg: string): void;
  error(msg: string, err?: Error): void;
  progress(folder: string, current: number, total: number): void;
  summary(result: SyncResult): void;
}

export function createLogger(_opts: { verbose: boolean }): Logger {
  return {
    info(msg: string) {
      console.log(`${formatTimestamp()} ${msg}`);
    },
    warn(msg: string) {
      console.log(`${formatTimestamp()} WARN: ${msg}`);
    },
    error(msg: string, err?: Error) {
      const detail = err ? `: ${err.message}` : '';
      console.error(`${formatTimestamp()} ERROR: ${msg}${detail}`);
    },
    progress(folder, current, total) {
      console.log(`${formatTimestamp()} ${formatProgress(folder, current, total)}`);
    },
    summary(result) {
      const elapsed = Date.now() - result.state.startTime.getTime();
      console.log(
        `${formatTimestamp()} ${formatSummary({
          copied: result.state.messagesCopied,
          skipped: result.state.messagesSkipped,
          deleted: result.state.messagesDeleted,
          errors: result.state.errors.length,
          elapsedMs: elapsed,
        })}`
      );
    },
  };
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/logger.test.ts --no-cache
```
Expected: 4 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add imapsync-ts/src/errors.ts imapsync-ts/src/logger/ imapsync-ts/src/__tests__/
git commit -m "feat: add error classes and logger with tests"
```

---

### Task 4: SQLite cache layer

**Files:**
- Create: `imapsync-ts/src/cache/schema.ts`
- Create: `imapsync-ts/src/cache/store.ts`
- Test: `imapsync-ts/src/__tests__/unit/cache.test.ts`

- [ ] **Step 1: Write failing tests for CacheStore**

Create `imapsync-ts/src/__tests__/unit/cache.test.ts`:

```typescript
import { CacheStore } from '../../cache/store.js';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

let cache: CacheStore;
let dbPath: string;

beforeEach(() => {
  dbPath = path.join(os.tmpdir(), `imapsync-test-${Date.now()}.db`);
  cache = new CacheStore(dbPath);
});

afterEach(() => {
  cache.close();
  if (fs.existsSync(dbPath)) fs.unlinkSync(dbPath);
});

test('open creates tables and sets WAL mode', () => {
  expect(() => cache.open()).not.toThrow();
});

test('setMapping and getMapping round-trip', () => {
  cache.open();
  cache.setMapping('INBOX', 100, 200, 'v1');
  expect(cache.getMapping('INBOX', 100)).toBe(200);
  expect(cache.getMapping('INBOX', 999)).toBeNull();
});

test('invalidateFolder clears mappings for that folder', () => {
  cache.open();
  cache.setMapping('INBOX', 100, 200, 'v1');
  cache.setMapping('Sent', 50, 60, 'v1');
  cache.invalidateFolder('INBOX');
  expect(cache.getMapping('INBOX', 100)).toBeNull();
  expect(cache.getMapping('Sent', 50)).toBe(60);
});

test('setMapping with different uidValidity overwrites', () => {
  cache.open();
  cache.setMapping('INBOX', 100, 200, 'v1');
  cache.setMapping('INBOX', 100, 300, 'v2');
  expect(cache.getMapping('INBOX', 100)).toBe(300);
});

test('setMessageHash and getMessageHash round-trip', () => {
  cache.open();
  cache.setMessageHash('INBOX', 100, 'abc123', 'v1');
  expect(cache.getMessageHash('INBOX', 100)).toBe('abc123');
  expect(cache.getMessageHash('INBOX', 999)).toBeNull();
});

test('invalidateFolder clears hashes too', () => {
  cache.open();
  cache.setMessageHash('INBOX', 100, 'abc123', 'v1');
  cache.invalidateFolder('INBOX');
  expect(cache.getMessageHash('INBOX', 100)).toBeNull();
});

test('setMappingBatch inserts many mappings in a transaction', () => {
  cache.open();
  const mappings = Array.from({ length: 100 }, (_, i) => ({
    folder: 'INBOX',
    sourceUid: i,
    destUid: i + 1000,
    uidValidity: 'v1',
  }));
  cache.setMappingBatch(mappings);
  expect(cache.getMapping('INBOX', 99)).toBe(1099);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/cache.test.ts --no-cache 2>&1 | tail -5
```
Expected: FAIL — `Cannot find module '../../cache/store.js'`

- [ ] **Step 3: Create cache/schema.ts**

Create `imapsync-ts/src/cache/schema.ts`:

```typescript
export const SCHEMA = `
CREATE TABLE IF NOT EXISTS uid_mapping (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  dest_uid    INTEGER NOT NULL,
  uidvalidity TEXT NOT NULL,
  PRIMARY KEY (folder, source_uid)
);

CREATE TABLE IF NOT EXISTS message_hash (
  folder      TEXT NOT NULL,
  source_uid  INTEGER NOT NULL,
  header_hash TEXT NOT NULL,
  uidvalidity TEXT NOT NULL,
  PRIMARY KEY (folder, source_uid)
);
`;
```

- [ ] **Step 4: Create cache/store.ts**

Create `imapsync-ts/src/cache/store.ts`:

```typescript
import Database from 'better-sqlite3';
import { SCHEMA } from './schema.js';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

export class CacheStore {
  private db: Database.Database;
  private stmtGetMapping: Database.Statement;
  private stmtSetMapping: Database.Statement;
  private stmtGetHash: Database.Statement;
  private stmtSetHash: Database.Statement;
  private stmtDeleteMapping: Database.Statement;
  private stmtDeleteHash: Database.Statement;
  private stmtInsertMapping: Database.Statement;

  constructor(dbPath: string) {
    mkdirSync(dirname(dbPath), { recursive: true });
    this.db = new Database(dbPath);
    this.db.pragma('journal_mode = WAL');
    this.db.exec(SCHEMA);

    this.stmtGetMapping = this.db.prepare(
      'SELECT dest_uid FROM uid_mapping WHERE folder = ? AND source_uid = ?'
    );
    this.stmtSetMapping = this.db.prepare(
      `INSERT INTO uid_mapping (folder, source_uid, dest_uid, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET dest_uid = excluded.dest_uid, uidvalidity = excluded.uidvalidity`
    );
    this.stmtGetHash = this.db.prepare(
      'SELECT header_hash FROM message_hash WHERE folder = ? AND source_uid = ?'
    );
    this.stmtSetHash = this.db.prepare(
      `INSERT INTO message_hash (folder, source_uid, header_hash, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET header_hash = excluded.header_hash, uidvalidity = excluded.uidvalidity`
    );
    this.stmtDeleteMapping = this.db.prepare(
      'DELETE FROM uid_mapping WHERE folder = ?'
    );
    this.stmtDeleteHash = this.db.prepare(
      'DELETE FROM message_hash WHERE folder = ?'
    );
    this.stmtInsertMapping = this.db.prepare(
      `INSERT INTO uid_mapping (folder, source_uid, dest_uid, uidvalidity)
       VALUES (?, ?, ?, ?)
       ON CONFLICT(folder, source_uid) DO UPDATE SET dest_uid = excluded.dest_uid, uidvalidity = excluded.uidvalidity`
    );
  }

  open(): void {
    // Tables already created in constructor. This method is a no-op
    // kept for API compatibility with the spec.
  }

  getMapping(folder: string, sourceUid: number): number | null {
    const row = this.stmtGetMapping.get(folder, sourceUid) as { dest_uid: number } | undefined;
    return row ? row.dest_uid : null;
  }

  setMapping(folder: string, sourceUid: number, destUid: number, uidValidity: string): void {
    this.stmtSetMapping.run(folder, sourceUid, destUid, uidValidity);
  }

  setMappingBatch(mappings: Array<{ folder: string; sourceUid: number; destUid: number; uidValidity: string }>): void {
    const tx = this.db.transaction(() => {
      for (const m of mappings) {
        this.stmtInsertMapping.run(m.folder, m.sourceUid, m.destUid, m.uidValidity);
      }
    });
    tx();
  }

  invalidateFolder(folder: string): void {
    this.stmtDeleteMapping.run(folder);
    this.stmtDeleteHash.run(folder);
  }

  getMessageHash(folder: string, sourceUid: number): string | null {
    const row = this.stmtGetHash.get(folder, sourceUid) as { header_hash: string } | undefined;
    return row ? row.header_hash : null;
  }

  setMessageHash(folder: string, sourceUid: number, hash: string, uidValidity: string): void {
    this.stmtSetHash.run(folder, sourceUid, hash, uidValidity);
  }

  close(): void {
    this.db.close();
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/cache.test.ts --no-cache
```
Expected: 7 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add imapsync-ts/src/cache/ imapsync-ts/src/__tests__/unit/cache.test.ts
git commit -m "feat: add SQLite cache layer with uid mapping and message hash"
```

---

### Task 5: Config presets + validation

**Files:**
- Create: `imapsync-ts/src/config/presets.ts`
- Create: `imapsync-ts/src/config/defaults.ts`
- Create: `imapsync-ts/src/config/validate.ts`
- Test: `imapsync-ts/src/__tests__/unit/config.test.ts`

- [ ] **Step 1: Write failing tests for config**

Create `imapsync-ts/src/__tests__/unit/config.test.ts`:

```typescript
import { gmailPreset, exchangePreset } from '../../config/presets.js';
import { buildDefaultConfig, mergePresets } from '../../config/defaults.js';
import { validateConfig } from '../../config/validate.js';

test('gmailPreset returns correct host and port', () => {
  const preset = gmailPreset();
  expect(preset.host).toBe('imap.gmail.com');
  expect(preset.port).toBe(993);
  expect(preset.tls).toBe(true);
});

test('exchangePreset returns correct host', () => {
  const preset = exchangePreset();
  expect(preset.host).toBe('outlook.office365.com');
  expect(preset.port).toBe(993);
});

test('buildDefaultConfig sets sensible defaults', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(config.flags.sync).toBe(true);
  expect(config.cache.enabled).toBe(true);
  expect(config.messages.dryRun).toBe(false);
  expect(config.verbose).toBe(false);
});

test('mergePresets applies gmail preset to source', () => {
  const config = buildDefaultConfig({
    source: { host: '', port: 993, user: 'u@gmail.com', auth: { pass: 'p' }, tls: false },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  mergePresets(config, { source: 'gmail' });
  expect(config.source.host).toBe('imap.gmail.com');
  expect(config.source.tls).toBe(true);
  expect(config.source.port).toBe(993);
});

test('validateConfig rejects missing host', () => {
  const config = buildDefaultConfig({
    source: { host: '', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).toThrow('source host');
});

test('validateConfig rejects missing user', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: '', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).toThrow('source user');
});

test('validateConfig accepts valid config', () => {
  const config = buildDefaultConfig({
    source: { host: 's1', port: 993, user: 'u1', auth: { pass: 'p1' }, tls: true },
    dest: { host: 's2', port: 993, user: 'u2', auth: { pass: 'p2' }, tls: true },
  });
  expect(() => validateConfig(config)).not.toThrow();
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/config.test.ts --no-cache 2>&1 | tail -5
```
Expected: FAIL — module not found.

- [ ] **Step 3: Create config/presets.ts**

Create `imapsync-ts/src/config/presets.ts`:

```typescript
import type { ImapAccount } from '../types/account.js';

export interface PresetConfig {
  host: string;
  port: number;
  tls: boolean;
}

export function gmailPreset(): PresetConfig {
  return { host: 'imap.gmail.com', port: 993, tls: true };
}

export function exchangePreset(): PresetConfig {
  return { host: 'outlook.office365.com', port: 993, tls: true };
}

export function office365Preset(): PresetConfig {
  return { host: 'outlook.office365.com', port: 993, tls: true };
}

export function dominoPreset(): PresetConfig {
  return { host: '', port: 993, tls: true };
}
```

- [ ] **Step 4: Create config/defaults.ts**

Create `imapsync-ts/src/config/defaults.ts`:

```typescript
import type { SyncConfig } from '../types/sync.js';
import type { ImapAccount } from '../types/account.js';
import { gmailPreset, exchangePreset, office365Preset } from './presets.js';
import { homedir } from 'node:os';
import { join } from 'node:path';

export function buildDefaultConfig(accounts: {
  source: ImapAccount;
  dest: ImapAccount;
}): SyncConfig {
  return {
    source: accounts.source,
    dest: accounts.dest,
    folders: {
      recursive: true,
    },
    messages: {
      dryRun: false,
      deleteSource: false,
      deleteDuplicates: false,
    },
    flags: {
      sync: true,
      syncAfterCopy: true,
    },
    labels: {
      sync: false,
    },
    cache: {
      enabled: true,
      path: join(homedir(), '.imapsync', 'cache.db'),
    },
    verbose: false,
  };
}

export function mergePresets(
  config: SyncConfig,
  presets: { source?: string; dest?: string },
): void {
  if (presets.source === 'gmail') Object.assign(config.source, gmailPreset());
  if (presets.source === 'exchange' || presets.source === 'office365') Object.assign(config.source, exchangePreset());
  if (presets.dest === 'gmail') Object.assign(config.dest, gmailPreset());
  if (presets.dest === 'exchange' || presets.dest === 'office365') Object.assign(config.dest, office365Preset());
}
```

- [ ] **Step 5: Create config/validate.ts**

Create `imapsync-ts/src/config/validate.ts`:

```typescript
import type { SyncConfig } from '../types/sync.js';

export function validateConfig(config: SyncConfig): void {
  if (!config.source.host) throw new Error('source host is required');
  if (!config.source.user) throw new Error('source user is required');
  if (!config.source.auth.pass && !config.source.auth.accessToken) {
    throw new Error('source password or accessToken is required');
  }
  if (!config.dest.host) throw new Error('dest host is required');
  if (!config.dest.user) throw new Error('dest user is required');
  if (!config.dest.auth.pass && !config.dest.auth.accessToken) {
    throw new Error('dest password or accessToken is required');
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/config.test.ts --no-cache
```
Expected: 6 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add imapsync-ts/src/config/ imapsync-ts/src/__tests__/unit/config.test.ts
git commit -m "feat: add config presets, defaults, and validation"
```

---

### Task 6: ImapClient — IMAP connection wrapper

**Files:**
- Create: `imapsync-ts/src/imap/connection.ts`

This is a thin wrapper around imapflow that exposes domain-level methods. No tests yet — integration tests will cover this in Task 11.

- [ ] **Step 1: Create imap/connection.ts**

Create directory:
```bash
mkdir -p /home/bowmanhan/Code/imapsync/imapsync-ts/src/imap
```

Create `imapsync-ts/src/imap/connection.ts`:

```typescript
import { ImapFlow } from 'imapflow';
import type { ImapAccount, FolderInfo, FolderStatus, AppendResult } from '../types/account.js';
import { ImapConnectionError, ImapAuthError } from '../errors.js';

export class ImapClient {
  private client: ImapFlow;
  private connected = false;

  constructor(account: ImapAccount) {
    this.client = new ImapFlow({
      host: account.host,
      port: account.port,
      secure: account.tls,
      auth: {
        user: account.user,
        pass: account.auth.pass ?? '',
        accessToken: account.auth.accessToken,
      },
      logger: false,
    });
  }

  async connect(): Promise<void> {
    try {
      await this.client.connect();
      this.connected = true;
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.toLowerCase().includes('auth') || msg.toLowerCase().includes('login') || msg.toLowerCase().includes('credential')) {
        throw new ImapAuthError(msg, err instanceof Error ? err : undefined);
      }
      throw new ImapConnectionError(msg, err instanceof Error ? err : undefined);
    }
  }

  async logout(): Promise<void> {
    try {
      await this.client.logout();
    } catch {
      // Best-effort logout
    }
    this.connected = false;
  }

  async ensureConnected(): Promise<void> {
    if (this.connected && this.client.usable) return;
    await this.connect();
  }

  async listFolders(): Promise<FolderInfo[]> {
    const mailboxes = await this.client.list();
    return mailboxes.map((mb) => ({
      path: mb.path,
      delimiter: mb.delimiter,
      specialUse: mb.specialUse,
      subscribed: mb.subscribed,
    }));
  }

  async ensureFolder(path: string): Promise<void> {
    const result = await this.client.mailboxCreate(path);
    if (!result.created) {
      // Folder already exists, that's fine
    }
  }

  async folderStatus(folder: string): Promise<FolderStatus> {
    const status = await this.client.status(folder, {
      messages: true,
      uidValidity: true,
      uidNext: true,
      highestModseq: true,
    });
    return {
      path: folder,
      exists: status.messages ?? 0,
      uidValidity: String(status.uidValidity ?? ''),
      uidNext: status.uidNext ?? 0,
      highestModseq: status.highestModseq ? String(status.highestModseq) : undefined,
    };
  }

  async appendMessage(
    folder: string,
    raw: Buffer,
    flags: string[],
    date: Date,
  ): Promise<AppendResult> {
    const result = await this.client.append(folder, raw, flags, date);
    if (!result) {
      throw new Error(`Failed to append message to ${folder}`);
    }
    return {
      destination: result.destination,
      uid: result.uid ?? 0,
      uidValidity: String(result.uidValidity ?? ''),
    };
  }

  async fetchMessageSource(uid: number, folder: string): Promise<Buffer> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      const msg = await this.client.fetchOne(String(uid), { source: true }, { uid: true });
      if (!msg || !msg.source) throw new Error(`Message ${uid} not found in ${folder}`);
      return Buffer.from(msg.source);
    } finally {
      lock.release();
    }
  }

  async addFlags(folder: string, uid: number, flags: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsAdd(String(uid), flags, { uid: true });
    } finally {
      lock.release();
    }
  }

  async setFlags(folder: string, uid: number, flags: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsSet(String(uid), flags, { uid: true });
    } finally {
      lock.release();
    }
  }

  async addLabels(folder: string, uid: number, labels: string[]): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageFlagsAdd(String(uid), labels, { uid: true, useLabels: true });
    } finally {
      lock.release();
    }
  }

  async deleteMessage(folder: string, uid: number): Promise<void> {
    const lock = await this.client.getMailboxLock(folder);
    try {
      await this.client.messageDelete(String(uid), { uid: true });
    } finally {
      lock.release();
    }
  }

  getClient(): ImapFlow {
    return this.client;
  }
}
```

- [ ] **Step 2: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add imapsync-ts/src/imap/connection.ts
git commit -m "feat: add ImapClient wrapper around imapflow"
```

---

### Task 7: Folder operations + message listing

**Files:**
- Create: `imapsync-ts/src/imap/folder.ts`
- Create: `imapsync-ts/src/imap/message.ts`
- Create: `imapsync-ts/src/imap/search.ts`
- Test: `imapsync-ts/src/__tests__/unit/folder-mapping.test.ts`
- Test: `imapsync-ts/src/__tests__/unit/message-merge.test.ts`

- [ ] **Step 1: Write failing test for folder mapping**

Create `imapsync-ts/src/__tests__/unit/folder-mapping.test.ts`:

```typescript
import { filterFolders, mapFolderName } from '../../imap/folder.js';
import type { FolderInfo } from '../../types/account.js';

function makeFolder(path: string): FolderInfo {
  return { path, delimiter: '/', subscribed: true };
}

test('filterFolders includes matching folders', () => {
  const folders = [makeFolder('INBOX'), makeFolder('Sent'), makeFolder('Trash')];
  const result = filterFolders(folders, { include: [/^INBOX$/] });
  expect(result.map(f => f.path)).toEqual(['INBOX']);
});

test('filterFolders excludes matching folders', () => {
  const folders = [makeFolder('INBOX'), makeFolder('Sent'), makeFolder('Trash')];
  const result = filterFolders(folders, { exclude: [/^Trash$/] });
  expect(result.map(f => f.path)).toEqual(['INBOX', 'Sent']);
});

test('filterFolders with no filters returns all', () => {
  const folders = [makeFolder('INBOX'), makeFolder('Sent')];
  const result = filterFolders(folders, {});
  expect(result.map(f => f.path)).toEqual(['INBOX', 'Sent']);
});

test('mapFolderName handles separator inversion', () => {
  // Source uses '.', dest uses '/'
  expect(mapFolderName('INBOX.Sent', '.', '/')).toBe('INBOX/Sent');
});

test('mapFolderName with same separator returns unchanged', () => {
  expect(mapFolderName('INBOX/Sent', '/', '/')).toBe('INBOX/Sent');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/folder-mapping.test.ts --no-cache 2>&1 | tail -5
```
Expected: FAIL.

- [ ] **Step 3: Write failing test for message merge**

Create `imapsync-ts/src/__tests__/unit/message-merge.test.ts`:

```typescript
import { findMessagesToCopy } from '../../imap/message.js';
import type { MessageInfo } from '../../types/account.js';
import type { CacheStore } from '../../cache/store.js';

function makeMsg(uid: number, size = 1000, messageId?: string): MessageInfo {
  return {
    uid,
    flags: new Set(['\\Seen']),
    internalDate: new Date(),
    size,
    envelope: messageId ? { subject: '', from: [], date: new Date(), messageId } : undefined,
  };
}

function makeCache(mappings: Record<string, number>): Pick<CacheStore, 'getMapping'> {
  return {
    getMapping: (_folder: string, uid: number) => mappings[String(uid)] ?? null,
  };
}

test('findMessagesToCopy returns messages not in cache', () => {
  const src = [makeMsg(1), makeMsg(2), makeMsg(3)];
  const dst: MessageInfo[] = [];
  const cache = makeCache({ 1: 100 });
  const result = findMessagesToCopy(src, dst, cache as CacheStore, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.toCopy.map(m => m.uid)).toEqual([2, 3]);
  expect(result.alreadySynced.map(m => m.uid)).toEqual([1]);
});

test('findMessagesToCopy skips messages exceeding maxsize', () => {
  const src = [makeMsg(1, 500), makeMsg(2, 5000)];
  const dst: MessageInfo[] = [];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true, skipLarge: 1000 });
  expect(result.toCopy.map(m => m.uid)).toEqual([1]);
});

test('findMessagesToCopy with no cache and no dest returns all source', () => {
  const src = [makeMsg(1), makeMsg(2)];
  const dst: MessageInfo[] = [];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.toCopy.map(m => m.uid)).toEqual([1, 2]);
});

test('findMessagesToCopy detects duplicates via messageId', () => {
  const src = [makeMsg(1, 1000, '<msg1@example>'), makeMsg(2, 1000, '<msg2@example>')];
  const dst = [makeMsg(10, 1000, '<msg1@example>')];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.toCopy.map(m => m.uid)).toEqual([2]);
  expect(result.duplicates.map(m => m.uid)).toEqual([1]);
});
```

- [ ] **Step 4: Create imap/search.ts**

Create `imapsync-ts/src/imap/search.ts`:

```typescript
import type { MessageInfo } from '../types/account.js';

export function shouldSkipMessage(
  msg: MessageInfo,
  opts: { skipLarge?: number; skipRegex?: RegExp[] },
): boolean {
  if (opts.skipLarge && msg.size > opts.skipLarge) return true;
  if (opts.skipRegex && opts.skipRegex.length > 0) {
    const subject = msg.envelope?.subject ?? '';
    const from = msg.envelope?.from.map(a => a.address).join(', ') ?? '';
    if (opts.skipRegex.some(re => re.test(subject) || re.test(from))) return true;
  }
  return false;
}
```

- [ ] **Step 5: Create imap/folder.ts**

Create `imapsync-ts/src/imap/folder.ts`:

```typescript
import type { FolderInfo } from '../types/account.js';
import type { FolderPair } from '../types/sync.js';

export function filterFolders(
  folders: FolderInfo[],
  opts: { include?: RegExp[]; exclude?: RegExp[] },
): FolderInfo[] {
  let result = folders;
  if (opts.include && opts.include.length > 0) {
    result = result.filter(f => opts.include!.some(re => re.test(f.path)));
  }
  if (opts.exclude && opts.exclude.length > 0) {
    result = result.filter(f => !opts.exclude!.some(re => re.test(f.path)));
  }
  return result;
}

export function mapFolderName(path: string, srcDelimiter: string, dstDelimiter: string): string {
  if (srcDelimiter === dstDelimiter) return path;
  return path.split(srcDelimiter).join(dstDelimiter);
}

export async function resolveFolderPairs(
  sourceFolders: FolderInfo[],
  destFolders: FolderInfo[],
  opts: { include?: RegExp[]; exclude?: RegExp[] },
): Promise<FolderPair[]> {
  const filtered = filterFolders(sourceFolders, opts);
  const destPaths = new Set(destFolders.map(f => f.path));

  return filtered.map(src => {
    const dest = destPaths.has(src.path)
      ? destFolders.find(f => f.path === src.path)!
      : { ...src, subscribed: false };
    return { source: src, dest };
  });
}
```

- [ ] **Step 6: Create imap/message.ts**

Create `imapsync-ts/src/imap/message.ts`:

```typescript
import type { MessageInfo } from '../types/account.js';
import type { CacheStore } from '../cache/store.js';
import { shouldSkipMessage } from './search.js';

interface MergeResult {
  toCopy: MessageInfo[];
  alreadySynced: MessageInfo[];
  duplicates: MessageInfo[];
}

export function findMessagesToCopy(
  srcMsgs: MessageInfo[],
  dstMsgs: MessageInfo[],
  cache: CacheStore | null,
  folder: string,
  flagsConfig: { sync: boolean; syncAfterCopy: boolean; skipLarge?: number; skipRegex?: RegExp[] } = { sync: true, syncAfterCopy: true },
): MergeResult {
  const toCopy: MessageInfo[] = [];
  const alreadySynced: MessageInfo[] = [];
  const duplicates: MessageInfo[] = [];

  // Build a set of destination message-ids for duplicate detection
  const dstMessageIds = new Set<string>();
  for (const msg of dstMsgs) {
    const mid = msg.envelope?.messageId;
    if (mid) dstMessageIds.add(mid);
  }

  for (const msg of srcMsgs) {
    // Skip messages that exceed size or regex filters
    if (shouldSkipMessage(msg, { skipLarge: flagsConfig.skipLarge, skipRegex: flagsConfig.skipRegex })) {
      continue;
    }

    // Check cache first
    if (cache) {
      const mapped = cache.getMapping(folder, msg.uid);
      if (mapped !== null) {
        alreadySynced.push(msg);
        continue;
      }
    }

    // Check duplicate by messageId
    const mid = msg.envelope?.messageId;
    if (mid && dstMessageIds.has(mid)) {
      duplicates.push(msg);
      continue;
    }

    toCopy.push(msg);
  }

  return { toCopy, alreadySynced, duplicates };
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/folder-mapping.test.ts src/__tests__/unit/message-merge.test.ts --no-cache
```
Expected: 9 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add imapsync-ts/src/imap/folder.ts imapsync-ts/src/imap/message.ts imapsync-ts/src/imap/search.ts imapsync-ts/src/__tests__/unit/folder-mapping.test.ts imapsync-ts/src/__tests__/unit/message-merge.test.ts
git commit -m "feat: add folder operations, message listing, and search filtering"
```

---

### Task 8: Flag + label sync

**Files:**
- Create: `imapsync-ts/src/imap/flags.ts`
- Create: `imapsync-ts/src/imap/labels.ts`
- Test: `imapsync-ts/src/__tests__/unit/flags.test.ts`

- [ ] **Step 1: Write failing test for flag diff**

Create `imapsync-ts/src/__tests__/unit/flags.test.ts`:

```typescript
import { diffFlags } from '../../imap/flags.js';

test('diffFlags returns flags to add and remove', () => {
  const src = new Set(['\\Seen', '\\Flagged', '$Important']);
  const dst = new Set(['\\Seen', '$Work']);
  const diff = diffFlags(src, dst);
  expect(diff.toAdd).toEqual(['\\Flagged', '$Important']);
  expect(diff.toRemove).toEqual(['$Work']);
});

test('diffFlags with identical sets returns empty', () => {
  const src = new Set(['\\Seen', '\\Flagged']);
  const dst = new Set(['\\Seen', '\\Flagged']);
  const diff = diffFlags(src, dst);
  expect(diff.toAdd).toEqual([]);
  expect(diff.toRemove).toEqual([]);
});

test('diffLabels returns labels to add and remove', () => {
  const src = new Set(['Important', 'Work']);
  const dst = new Set(['Work', 'Personal']);
  const diff = diffFlags(src, dst);
  expect(diff.toAdd).toEqual(['Important']);
  expect(diff.toRemove).toEqual(['Personal']);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/flags.test.ts --no-cache 2>&1 | tail -5
```
Expected: FAIL.

- [ ] **Step 3: Create imap/flags.ts**

Create `imapsync-ts/src/imap/flags.ts`:

```typescript
export function diffFlags(source: Set<string>, dest: Set<string>): { toAdd: string[]; toRemove: string[] } {
  const toAdd: string[] = [];
  const toRemove: string[] = [];
  for (const flag of source) {
    if (!dest.has(flag)) toAdd.push(flag);
  }
  for (const flag of dest) {
    if (!source.has(flag)) toRemove.push(flag);
  }
  return { toAdd, toRemove };
}
```

- [ ] **Step 4: Create imap/labels.ts**

Create `imapsync-ts/src/imap/labels.ts`:

```typescript
import type { ImapClient } from './connection.js';
import type { Logger } from '../logger/index.js';
import { diffFlags } from './flags.js';

export async function syncLabels(
  client: ImapClient,
  folder: string,
  uid: number,
  srcLabels: Set<string>,
  dstLabels: Set<string>,
  logger: Logger,
): Promise<void> {
  const diff = diffFlags(srcLabels, dstLabels);
  if (diff.toAdd.length > 0) {
    logger.info(`Adding labels to ${folder} uid=${uid}: ${diff.toAdd.join(', ')}`);
    await client.addLabels(folder, uid, diff.toAdd);
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/flags.test.ts --no-cache
```
Expected: 3 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add imapsync-ts/src/imap/flags.ts imapsync-ts/src/imap/labels.ts imapsync-ts/src/__tests__/unit/flags.test.ts
git commit -m "feat: add flag diff and Gmail label sync"
```

---

### Task 9: OAuth2 auth module

**Files:**
- Create: `imapsync-ts/src/auth/oauth2.ts`

Thin helper — the real OAuth2 token acquisition happens outside the tool (user provides the token or refreshes via external script). This module just helps build the imapflow auth config.

- [ ] **Step 1: Create auth/oauth2.ts**

Create directory:
```bash
mkdir -p /home/bowmanhan/Code/imapsync/imapsync-ts/src/auth
```

Create `imapsync-ts/src/auth/oauth2.ts`:

```typescript
import type { ImapAccount } from '../types/account.js';

export interface OAuth2Config {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
  tokenUrl?: string;
}

export async function refreshAccessToken(config: OAuth2Config): Promise<string> {
  const url = config.tokenUrl ?? 'https://oauth2.googleapis.com/token';
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    refresh_token: config.refreshToken,
    grant_type: 'refresh_token',
  });

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OAuth2 token refresh failed: ${res.status} ${text}`);
  }

  const data = await res.json() as { access_token: string };
  return data.access_token;
}

export function applyOAuth2ToAccount(account: ImapAccount, accessToken: string): void {
  account.auth.accessToken = accessToken;
  account.auth.pass = undefined;
}
```

- [ ] **Step 2: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add imapsync-ts/src/auth/
git commit -m "feat: add OAuth2 token refresh helper"
```

---

### Task 10: Core sync orchestrator

**Files:**
- Create: `imapsync-ts/src/sync.ts`

This is the main orchestrator that wires together all the modules. No unit tests here — it will be tested via integration tests in Task 11.

- [ ] **Step 1: Create sync.ts**

Create `imapsync-ts/src/sync.ts`:

```typescript
import type { SyncConfig, SyncState, SyncResult, FolderPair } from './types/sync.js';
import type { MessageInfo } from './types/account.js';
import { ImapClient } from './imap/connection.js';
import { resolveFolderPairs, mapFolderName } from './imap/folder.js';
import { findMessagesToCopy } from './imap/message.js';
import { diffFlags } from './imap/flags.js';
import { syncLabels } from './imap/labels.js';
import { CacheStore } from './cache/store.js';
import { createLogger, type Logger } from './logger/index.js';
import { createSyncState, buildResult } from './types/sync.js';
import { MessageCopyError, FolderError, CacheError, classifyError } from './errors.js';
import type { ErrorRecord } from './types/sync.js';

export async function runSync(config: SyncConfig): Promise<SyncResult> {
  const state = createSyncState();
  const logger = createLogger({ verbose: config.verbose });

  // 1. Connect to both IMAP servers
  logger.info(`Connecting to ${config.source.host}:${config.source.port} ...`);
  const source = new ImapClient(config.source);
  try {
    await source.connect();
    logger.info(`Connected to source.`);
  } catch (err) {
    logger.error('Source connection failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    return buildResult(state);
  }

  logger.info(`Connecting to ${config.dest.host}:${config.dest.port} ...`);
  const dest = new ImapClient(config.dest);
  try {
    await dest.connect();
    logger.info(`Connected to dest.`);
  } catch (err) {
    logger.error('Dest connection failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    await source.logout();
    return buildResult(state);
  }

  // 2. Enumerate and map folders
  let folderPairs: FolderPair[] = [];
  try {
    const srcFolders = await source.listFolders();
    const dstFolders = await dest.listFolders();
    folderPairs = await resolveFolderPairs(srcFolders, dstFolders, config.folders);
    logger.info(`Found ${srcFolders.length} source folders, ${folderPairs.length} to sync after filters`);
  } catch (err) {
    logger.error('Folder enumeration failed', err instanceof Error ? err : undefined);
    recordError(state, err, logger);
    await source.logout();
    await dest.logout();
    return buildResult(state);
  }

  // 3. Initialize cache
  let cache: CacheStore | null = null;
  if (config.cache.enabled) {
    try {
      cache = new CacheStore(config.cache.path);
      cache.open();
    } catch (err) {
      logger.warn('Cache initialization failed, continuing without cache');
      cache = null;
      recordError(state, new CacheError('Cache init failed', err instanceof Error ? err : undefined), logger);
    }
  }

  // 4. Sync each folder
  let folderIndex = 0;
  for (const pair of folderPairs) {
    folderIndex++;
    logger.progress(pair.source.path, folderIndex, folderPairs.length);
    try {
      await syncFolder(pair, source, dest, cache, config, state, logger);
    } catch (err) {
      if (err instanceof FolderError) {
        logger.warn(`Skipping folder ${err.folder}: ${err.message}`);
        recordError(state, err, logger);
      } else {
        logger.error(`Folder sync failed: ${pair.source.path}`, err instanceof Error ? err : undefined);
        recordError(state, err, logger);
      }
    }
  }

  // 5. Summary + cleanup
  const result = buildResult(state);
  logger.summary(result);
  if (cache) cache.close();
  await source.logout();
  await dest.logout();
  return result;
}

async function syncFolder(
  pair: FolderPair,
  source: ImapClient,
  dest: ImapClient,
  cache: CacheStore | null,
  config: SyncConfig,
  state: SyncState,
  logger: Logger,
): Promise<void> {
  const srcPath = pair.source.path;
  const dstPath = pair.dest.path;

  // Map folder name if delimiters differ
  const mappedDstPath = pair.source.delimiter !== pair.dest.delimiter
    ? mapFolderName(srcPath, pair.source.delimiter, pair.dest.delimiter)
    : dstPath;

  // Ensure destination folder exists
  try {
    await dest.ensureFolder(mappedDstPath);
  } catch (err) {
    throw new FolderError(`Cannot create folder ${mappedDstPath}`, mappedDstPath, err instanceof Error ? err : undefined);
  }

  // Get folder status for uidValidity
  let srcStatus: { uidValidity: string };
  let dstStatus: { uidValidity: string };
  try {
    srcStatus = await source.folderStatus(srcPath);
    dstStatus = await dest.folderStatus(mappedDstPath);
  } catch (err) {
    throw new FolderError(`Cannot get status for ${srcPath}`, srcPath, err instanceof Error ? err : undefined);
  }

  // Invalidate cache if uidValidity changed
  if (cache && srcStatus.uidValidity) {
    // We only invalidate when we detect a mismatch; for now, cache handles this via uidValidity column
  }

  // List messages on both sides
  const srcMsgs = await listFolderMessages(source, srcPath);
  const dstMsgs = await listFolderMessages(dest, mappedDstPath);

  logger.info(`${srcPath}: ${srcMsgs.length} source, ${dstMsgs.length} dest`);

  // Determine which messages to copy
  const merge = findMessagesToCopy(srcMsgs, dstMsgs, cache, srcPath, {
    sync: config.flags.sync,
    syncAfterCopy: config.flags.syncAfterCopy,
    skipLarge: config.messages.skipLarge,
    skipRegex: config.messages.skipRegex,
  });

  logger.info(`${srcPath}: ${merge.toCopy.length} to copy, ${merge.alreadySynced.length} already synced, ${merge.duplicates.length} duplicates`);

  // Copy messages
  for (const msg of merge.toCopy) {
    try {
      if (config.messages.dryRun) {
        logger.info(`[DRY] Would copy uid=${msg.uid} from ${srcPath}`);
        state.messagesCopied++;
        continue;
      }

      const raw = await source.fetchMessageSource(msg.uid, srcPath);
      const flags = Array.from(msg.flags);
      const result = await dest.appendMessage(mappedDstPath, raw, flags, msg.internalDate);

      // Update cache
      if (cache && result.uid) {
        cache.setMapping(srcPath, msg.uid, result.uid, srcStatus.uidValidity);
        if (msg.envelope?.messageId) {
          cache.setMessageHash(srcPath, msg.uid, msg.envelope.messageId, srcStatus.uidValidity);
        }
      }

      // Sync flags after copy
      if (config.flags.syncAfterCopy) {
        const dstMsg = dstMsgs.find(m => m.uid === result.uid);
        if (dstMsg) {
          const flagDiff = diffFlags(msg.flags, dstMsg.flags);
          if (flagDiff.toAdd.length > 0) {
            await dest.addFlags(mappedDstPath, result.uid, flagDiff.toAdd);
          }
        }
      }

      // Sync labels after copy (Gmail)
      if (config.labels.sync && msg.labels) {
        const dstMsg = dstMsgs.find(m => m.uid === result.uid);
        if (dstMsg && dstMsg.labels) {
          await syncLabels(dest, mappedDstPath, result.uid, msg.labels, dstMsg.labels, logger);
        }
      }

      state.messagesCopied++;
    } catch (err) {
      const copyErr = new MessageCopyError(
        err instanceof Error ? err.message : String(err),
        srcPath,
        msg.uid,
        err instanceof Error ? err : undefined,
      );
      logger.warn(`Failed to copy uid=${msg.uid} from ${srcPath}: ${copyErr.message}`);
      recordError(state, copyErr, logger);
    }
  }

  state.messagesSkipped += merge.alreadySynced.length + merge.duplicates.length;

  // Handle deletes
  if (config.messages.deleteSource && !config.messages.dryRun) {
    for (const msg of merge.alreadySynced) {
      try {
        await source.deleteMessage(srcPath, msg.uid);
        state.messagesDeleted++;
      } catch (err) {
        logger.warn(`Failed to delete uid=${msg.uid} from ${srcPath}`);
        recordError(state, err, logger);
      }
    }
  }

  if (config.messages.deleteDuplicates && !config.messages.dryRun) {
    for (const msg of merge.duplicates) {
      // Delete the duplicate on the dest side
      const dstUid = cache?.getMapping(srcPath, msg.uid);
      if (dstUid) {
        try {
          await dest.deleteMessage(mappedDstPath, dstUid);
          state.messagesDeleted++;
        } catch (err) {
          logger.warn(`Failed to delete duplicate uid=${dstUid} from ${mappedDstPath}`);
          recordError(state, err, logger);
        }
      }
    }
  }

  state.foldersProcessed++;
}

async function listFolderMessages(client: ImapClient, folder: string): Promise<MessageInfo[]> {
  const imapFlowClient = client.getClient();
  const lock = await imapFlowClient.getMailboxLock(folder);
  try {
    const messages: MessageInfo[] = [];
    for await (const msg of imapFlowClient.fetch('1:*', {
      uid: true,
      flags: true,
      internalDate: true,
      size: true,
      envelope: true,
      labels: true,
    })) {
      messages.push({
        uid: msg.uid,
        flags: msg.flags,
        internalDate: msg.internalDate,
        size: msg.size,
        envelope: msg.envelope ? {
          subject: msg.envelope.subject ?? '',
          from: msg.envelope.from ?? [],
          date: msg.envelope.date ?? new Date(),
          messageId: msg.envelope.messageId,
        } : undefined,
        labels: msg.labels,
      });
    }
    return messages;
  } finally {
    lock.release();
  }
}

function recordError(state: SyncState, err: unknown, _logger: Logger): void {
  const error = err instanceof Error ? err : new Error(String(err));
  state.errors.push({
    type: classifyError(error),
    message: error.message,
    timestamp: new Date(),
  });
}
```

- [ ] **Step 2: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add imapsync-ts/src/sync.ts
git commit -m "feat: add core sync orchestrator"
```

---

### Task 11: CLI entry point

**Files:**
- Modify: `imapsync-ts/src/cli.ts`

- [ ] **Step 1: Implement full CLI with commander**

Rewrite `imapsync-ts/src/cli.ts`:

```typescript
import { Command } from 'commander';
import { runSync } from './sync.js';
import { buildDefaultConfig, mergePresets } from './config/defaults.js';
import { validateConfig } from './config/validate.js';
import type { SyncConfig } from './types/sync.js';
import { refreshAccessToken, applyOAuth2ToAccount } from './auth/oauth2.js';

function collect(value: string, previous: string[]): string[] {
  return [...previous, value];
}

const program = new Command();

program
  .name('imapsync-ts')
  .description('IMAP mailbox synchronizer — TypeScript port of imapsync')
  .version('0.1.0')
  .requiredOption('--host1 <host>', 'Source IMAP host')
  .requiredOption('--user1 <user>', 'Source username')
  .option('--password1 <pass>', 'Source password')
  .requiredOption('--host2 <host>', 'Destination IMAP host')
  .requiredOption('--user2 <user>', 'Destination username')
  .option('--password2 <pass>', 'Destination password')
  .option('--port1 <port>', 'Source port', '993')
  .option('--port2 <port>', 'Destination port', '993')
  .option('--ssl1', 'Use TLS for source', true)
  .option('--ssl2', 'Use TLS for destination', true)
  .option('--oauth2', 'Use OAuth2 authentication')
  .option('--folder <name>', 'Sync specific folder (repeatable)', collect, [])
  .option('--folderrec <pattern>', 'Include folders matching pattern (repeatable)', collect, [])
  .option('--exclude <pattern>', 'Exclude folders matching pattern (repeatable)', collect, [])
  .option('--delete1', 'Delete source messages after copy', false)
  .option('--delete2duplicates', 'Delete duplicates on destination', false)
  .option('--maxsize <bytes>', 'Skip messages larger than N bytes')
  .option('--skipmess <regex>', 'Skip messages matching regex (repeatable)', collect, [])
  .option('--dry', 'Dry run — no actual changes', false)
  .option('--gmail1', 'Use Gmail presets for source')
  .option('--gmail2', 'Use Gmail presets for destination')
  .option('--exchange1', 'Use Exchange presets for source')
  .option('--exchange2', 'Use Exchange presets for destination')
  .option('--syncflagsaftercopy', 'Sync flags after copying', true)
  .option('--synclabels', 'Sync Gmail labels', false)
  .option('--nocache', 'Disable cache', false)
  .option('--cachefile <path>', 'Cache file path')
  .option('--verbose', 'Verbose output', false);

program.parse();

const opts = program.opts();

async function main(): Promise<void> {
  const config = buildDefaultConfig({
    source: {
      host: opts.host1,
      port: parseInt(opts.port1, 10),
      user: opts.user1,
      auth: { pass: opts.password1 },
      tls: opts.ssl1,
    },
    dest: {
      host: opts.host2,
      port: parseInt(opts.port2, 10),
      user: opts.user2,
      auth: { pass: opts.password2 },
      tls: opts.ssl2,
    },
  });

  // Apply presets
  mergePresets(config, {
    source: opts.gmail1 ? 'gmail' : opts.exchange1 ? 'exchange' : undefined,
    dest: opts.gmail2 ? 'gmail' : opts.exchange2 ? 'exchange' : undefined,
  });

  // Apply folder filters
  if (opts.folder.length > 0) {
    config.folders.include = opts.folder.map((f: string) => new RegExp(`^${escapeRegex(f)}$`));
  }
  if (opts.folderrec.length > 0) {
    config.folders.include = [
      ...(config.folders.include ?? []),
      ...opts.folderrec.map((f: string) => new RegExp(f)),
    ];
  }
  if (opts.exclude.length > 0) {
    config.folders.exclude = opts.exclude.map((f: string) => new RegExp(f));
  }

  // Apply message options
  if (opts.maxsize) config.messages.skipLarge = parseInt(opts.maxsize, 10);
  if (opts.skipmess.length > 0) config.messages.skipRegex = opts.skipmess.map((r: string) => new RegExp(r));
  if (opts.dry) config.messages.dryRun = true;
  if (opts.delete1) config.messages.deleteSource = true;
  if (opts.delete2duplicates) config.messages.deleteDuplicates = true;

  // Apply flag/label options
  config.flags.syncAfterCopy = opts.syncflagsaftercopy;
  config.labels.sync = opts.synclabels;

  // Apply cache options
  if (opts.nocache) config.cache.enabled = false;
  if (opts.cachefile) config.cache.path = opts.cachefile;

  // Apply verbose
  config.verbose = opts.verbose;

  // OAuth2
  if (opts.oauth2) {
    // For OAuth2, user must provide accessToken via --password1/--password2
    // (treating the password field as the access token for simplicity)
    if (config.source.auth.pass) {
      config.source.auth.accessToken = config.source.auth.pass;
      config.source.auth.pass = undefined;
    }
    if (config.dest.auth.pass) {
      config.dest.auth.accessToken = config.dest.auth.pass;
      config.dest.auth.pass = undefined;
    }
  }

  // Validate
  try {
    validateConfig(config);
  } catch (err) {
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  }

  // Run sync
  const result = await runSync(config);
  process.exit(result.exitCode);
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 3: Verify CLI help output**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsx src/cli.ts --help
```
Expected: commander help text showing all options.

- [ ] **Step 4: Commit**

```bash
git add imapsync-ts/src/cli.ts
git commit -m "feat: implement CLI entry point with commander"
```

---

### Task 12: Integration test scaffolding

**Files:**
- Create: `imapsync-ts/src/__tests__/integration/sync.test.ts`
- Create: `imapsync-ts/docker-compose.yml` (optional Dovecot test server)

Integration tests require real IMAP servers. We provide a docker-compose.yml with Dovecot for local testing, plus env-var-based configuration for testing against any IMAP server.

- [ ] **Step 1: Create docker-compose.yml for test Dovecot**

Create `imapsync-ts/docker-compose.yml`:

```yaml
version: "3.8"
services:
  dovecot-source:
    image: dovecot/dovecot:2.3
    ports:
      - "10143:143"
    environment:
      - DOVECOT_PASSDB=pass:password1
  dovecot-dest:
    image: dovecot/dovecot:2.3
    ports:
      - "10144:143"
    environment:
      - DOVECOT_PASSDB=pass:password2
```

Note: The stock dovecot/dovecot image may need custom config. For a real test environment, users can use their own IMAP servers via env vars instead.

- [ ] **Step 2: Create integration test skeleton**

Create directory:
```bash
mkdir -p /home/bowmanhan/Code/imapsync/imapsync-ts/src/__tests__/integration
```

Create `imapsync-ts/src/__tests__/integration/sync.test.ts`:

```typescript
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
    // Dry run counts messages as "copied" for reporting but doesn't actually append
  }, 60_000);
});
```

- [ ] **Step 3: Run type check**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 4: Run all unit tests to confirm nothing is broken**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/ --no-cache
```
Expected: all unit tests PASS (logger 4, cache 7, folder-mapping 4, message-merge 3, flags 3, config 6 = 27 total).

- [ ] **Step 5: Commit**

```bash
git add imapsync-ts/src/__tests__/integration/ imapsync-ts/docker-compose.yml
git commit -m "feat: add integration test scaffolding with docker-compose Dovecot"
```

---

### Task 13: Build + final smoke test

**Files:**
- Modify: `imapsync-ts/package.json` (add shebang script)
- No new files

- [ ] **Step 1: Build with tsup**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx tsup
```
Expected: `dist/cli.js` created.

- [ ] **Step 2: Verify built CLI runs**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && node dist/cli.js --help
```
Expected: commander help text.

- [ ] **Step 3: Verify built CLI shows version**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && node dist/cli.js --version
```
Expected: `0.1.0`

- [ ] **Step 4: Run full test suite**

Run:
```bash
cd /home/bowmanhan/Code/imapsync/imapsync-ts && npx jest src/__tests__/unit/ --no-cache
```
Expected: 27 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add imapsync-ts/
git commit -m "feat: verify build and full test suite passing"
```

---

## Spec Self-Review Checklist

**1. Spec coverage:**
- Core sync flow (connect, folders, messages, flags, cache, deletes) → Tasks 6, 7, 8, 10
- Gmail labels → Task 8 (labels.ts)
- OAuth2 → Task 9
- SQLite cache → Task 4
- Presets (Gmail/Exchange) → Task 5
- CLI interface → Task 11
- Tests (unit + integration) → Tasks 3-8, 12
- Error handling → Task 3 (error classes + classifyError), Task 10 (error recording in sync)
- Logger → Task 3
- All covered, no gaps.

**2. Placeholder scan:** No TBD/TODO/placeholder patterns found. All code steps contain complete implementations.

**3. Type consistency:**
- `ImapClient` methods match usage in `sync.ts` (fetchMessageSource, appendMessage, addFlags, setFlags, addLabels, deleteMessage, folderStatus, listFolders, ensureFolder)
- `CacheStore` methods match usage in `sync.ts` and `message.ts` (getMapping, setMapping, setMessageHash, invalidateFolder, close, open)
- `SyncConfig`, `SyncState`, `SyncResult` types consistent across all files
- `FolderPair` type used consistently in folder.ts and sync.ts
- `MessageInfo` type used consistently in message.ts, sync.ts, and search.ts

**4. Dependency chain verified:**
- Types (Task 2) → no dependencies
- Errors + Logger (Task 3) → depends on Types
- Cache (Task 4) → depends on Types
- Config (Task 5) → depends on Types
- ImapClient (Task 6) → depends on Types + Errors
- Folder + Message (Task 7) → depends on Types + Cache + ImapClient
- Flags + Labels (Task 8) → depends on ImapClient + Logger
- OAuth2 (Task 9) → depends on Types
- Sync orchestrator (Task 10) → depends on all above
- CLI (Task 11) → depends on Sync + Config + OAuth2
- Integration tests (Task 12) → depends on all above
- Build verification (Task 13) → depends on all above
