import { runSync } from '../../sync.js';
import type { SyncConfig } from '../../types/sync.js';
import type { MessageInfo, FolderInfo, AppendResult } from '../../types/account.js';
import { FolderError, ImapConnectionError, ImapAuthError } from '../../errors.js';

// ---------------------------------------------------------------------------
// Module mocks
//
// jest.mock() factories are hoisted before variable declarations, so they
// must be fully self-contained. We create mock objects inside the factory
// and attach them as extra exports (__srcMock, __dstMock, etc.) so we can
// retrieve them after import.
// ---------------------------------------------------------------------------

jest.mock('../../imap/connection.js', () => {
  // Helper: create an ImapFlow-like mock that listFolderMessages() needs.
  // listFolderMessages does:
  //   const imapFlowClient = client.getClient();
  //   const lock = await imapFlowClient.getMailboxLock(folder);
  //   const mb = imapFlowClient.mailbox;
  //   if (!mb || mb.exists === 0) return [];
  //   for await (const msg of imapFlowClient.fetch('1:*', {...})) { ... }
  //   lock.release();
  function makeImapFlowMock(messages: MessageInfo[] = []) {
    const lock = { release: jest.fn() };
    const asyncIterable = {
      [Symbol.asyncIterator]() {
        let i = 0;
        return {
          next: async () => {
            if (i >= messages.length) return { done: true, value: undefined };
            const msg = messages[i++];
            return {
              done: false,
              value: {
                uid: msg.uid,
                flags: msg.flags,
                internalDate: msg.internalDate,
                size: msg.size,
                envelope: msg.envelope ? {
                  subject: msg.envelope.subject,
                  from: msg.envelope.from,
                  date: msg.envelope.date,
                  messageId: msg.envelope.messageId,
                } : undefined,
                labels: msg.labels,
              },
            };
          },
        };
      },
    };
    return {
      getMailboxLock: jest.fn().mockResolvedValue(lock),
      mailbox: { exists: messages.length, path: 'INBOX' },
      fetch: jest.fn().mockReturnValue(asyncIterable),
    };
  }

  // Source client mock
  const srcImapFlow = makeImapFlowMock([]);
  const srcMock = {
    connect: jest.fn().mockResolvedValue(undefined),
    logout: jest.fn().mockResolvedValue(undefined),
    listFolders: jest.fn().mockResolvedValue([]),
    folderStatus: jest.fn().mockResolvedValue({ uidValidity: '12345' }),
    fetchMessageSource: jest.fn().mockResolvedValue(Buffer.from('')),
    deleteMessage: jest.fn().mockResolvedValue(undefined),
    getClient: jest.fn().mockReturnValue(srcImapFlow),
    ensureFolder: jest.fn().mockResolvedValue(undefined),
    appendMessage: jest.fn().mockResolvedValue({ destination: '', uid: 0, uidValidity: '' }),
    addFlags: jest.fn().mockResolvedValue(undefined),
    addLabels: jest.fn().mockResolvedValue(undefined),
  };

  // Dest client mock
  const dstImapFlow = makeImapFlowMock([]);
  const dstMock = {
    connect: jest.fn().mockResolvedValue(undefined),
    logout: jest.fn().mockResolvedValue(undefined),
    listFolders: jest.fn().mockResolvedValue([]),
    folderStatus: jest.fn().mockResolvedValue({ uidValidity: '12345' }),
    fetchMessageSource: jest.fn().mockResolvedValue(Buffer.from('')),
    deleteMessage: jest.fn().mockResolvedValue(undefined),
    getClient: jest.fn().mockReturnValue(dstImapFlow),
    ensureFolder: jest.fn().mockResolvedValue(undefined),
    appendMessage: jest.fn().mockResolvedValue({ destination: '', uid: 0, uidValidity: '' }),
    addFlags: jest.fn().mockResolvedValue(undefined),
    addLabels: jest.fn().mockResolvedValue(undefined),
  };

  let callCount = 0;
  return {
    ImapClient: jest.fn().mockImplementation(() => {
      callCount++;
      return callCount === 1 ? srcMock : dstMock;
    }),
    __srcMock: srcMock,
    __dstMock: dstMock,
    __srcImapFlow: srcImapFlow,
    __dstImapFlow: dstImapFlow,
    __resetCallCount: () => { callCount = 0; },
  };
});

