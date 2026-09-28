import {
  classifyError,
  ImapAuthError,
  ImapConnectionError,
  MessageCopyError,
  FolderError,
  CacheError,
} from '../../errors.js';

test('classifyError with ImapAuthError returns auth', () => {
  const err = new ImapAuthError('auth failed');
  expect(classifyError(err)).toBe('auth');
});

test('classifyError with ImapConnectionError returns connection', () => {
  const err = new ImapConnectionError('connection lost');
  expect(classifyError(err)).toBe('connection');
});

test('classifyError with MessageCopyError returns message', () => {
  const err = new MessageCopyError('copy failed', 'INBOX', 42);
  expect(classifyError(err)).toBe('message');
});

test('classifyError with FolderError returns folder', () => {
  const err = new FolderError('folder error', 'Sent');
  expect(classifyError(err)).toBe('folder');
});

test('classifyError with CacheError returns cache', () => {
  const err = new CacheError('cache miss');
  expect(classifyError(err)).toBe('cache');
});

test('classifyError with plain Error returns unknown', () => {
  const err = new Error('something went wrong');
  expect(classifyError(err)).toBe('unknown');
});

test('MessageCopyError carries folder and uid properties', () => {
  const cause = new Error('underlying');
  const err = new MessageCopyError('copy failed', 'Archive', 123, cause);
  expect(err.folder).toBe('Archive');
  expect(err.uid).toBe(123);
});

test('FolderError carries folder property', () => {
  const err = new FolderError('folder error', 'Drafts');
  expect(err.folder).toBe('Drafts');
});

test('all errors carry optional cause property', () => {
  const cause = new Error('root cause');

  const auth = new ImapAuthError('auth failed', cause);
  expect(auth.cause).toBe(cause);

  const conn = new ImapConnectionError('connection lost', cause);
  expect(conn.cause).toBe(cause);

  const msg = new MessageCopyError('copy failed', 'INBOX', 1, cause);
  expect(msg.cause).toBe(cause);

  const folder = new FolderError('folder error', 'Sent', cause);
  expect(folder.cause).toBe(cause);

  const cache = new CacheError('cache error', cause);
  expect(cache.cause).toBe(cause);
});
