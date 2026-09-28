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
  expect(mapFolderName('INBOX.Sent', '.', '/')).toBe('INBOX/Sent');
});

test('mapFolderName with same separator returns unchanged', () => {
  expect(mapFolderName('INBOX/Sent', '/', '/')).toBe('INBOX/Sent');
});