jest.mock('../../cache/store.js', () => {
  const mockCache = {
    open: jest.fn(),
    close: jest.fn(),
    getMapping: jest.fn().mockReturnValue(null),
    setMapping: jest.fn(),
    setMessageHash: jest.fn(),
  };
  return {
    CacheStore: jest.fn().mockImplementation(() => mockCache),
    __mockCache: mockCache,
  };
});

jest.mock('../../logger/index.js', () => {
  const mockLogger = {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    progress: jest.fn(),
    summary: jest.fn(),
  };
  return {
    createLogger: jest.fn().mockReturnValue(mockLogger),
    __mockLogger: mockLogger,
  };
});

jest.mock('../../imap/folder.js', () => ({
  resolveFolderPairs: jest.fn().mockResolvedValue([]),
  mapFolderName: (path: string, srcDelim: string, dstDelim: string) => {
    if (srcDelim === dstDelim) return path;
    return path.split(srcDelim).join(dstDelim);
  },
}));

jest.mock('../../imap/message.js', () => ({
  findMessagesToCopy: jest.fn().mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] }),
}));

jest.mock('../../imap/flags.js', () => ({
  diffFlags: jest.fn().mockReturnValue({ toAdd: [], toRemove: [] }),
}));

jest.mock('../../imap/labels.js', () => ({
  syncLabels: jest.fn().mockResolvedValue(undefined),
}));

// ---------------------------------------------------------------------------
// Retrieve mock references
// ---------------------------------------------------------------------------

