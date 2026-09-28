import { shouldSkipMessage } from '../../imap/search.js';
import type { MessageInfo } from '../../types/account.js';

function makeMsg(overrides: Partial<MessageInfo> = {}): MessageInfo {
  return {
    uid: 1,
    flags: new Set(['\\Seen']),
    internalDate: new Date(),
    size: 1024,
    envelope: {
      subject: 'Hello',
      from: [{ address: 'alice@example.com' }],
      date: new Date(),
    },
    ...overrides,
  };
}

test('no options returns false for any message', () => {
  const msg = makeMsg({ size: 999999 });
  expect(shouldSkipMessage(msg, {})).toBe(false);
});

describe('skipLarge', () => {
  test('size above limit returns true', () => {
    const msg = makeMsg({ size: 2000 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000 })).toBe(true);
  });

  test('size at limit returns false', () => {
    const msg = makeMsg({ size: 1000 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000 })).toBe(false);
  });

  test('size below limit returns false', () => {
    const msg = makeMsg({ size: 500 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000 })).toBe(false);
  });

  test('skipLarge = 0 is falsy so no skip by size', () => {
    const msg = makeMsg({ size: 999999 });
    expect(shouldSkipMessage(msg, { skipLarge: 0 })).toBe(false);
  });
});

describe('skipRegex', () => {
  test('matches subject returns true', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [/^Hello$/] })).toBe(true);
  });

  test('matches from returns true', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [/alice@example\.com/] })).toBe(true);
  });

  test('no match returns false', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [/^SPAM$/] })).toBe(false);
  });

  test('multiple regexes any match returns true', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [/^SPAM$/, /^Hello$/] })).toBe(true);
  });

  test('multiple regexes none match returns false', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [/^SPAM$/, /^ADS$/] })).toBe(false);
  });

  test('empty regex array returns false', () => {
    const msg = makeMsg();
    expect(shouldSkipMessage(msg, { skipRegex: [] })).toBe(false);
  });
});

describe('missing envelope', () => {
  test('undefined envelope uses empty strings for subject and from', () => {
    const msg = makeMsg({ envelope: undefined });
    expect(shouldSkipMessage(msg, { skipRegex: [/^$/] })).toBe(true);
  });

  test('undefined envelope with non-matching regex returns false', () => {
    const msg = makeMsg({ envelope: undefined });
    expect(shouldSkipMessage(msg, { skipRegex: [/^SPAM$/] })).toBe(false);
  });
});

describe('combined skipLarge and skipRegex', () => {
  test('skipLarge triggers before skipRegex', () => {
    const msg = makeMsg({ size: 5000 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000, skipRegex: [/^NOMATCH$/] })).toBe(true);
  });

  test('skipRegex triggers when size is within limit', () => {
    const msg = makeMsg({ size: 500 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000, skipRegex: [/^Hello$/] })).toBe(true);
  });

  test('neither triggers returns false', () => {
    const msg = makeMsg({ size: 500 });
    expect(shouldSkipMessage(msg, { skipLarge: 1000, skipRegex: [/^NOMATCH$/] })).toBe(false);
  });
});
