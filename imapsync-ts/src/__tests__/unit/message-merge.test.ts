import { findMessagesToCopy } from '../../imap/message.js';
import type { MessageInfo } from '../../types/account.js';
import type { CacheStore } from '../../cache/store.js';

function makeMsg(uid: number, opts: { size?: number; messageId?: string; subject?: string; from?: string[] } = {}): MessageInfo {
  return {
    uid,
    flags: new Set(['\\Seen']),
    internalDate: new Date(),
    size: opts.size ?? 1000,
    envelope: (opts.messageId || opts.subject || opts.from)
      ? {
          subject: opts.subject ?? '',
          from: (opts.from ?? []).map(a => ({ address: a })),
          date: new Date(),
          messageId: opts.messageId,
        }
      : undefined,
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
  const src = [makeMsg(1, { size: 500 }), makeMsg(2, { size: 5000 })];
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
  const src = [makeMsg(1, { messageId: '<msg1@example>' }), makeMsg(2, { messageId: '<msg2@example>' })];
  const dst = [makeMsg(10, { messageId: '<msg1@example>' })];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.toCopy.map(m => m.uid)).toEqual([2]);
  expect(result.duplicates.map(m => m.uid)).toEqual([1]);
});

test('skipRegex filters messages matching subject — excluded from all lists', () => {
  const src = [
    makeMsg(1, { subject: 'Important meeting' }),
    makeMsg(2, { subject: 'SPAM offer!!!' }),
    makeMsg(3, { subject: 'Project update' }),
  ];
  const dst: MessageInfo[] = [];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true, skipRegex: [/spam/i] });
  expect(result.toCopy.map(m => m.uid)).toEqual([1, 3]);
  expect(result.alreadySynced).toEqual([]);
  expect(result.duplicates).toEqual([]);
});

test('skipRegex filters messages matching from address — excluded from all lists', () => {
  const src = [
    makeMsg(1, { from: ['colleague@work.com'] }),
    makeMsg(2, { from: ['spammer@spamcorp.com'] }),
    makeMsg(3, { from: ['boss@work.com'] }),
  ];
  const dst: MessageInfo[] = [];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true, skipRegex: [/spamcorp/i] });
  expect(result.toCopy.map(m => m.uid)).toEqual([1, 3]);
  expect(result.alreadySynced).toEqual([]);
  expect(result.duplicates).toEqual([]);
});

test('multiple source messages with same messageId as dest — both go to duplicates', () => {
  const src = [
    makeMsg(1, { messageId: '<dup@example>' }),
    makeMsg(2, { messageId: '<dup@example>' }),
    makeMsg(3, { messageId: '<unique@example>' }),
  ];
  const dst = [makeMsg(10, { messageId: '<dup@example>' })];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.duplicates.map(m => m.uid)).toEqual([1, 2]);
  expect(result.toCopy.map(m => m.uid)).toEqual([3]);
  expect(result.alreadySynced).toEqual([]);
});

test('messages with no envelope (no messageId) go to toCopy, not duplicates', () => {
  const src = [
    makeMsg(1),  // no envelope
    makeMsg(2, { messageId: '<exists@example>' }),
  ];
  const dst = [makeMsg(10, { messageId: '<exists@example>' })];
  const result = findMessagesToCopy(src, dst, null, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.toCopy.map(m => m.uid)).toEqual([1]);
  expect(result.duplicates.map(m => m.uid)).toEqual([2]);
});

test('cache returns null for a UID — message goes to toCopy', () => {
  const src = [makeMsg(1), makeMsg(2)];
  const dst: MessageInfo[] = [];
  const cache = makeCache({ 1: 100 }); // UID 2 not in cache
  const result = findMessagesToCopy(src, dst, cache as CacheStore, 'INBOX', { sync: true, syncAfterCopy: true });
  expect(result.alreadySynced.map(m => m.uid)).toEqual([1]);
  expect(result.toCopy.map(m => m.uid)).toEqual([2]);
});

test('mix of scenarios — cache, duplicates, skip, and toCopy', () => {
  const src = [
    makeMsg(1, { messageId: '<cached@example>' }),                          // in cache → alreadySynced
    makeMsg(2, { messageId: '<dup@example>' }),                             // duplicate in dst → duplicates
    makeMsg(3, { subject: 'SPAM buy now', messageId: '<skip@example>' }),   // skipRegex → skipped
    makeMsg(4, { messageId: '<new@example>' }),                             // not in cache, not dup → toCopy
    makeMsg(5, { size: 9000 }),                                             // skipLarge → skipped
    makeMsg(6),                                                             // no envelope, no cache → toCopy
  ];
  const dst = [
    makeMsg(10, { messageId: '<dup@example>' }),
  ];
  const cache = makeCache({ 1: 100 });
  const result = findMessagesToCopy(src, dst, cache as CacheStore, 'INBOX', {
    sync: true,
    syncAfterCopy: true,
    skipLarge: 5000,
    skipRegex: [/spam/i],
  });
  expect(result.alreadySynced.map(m => m.uid)).toEqual([1]);
  expect(result.duplicates.map(m => m.uid)).toEqual([2]);
  expect(result.toCopy.map(m => m.uid)).toEqual([4, 6]);
});