// eslint-disable-next-line @typescript-eslint/no-require-imports
const connMod = require('../../imap/connection.js') as {
  ImapClient: jest.Mock;
  __srcMock: {
    connect: jest.Mock;
    logout: jest.Mock;
    listFolders: jest.Mock;
    folderStatus: jest.Mock;
    fetchMessageSource: jest.Mock;
    deleteMessage: jest.Mock;
    getClient: jest.Mock;
    ensureFolder: jest.Mock;
    appendMessage: jest.Mock;
    addFlags: jest.Mock;
    addLabels: jest.Mock;
  };
  __dstMock: {
    connect: jest.Mock;
    logout: jest.Mock;
    listFolders: jest.Mock;
    folderStatus: jest.Mock;
    fetchMessageSource: jest.Mock;
    deleteMessage: jest.Mock;
    getClient: jest.Mock;
    ensureFolder: jest.Mock;
    appendMessage: jest.Mock;
    addFlags: jest.Mock;
    addLabels: jest.Mock;
  };
  __srcImapFlow: {
    getMailboxLock: jest.Mock;
    mailbox: { exists: number; path: string };
    fetch: jest.Mock;
  };
  __dstImapFlow: {
    getMailboxLock: jest.Mock;
    mailbox: { exists: number; path: string };
    fetch: jest.Mock;
  };
  __resetCallCount: () => void;
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const cacheModule = require('../../cache/store.js') as {
  CacheStore: jest.Mock;
  __mockCache: {
    open: jest.Mock;
    close: jest.Mock;
    getMapping: jest.Mock;
    setMapping: jest.Mock;
    setMessageHash: jest.Mock;
  };
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const loggerModule = require('../../logger/index.js') as {
  createLogger: jest.Mock;
  __mockLogger: {
    info: jest.Mock;
    warn: jest.Mock;
    error: jest.Mock;
    progress: jest.Mock;
    summary: jest.Mock;
  };
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const folderModule = require('../../imap/folder.js') as {
  resolveFolderPairs: jest.Mock;
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const messageModule = require('../../imap/message.js') as {
  findMessagesToCopy: jest.Mock;
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const flagsModule = require('../../imap/flags.js') as {
  diffFlags: jest.Mock;
};

// eslint-disable-next-line @typescript-eslint/no-require-imports
const labelsModule = require('../../imap/labels.js') as {
  syncLabels: jest.Mock;
};

// Short aliases
const src = connMod.__srcMock;
const dst = connMod.__dstMock;
const srcFlow = connMod.__srcImapFlow;
const dstFlow = connMod.__dstImapFlow;
const cache = cacheModule.__mockCache;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeConfig(overrides: Partial<SyncConfig> = {}): SyncConfig {
  return {
    source: { host: 'src.test', port: 993, user: 'src', auth: { pass: 'p' }, tls: true },
    dest: { host: 'dst.test', port: 993, user: 'dst', auth: { pass: 'p' }, tls: true },
    folders: {},
    messages: { dryRun: false, deleteSource: false, deleteDuplicates: false },
    flags: { sync: true, syncAfterCopy: false },
    labels: { sync: false },
    cache: { enabled: false, path: ':memory:' },
    verbose: false,
    ...overrides,
  };
}

function makeMsg(uid: number, flags: string[] = ['\\Seen'], messageId?: string, labels?: string[]): MessageInfo {
  return {
    uid,
    flags: new Set(flags),
    internalDate: new Date('2025-01-01'),
    size: 500,
    envelope: messageId
      ? { subject: 'Test', from: [{ address: 'a@b.c' }], date: new Date(), messageId }
      : undefined,
    labels: labels ? new Set(labels) : undefined,
  };
}

function makeFolderPair(srcPath = 'INBOX', dstPath = 'INBOX', srcDelim = '.', dstDelim = '.'): { source: FolderInfo; dest: FolderInfo } {
  return {
    source: { path: srcPath, delimiter: srcDelim, subscribed: true },
    dest: { path: dstPath, delimiter: dstDelim, subscribed: true },
  };
}

/** Set up an ImapFlow mock to return the given messages via listFolderMessages */
function setImapFlowMessages(flowMock: typeof srcFlow, messages: MessageInfo[]): void {
  flowMock.mailbox = { exists: messages.length, path: 'INBOX' };
  const asyncIterable = {
    [Symbol.asyncIterator]() {
      let i = 0;
      return {
        next: async () => {
          if (i >= messages.length) return { done: true, value: undefined };
          const msg = messages[i++];
          return {
            done: false,
            value: {
              uid: msg.uid,
              flags: msg.flags,
              internalDate: msg.internalDate,
              size: msg.size,
              envelope: msg.envelope ? {
                subject: msg.envelope.subject,
                from: msg.envelope.from,
                date: msg.envelope.date,
                messageId: msg.envelope.messageId,
              } : undefined,
              labels: msg.labels,
            },
          };
        },
      };
    },
  };
  flowMock.fetch.mockReturnValue(asyncIterable);
}

// ---------------------------------------------------------------------------
// Setup / Teardown
// ---------------------------------------------------------------------------

beforeEach(() => {
  jest.clearAllMocks();
  connMod.__resetCallCount();

  // Default: both connections succeed
  src.connect.mockResolvedValue(undefined);
  dst.connect.mockResolvedValue(undefined);
  src.logout.mockResolvedValue(undefined);
  dst.logout.mockResolvedValue(undefined);

  // Default folder setup: one folder pair
  src.listFolders.mockResolvedValue([{ path: 'INBOX', delimiter: '.' }]);
  dst.listFolders.mockResolvedValue([{ path: 'INBOX', delimiter: '.' }]);
  folderModule.resolveFolderPairs.mockResolvedValue([makeFolderPair()]);

  // Default folder status
  src.folderStatus.mockResolvedValue({ uidValidity: '12345' });
  dst.folderStatus.mockResolvedValue({ uidValidity: '12345' });

  // Default: empty mailboxes (listFolderMessages returns [])
  setImapFlowMessages(srcFlow, []);
  setImapFlowMessages(dstFlow, []);

  // Default merge result: nothing to copy
  messageModule.findMessagesToCopy.mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] });

  // Default flags diff: no changes
  flagsModule.diffFlags.mockReturnValue({ toAdd: [], toRemove: [] });

  // Default syncLabels
  labelsModule.syncLabels.mockResolvedValue(undefined);

  // Default cache behavior
  cache.getMapping.mockReturnValue(null);
});

// ---------------------------------------------------------------------------
// Tests: Connection handling
// ---------------------------------------------------------------------------

test('runSync returns error result when source connection fails', async () => {
  src.connect.mockRejectedValue(new ImapConnectionError('refused'));
  const result = await runSync(makeConfig());
  expect(result.success).toBe(false);
  expect(result.exitCode).toBe(1);
  expect(result.state.errors.length).toBe(1);
  expect(result.state.errors[0].type).toBe('connection');
});

test('runSync returns auth error when dest auth fails', async () => {
  dst.connect.mockRejectedValue(new ImapAuthError('bad credentials'));
  const result = await runSync(makeConfig());
  expect(result.success).toBe(false);
  expect(result.exitCode).toBe(2);
  expect(result.state.errors[0].type).toBe('auth');
  // Source should still be logged out
  expect(src.logout).toHaveBeenCalled();
});

test('runSync logs out both connections on folder enumeration failure', async () => {
  src.listFolders.mockRejectedValue(new Error('list failed'));
  const result = await runSync(makeConfig());
  expect(src.logout).toHaveBeenCalled();
  expect(dst.logout).toHaveBeenCalled();
  expect(result.state.errors.length).toBe(1);
});

// ---------------------------------------------------------------------------
// Tests: Copy loop
// ---------------------------------------------------------------------------

test('runSync copies messages and updates cache', async () => {
  const msg = makeMsg(1, ['\\Seen'], '<msg1@example>');
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [msg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);

  const config = makeConfig({ cache: { enabled: true, path: ':memory:' } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(src.fetchMessageSource).toHaveBeenCalledWith(1, 'INBOX');
  expect(dst.appendMessage).toHaveBeenCalledWith('INBOX', expect.any(Buffer), ['\\Seen'], expect.any(Date));
  expect(cache.setMapping).toHaveBeenCalledWith('INBOX', 1, 100, '12345');
  expect(cache.setMessageHash).toHaveBeenCalledWith('INBOX', 1, '<msg1@example>', '12345');
});

test('runSync dry run increments counter but does not fetch or append', async () => {
  const msg = makeMsg(1, ['\\Seen'], '<msg1@example>');
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [msg],
    alreadySynced: [],
    duplicates: [],
  });

  const config = makeConfig({ messages: { dryRun: true, deleteSource: false, deleteDuplicates: false } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(src.fetchMessageSource).not.toHaveBeenCalled();
  expect(dst.appendMessage).not.toHaveBeenCalled();
});

test('runSync copies multiple messages in order', async () => {
  const msg1 = makeMsg(1);
  const msg2 = makeMsg(2);
  const msg3 = makeMsg(3);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [msg1, msg2, msg3],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);

  const result = await runSync(makeConfig());
  expect(result.state.messagesCopied).toBe(3);
  expect(src.fetchMessageSource).toHaveBeenCalledTimes(3);
  expect(dst.appendMessage).toHaveBeenCalledTimes(3);
});

test('runSync copies message without messageId without calling setMessageHash', async () => {
  const msg = makeMsg(5); // no messageId
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [msg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 50, uidValidity: 'v' } as AppendResult);

  const config = makeConfig({ cache: { enabled: true, path: ':memory:' } });
  await runSync(config);

  expect(cache.setMapping).toHaveBeenCalledWith('INBOX', 5, 50, '12345');
  expect(cache.setMessageHash).not.toHaveBeenCalled();
});

// ---------------------------------------------------------------------------
// Tests: Flag sync after copy
// ---------------------------------------------------------------------------

test('runSync with syncAfterCopy calls addFlags when dest message is found', async () => {
  const srcMsg = makeMsg(1, ['\\Seen', '\\Flagged']);
  const dstMsg = makeMsg(100, ['\\Seen']); // dest already has this msg
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [srcMsg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);
  flagsModule.diffFlags.mockReturnValue({ toAdd: ['\\Flagged'], toRemove: [] });

  // Make listFolderMessages on dest return the dest message so
  // dstMsgs.find(m => m.uid === 100) succeeds
  setImapFlowMessages(dstFlow, [dstMsg]);

  const config = makeConfig({ flags: { sync: true, syncAfterCopy: true } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(dst.addFlags).toHaveBeenCalledWith('INBOX', 100, ['\\Flagged']);
});

test('runSync with syncAfterCopy does not call addFlags when dest message not found', async () => {
  const srcMsg = makeMsg(1, ['\\Seen', '\\Flagged']);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [srcMsg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);
  flagsModule.diffFlags.mockReturnValue({ toAdd: ['\\Flagged'], toRemove: [] });

  // dest mailbox is empty, so the appended msg won't be found
  setImapFlowMessages(dstFlow, []);

  const config = makeConfig({ flags: { sync: true, syncAfterCopy: true } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(dst.addFlags).not.toHaveBeenCalled();
});

// ---------------------------------------------------------------------------
// Tests: Label sync after copy
// ---------------------------------------------------------------------------

test('runSync with label sync calls syncLabels when both source and dest have labels', async () => {
  const srcMsg = makeMsg(1, ['\\Seen'], '<m@x>', ['Important', 'Work']);
  const dstMsg = makeMsg(100, ['\\Seen'], '<m@x>', ['Work']);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [srcMsg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);

  // Make listFolderMessages on dest return the dest message
  setImapFlowMessages(dstFlow, [dstMsg]);

  const config = makeConfig({ labels: { sync: true } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(labelsModule.syncLabels).toHaveBeenCalledWith(
    expect.anything(), // dest client
    'INBOX',
    100,
    srcMsg.labels,
    dstMsg.labels,
    expect.anything(), // logger
  );
});

test('runSync with label sync does not call syncLabels when dest has no labels', async () => {
  const srcMsg = makeMsg(1, ['\\Seen'], '<m@x>', ['Important']);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [srcMsg],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource.mockResolvedValue(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 100, uidValidity: 'v' } as AppendResult);

  // dest mailbox is empty
  setImapFlowMessages(dstFlow, []);

  const config = makeConfig({ labels: { sync: true } });
  const result = await runSync(config);

  expect(result.state.messagesCopied).toBe(1);
  expect(labelsModule.syncLabels).not.toHaveBeenCalled();
});

// ---------------------------------------------------------------------------
// Tests: Delete source
// ---------------------------------------------------------------------------

test('runSync deletes already-synced source messages when deleteSource is true', async () => {
  const alreadySynced = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [alreadySynced],
    duplicates: [],
  });

  const config = makeConfig({ messages: { dryRun: false, deleteSource: true, deleteDuplicates: false } });
  const result = await runSync(config);

  expect(src.deleteMessage).toHaveBeenCalledWith('INBOX', 1);
  expect(result.state.messagesDeleted).toBe(1);
});

test('runSync does not delete source messages in dry run mode', async () => {
  const alreadySynced = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [alreadySynced],
    duplicates: [],
  });

  const config = makeConfig({ messages: { dryRun: true, deleteSource: true, deleteDuplicates: false } });
  const result = await runSync(config);

  expect(src.deleteMessage).not.toHaveBeenCalled();
  expect(result.state.messagesDeleted).toBe(0);
});

test('runSync deletes multiple already-synced source messages', async () => {
  const alreadySynced = [makeMsg(1), makeMsg(2), makeMsg(3)];
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced,
    duplicates: [],
  });

  const config = makeConfig({ messages: { dryRun: false, deleteSource: true, deleteDuplicates: false } });
  const result = await runSync(config);

  expect(src.deleteMessage).toHaveBeenCalledTimes(3);
  expect(result.state.messagesDeleted).toBe(3);
});

// ---------------------------------------------------------------------------
// Tests: Delete duplicates
// ---------------------------------------------------------------------------

test('runSync deletes duplicate messages on dest when deleteDuplicates is true', async () => {
  const dup = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [],
    duplicates: [dup],
  });
  cache.getMapping.mockReturnValue(200);

  const config = makeConfig({
    messages: { dryRun: false, deleteSource: false, deleteDuplicates: true },
    cache: { enabled: true, path: ':memory:' },
  });
  const result = await runSync(config);

  expect(cache.getMapping).toHaveBeenCalledWith('INBOX', 1);
  expect(dst.deleteMessage).toHaveBeenCalledWith('INBOX', 200);
  expect(result.state.messagesDeleted).toBe(1);
});

