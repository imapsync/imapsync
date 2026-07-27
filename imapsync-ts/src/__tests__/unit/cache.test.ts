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
