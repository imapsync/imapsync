import { filterFolders, mapFolderName, resolveFolderPairs } from '../../imap/folder.js';
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
  expect(mapFolderName('INBOX.Sent', '.', '/')).toBe('INBOX/Sent');
});

test('mapFolderName with same separator returns unchanged', () => {
  expect(mapFolderName('INBOX/Sent', '/', '/')).toBe('INBOX/Sent');
});

// --- resolveFolderPairs tests ---

test('resolveFolderPairs: folder exists on both sides → dest uses matching dest FolderInfo', async () => {
  const srcFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
  ];
  const dstFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true, specialUse: '\\Inbox' },
    { path: 'Sent', delimiter: '/', subscribed: false },
    { path: 'Archive', delimiter: '/', subscribed: true },
  ];
  const pairs = await resolveFolderPairs(srcFolders, dstFolders, {});
  expect(pairs).toHaveLength(2);
  // dest should be the actual dest FolderInfo (with specialUse, subscribed as-is on dest)
  const inboxPair = pairs.find(p => p.source.path === 'INBOX')!;
  expect(inboxPair.dest).toEqual(dstFolders[0]);
  const sentPair = pairs.find(p => p.source.path === 'Sent')!;
  expect(sentPair.dest).toEqual(dstFolders[1]);
});

test('resolveFolderPairs: folder only on source → dest has same path but subscribed=false', async () => {
  const srcFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Drafts', delimiter: '/', subscribed: true },
  ];
  const dstFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
  ];
  const pairs = await resolveFolderPairs(srcFolders, dstFolders, {});
  expect(pairs).toHaveLength(2);
  const draftsPair = pairs.find(p => p.source.path === 'Drafts')!;
  expect(draftsPair.dest.path).toBe('Drafts');
  expect(draftsPair.dest.subscribed).toBe(false);
  expect(draftsPair.dest.delimiter).toBe('/');
});

test('resolveFolderPairs: include filter applied → only matching source folders returned', async () => {
  const srcFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
    { path: 'Trash', delimiter: '/', subscribed: true },
  ];
  const dstFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
    { path: 'Trash', delimiter: '/', subscribed: true },
  ];
  const pairs = await resolveFolderPairs(srcFolders, dstFolders, { include: [/^INBOX$/] });
  expect(pairs).toHaveLength(1);
  expect(pairs[0].source.path).toBe('INBOX');
});

test('resolveFolderPairs: exclude filter applied → matching folders excluded', async () => {
  const srcFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
    { path: 'Trash', delimiter: '/', subscribed: true },
  ];
  const dstFolders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
    { path: 'Trash', delimiter: '/', subscribed: true },
  ];
  const pairs = await resolveFolderPairs(srcFolders, dstFolders, { exclude: [/^Trash$/] });
  expect(pairs).toHaveLength(2);
  expect(pairs.map(p => p.source.path)).toEqual(['INBOX', 'Sent']);
});

test('resolveFolderPairs: multiple source folders with different delimiters', async () => {
  const srcFolders: FolderInfo[] = [
    { path: 'INBOX.Sent.Archive', delimiter: '.', subscribed: true },
    { path: 'INBOX/Drafts', delimiter: '/', subscribed: true },
  ];
  const dstFolders: FolderInfo[] = [
    { path: 'INBOX.Sent.Archive', delimiter: '.', subscribed: true },
    { path: 'INBOX/Drafts', delimiter: '/', subscribed: true },
  ];
  const pairs = await resolveFolderPairs(srcFolders, dstFolders, {});
  expect(pairs).toHaveLength(2);
  expect(pairs[0].source.delimiter).toBe('.');
  expect(pairs[1].source.delimiter).toBe('/');
  // Both exist on dest side, so dest should match
  expect(pairs[0].dest).toEqual(dstFolders[0]);
  expect(pairs[1].dest).toEqual(dstFolders[1]);
});

// --- filterFolders edge cases ---

test('filterFolders: include + exclude combined on same folder → exclude wins', () => {
  const folders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
  ];
  // INBOX matches both include and exclude → exclude removes it
  const result = filterFolders(folders, { include: [/^INBOX$/], exclude: [/^INBOX$/] });
  expect(result.map(f => f.path)).toEqual([]);
});

test('filterFolders: empty folder list → returns empty', () => {
  const result = filterFolders([], { include: [/^INBOX$/] });
  expect(result).toEqual([]);
});

test('filterFolders: no include/exclude with many folders → all pass through', () => {
  const folders: FolderInfo[] = [
    { path: 'INBOX', delimiter: '/', subscribed: true },
    { path: 'Sent', delimiter: '/', subscribed: true },
    { path: 'Drafts', delimiter: '/', subscribed: true },
    { path: 'Trash', delimiter: '/', subscribed: true },
    { path: 'Archive', delimiter: '/', subscribed: true },
  ];
  const result = filterFolders(folders, {});
  expect(result.map(f => f.path)).toEqual(['INBOX', 'Sent', 'Drafts', 'Trash', 'Archive']);
});