test('runSync skips duplicate deletion when cache has no mapping', async () => {
  const dup = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [],
    duplicates: [dup],
  });
  cache.getMapping.mockReturnValue(null);

  const config = makeConfig({
    messages: { dryRun: false, deleteSource: false, deleteDuplicates: true },
    cache: { enabled: true, path: ':memory:' },
  });
  const result = await runSync(config);

  expect(dst.deleteMessage).not.toHaveBeenCalled();
  expect(result.state.messagesDeleted).toBe(0);
});

test('runSync does not delete duplicates in dry run mode', async () => {
  const dup = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [],
    duplicates: [dup],
  });
  cache.getMapping.mockReturnValue(200);

  const config = makeConfig({
    messages: { dryRun: true, deleteSource: false, deleteDuplicates: true },
    cache: { enabled: true, path: ':memory:' },
  });
  const result = await runSync(config);

  expect(dst.deleteMessage).not.toHaveBeenCalled();
});

// ---------------------------------------------------------------------------
// Tests: Error handling in copy loop
// ---------------------------------------------------------------------------

test('runSync records MessageCopyError when a message copy fails and continues', async () => {
  const msg1 = makeMsg(1);
  const msg2 = makeMsg(2);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [msg1, msg2],
    alreadySynced: [],
    duplicates: [],
  });
  src.fetchMessageSource
    .mockRejectedValueOnce(new Error('fetch failed'))
    .mockResolvedValueOnce(Buffer.from('raw'));
  dst.appendMessage.mockResolvedValue({ destination: 'INBOX', uid: 200, uidValidity: 'v' } as AppendResult);

  const result = await runSync(makeConfig());

  // First message fails, second succeeds
  expect(result.state.messagesCopied).toBe(1);
  expect(result.state.errors.length).toBe(1);
  expect(result.state.errors[0].type).toBe('message');
});

