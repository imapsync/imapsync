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
