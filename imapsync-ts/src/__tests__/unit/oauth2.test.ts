import { refreshAccessToken, applyOAuth2ToAccount } from '../../auth/oauth2.js';
import type { ImapAccount } from '../../types/account.js';

const originalFetch = global.fetch;

beforeEach(() => {
  global.fetch = jest.fn();
});

afterEach(() => {
  global.fetch = originalFetch;
});

test('applyOAuth2ToAccount sets accessToken and clears pass', () => {
  const account: ImapAccount = {
    host: 'imap.example.com',
    port: 993,
    user: 'user@example.com',
    auth: { pass: 'old-password', accessToken: 'old-token' },
    tls: true,
  };

  applyOAuth2ToAccount(account, 'new-access-token');

  expect(account.auth.accessToken).toBe('new-access-token');
  expect(account.auth.pass).toBeUndefined();
});

test('refreshAccessToken success returns access_token', async () => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ access_token: 'tok123' }),
  });

  const token = await refreshAccessToken({
    clientId: 'cid',
    clientSecret: 'csec',
    refreshToken: 'rtok',
  });

  expect(token).toBe('tok123');
});

test('refreshAccessToken error throws with status and body', async () => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: false,
    status: 400,
    text: async () => 'bad request',
  });

  await expect(
    refreshAccessToken({
      clientId: 'cid',
      clientSecret: 'csec',
      refreshToken: 'rtok',
    }),
  ).rejects.toThrow('OAuth2 token refresh failed: 400 bad request');
});

test('refreshAccessToken uses default URL when tokenUrl not provided', async () => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ access_token: 'tok' }),
  });

  await refreshAccessToken({
    clientId: 'cid',
    clientSecret: 'csec',
    refreshToken: 'rtok',
  });

  expect(global.fetch).toHaveBeenCalledWith(
    'https://oauth2.googleapis.com/token',
    expect.any(Object),
  );
});

test('refreshAccessToken uses custom tokenUrl when provided', async () => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ access_token: 'tok' }),
  });

  await refreshAccessToken({
    clientId: 'cid',
    clientSecret: 'csec',
    refreshToken: 'rtok',
    tokenUrl: 'https://custom.example.com/token',
  });

  expect(global.fetch).toHaveBeenCalledWith(
    'https://custom.example.com/token',
    expect.any(Object),
  );
});

test('refreshAccessToken sends correct POST body', async () => {
  (global.fetch as jest.Mock).mockResolvedValue({
    ok: true,
    json: async () => ({ access_token: 'tok' }),
  });

  await refreshAccessToken({
    clientId: 'my-client-id',
    clientSecret: 'my-client-secret',
    refreshToken: 'my-refresh-token',
  });

  const call = (global.fetch as jest.Mock).mock.calls[0];
  const options = call[1];

  expect(options.method).toBe('POST');
  expect(options.headers).toEqual({ 'Content-Type': 'application/x-www-form-urlencoded' });

  const body = new URLSearchParams(options.body);
  expect(body.get('client_id')).toBe('my-client-id');
  expect(body.get('client_secret')).toBe('my-client-secret');
  expect(body.get('refresh_token')).toBe('my-refresh-token');
  expect(body.get('grant_type')).toBe('refresh_token');
});