// ---------------------------------------------------------------------------
// Tests: FolderError handling
// ---------------------------------------------------------------------------

test('runSync catches FolderError and continues with next folder', async () => {
  const pair1 = makeFolderPair('INBOX', 'INBOX');
  const pair2 = makeFolderPair('Sent', 'Sent');
  folderModule.resolveFolderPairs.mockResolvedValue([pair1, pair2]);

  // First folder: ensureFolder throws FolderError
  dst.ensureFolder.mockRejectedValueOnce(new FolderError('cannot create', 'INBOX'));
  // Second folder succeeds
  messageModule.findMessagesToCopy.mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] });

  const result = await runSync(makeConfig());

  // First folder should have recorded an error, second should succeed
  expect(result.state.errors.some(e => e.type === 'folder')).toBe(true);
  expect(result.state.foldersProcessed).toBe(1); // second folder processed
});

test('runSync records error for non-FolderError exceptions during folder sync', async () => {
  const pair = makeFolderPair('INBOX', 'INBOX');
  folderModule.resolveFolderPairs.mockResolvedValue([pair]);

  // Make folderStatus throw a generic error
  src.folderStatus.mockRejectedValue(new Error('status failed'));

  const result = await runSync(makeConfig());
  expect(result.state.errors.length).toBeGreaterThanOrEqual(1);
});

