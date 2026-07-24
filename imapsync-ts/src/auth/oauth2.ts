import type { ImapAccount } from '../types/account.js';

export interface OAuth2Config {
  clientId: string;
  clientSecret: string;
  refreshToken: string;
  tokenUrl?: string;
}

export async function refreshAccessToken(config: OAuth2Config): Promise<string> {
  const url = config.tokenUrl ?? 'https://oauth2.googleapis.com/token';
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    refresh_token: config.refreshToken,
    grant_type: 'refresh_token',
  });

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`OAuth2 token refresh failed: ${res.status} ${text}`);
  }

  const data = await res.json() as { access_token: string };
  return data.access_token;
}

export function applyOAuth2ToAccount(account: ImapAccount, accessToken: string): void {
  account.auth.accessToken = accessToken;
  account.auth.pass = undefined;
}
