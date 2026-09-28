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