// ---------------------------------------------------------------------------
// Tests: Skipped messages count
// ---------------------------------------------------------------------------

test('runSync counts already-synced and duplicate messages as skipped', async () => {
  const alreadySynced = [makeMsg(1), makeMsg(2)];
  const duplicates = [makeMsg(3)];
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced,
    duplicates,
  });

  const result = await runSync(makeConfig());
  expect(result.state.messagesSkipped).toBe(3); // 2 already-synced + 1 duplicate
});

// ---------------------------------------------------------------------------
// Tests: Cache initialization
// ---------------------------------------------------------------------------

test('runSync initializes cache when cache is enabled', async () => {
  const config = makeConfig({ cache: { enabled: true, path: ':memory:' } });
  await runSync(config);

  expect(cacheModule.CacheStore).toHaveBeenCalledWith(':memory:');
  expect(cache.open).toHaveBeenCalled();
  expect(cache.close).toHaveBeenCalled();
});

test('runSync continues without cache when cache initialization fails', async () => {
  cacheModule.CacheStore.mockImplementationOnce(() => {
    throw new Error('db open failed');
  });

  const config = makeConfig({ cache: { enabled: true, path: '/bad/path' } });
  const result = await runSync(config);

  // Should record a cache error but continue
  expect(result.state.errors.some(e => e.type === 'cache')).toBe(true);
});

test('runSync skips cache when cache is disabled', async () => {
  const config = makeConfig({ cache: { enabled: false, path: ':memory:' } });
  await runSync(config);

  expect(cacheModule.CacheStore).not.toHaveBeenCalled();
  expect(cache.close).not.toHaveBeenCalled();
});

// ---------------------------------------------------------------------------
// Tests: Folder processing count
// ---------------------------------------------------------------------------

test('runSync increments foldersProcessed for each successful folder', async () => {
  const pair1 = makeFolderPair('INBOX', 'INBOX');
  const pair2 = makeFolderPair('Sent', 'Sent');
  const pair3 = makeFolderPair('Drafts', 'Drafts');
  folderModule.resolveFolderPairs.mockResolvedValue([pair1, pair2, pair3]);
  messageModule.findMessagesToCopy.mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] });

  const result = await runSync(makeConfig());
  expect(result.state.foldersProcessed).toBe(3);
});

// ---------------------------------------------------------------------------
// Tests: Delimiter mapping
// ---------------------------------------------------------------------------

test('runSync maps folder name when delimiters differ', async () => {
  const pair = makeFolderPair('INBOX.Archive', 'INBOX/Archive', '.', '/');
  folderModule.resolveFolderPairs.mockResolvedValue([pair]);
  messageModule.findMessagesToCopy.mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] });

  await runSync(makeConfig());
  expect(dst.ensureFolder).toHaveBeenCalledWith('INBOX/Archive');
});

test('runSync uses dest path directly when delimiters are the same', async () => {
  const pair = makeFolderPair('INBOX', 'INBOX', '.', '.');
  folderModule.resolveFolderPairs.mockResolvedValue([pair]);
  messageModule.findMessagesToCopy.mockReturnValue({ toCopy: [], alreadySynced: [], duplicates: [] });

  await runSync(makeConfig());
  expect(dst.ensureFolder).toHaveBeenCalledWith('INBOX');
});

// ---------------------------------------------------------------------------
// Tests: Result shape
// ---------------------------------------------------------------------------

test('runSync returns success with exitCode 0 when no connection/auth errors', async () => {
  const result = await runSync(makeConfig());
  expect(result.success).toBe(true);
  expect(result.exitCode).toBe(0);
});

test('runSync result includes state with startTime', async () => {
  const result = await runSync(makeConfig());
  expect(result.state.startTime).toBeInstanceOf(Date);
});

test('runSync returns zeroed state for no-op sync', async () => {
  const result = await runSync(makeConfig());
  expect(result.state.foldersProcessed).toBe(1); // one folder with no messages
  expect(result.state.messagesCopied).toBe(0);
  expect(result.state.messagesSkipped).toBe(0);
  expect(result.state.messagesDeleted).toBe(0);
});

// ---------------------------------------------------------------------------
// Tests: Delete source error handling
// ---------------------------------------------------------------------------

test('runSync records error when source delete fails', async () => {
  const alreadySynced = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [alreadySynced],
    duplicates: [],
  });
  src.deleteMessage.mockRejectedValue(new Error('delete failed'));

  const config = makeConfig({ messages: { dryRun: false, deleteSource: true, deleteDuplicates: false } });
  const result = await runSync(config);

  expect(result.state.errors.length).toBe(1);
  expect(result.state.messagesDeleted).toBe(0);
});

// ---------------------------------------------------------------------------
// Tests: Delete duplicates error handling
// ---------------------------------------------------------------------------

test('runSync records error when dest delete of duplicate fails', async () => {
  const dup = makeMsg(1);
  messageModule.findMessagesToCopy.mockReturnValue({
    toCopy: [],
    alreadySynced: [],
    duplicates: [dup],
  });
  cache.getMapping.mockReturnValue(200);
  dst.deleteMessage.mockRejectedValue(new Error('dest delete failed'));

  const config = makeConfig({
    messages: { dryRun: false, deleteSource: false, deleteDuplicates: true },
    cache: { enabled: true, path: ':memory:' },
  });
  const result = await runSync(config);

  expect(result.state.errors.length).toBe(1);
  expect(result.state.messagesDeleted).toBe(0);
});
